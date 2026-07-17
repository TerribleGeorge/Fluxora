-- Inventory reporting and owner alerts.
-- Product saves go through an RPC that records manual stock movement, while
-- every stock movement can enqueue real-time owner-facing automation events.

create or replace function public.product_owner_contacts(target_business_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'name', profile.name,
        'email', profile.email
      )
      order by profile.name, profile.email
    ),
    '[]'::jsonb
  )
  from public.memberships membership
  join public.profiles profile on profile.id = membership.user_id
  where membership.business_id = target_business_id
    and membership.active
    and membership.role in ('owner', 'manager');
$$;

create or replace function public.save_product_with_stock_movement(
  target_product_id uuid,
  target_business_id uuid,
  target_business_type public.business_type,
  target_name text,
  target_category text,
  target_sale_price numeric,
  target_unit_cost numeric,
  target_stock_quantity integer,
  target_min_stock_quantity integer,
  target_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_product public.products;
  saved_product public.products;
  stock_delta integer;
  movement_kind public.product_stock_movement_type;
begin
  if not public.has_business_role(
    target_business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Owner or manager access required';
  end if;

  if char_length(trim(coalesce(target_name, ''))) < 2
    or target_sale_price < 0
    or target_unit_cost < 0
    or target_stock_quantity < 0
    or target_min_stock_quantity < 0 then
    raise exception 'Invalid product data';
  end if;

  select * into existing_product
  from public.products
  where id = target_product_id
    and business_id = target_business_id;

  insert into public.products (
    id,
    business_id,
    business_type,
    name,
    category,
    sale_price,
    unit_cost,
    stock_quantity,
    min_stock_quantity,
    active
  ) values (
    target_product_id,
    target_business_id,
    target_business_type,
    trim(target_name),
    coalesce(nullif(trim(target_category), ''), 'Produtos'),
    target_sale_price,
    target_unit_cost,
    target_stock_quantity,
    target_min_stock_quantity,
    target_active
  )
  on conflict (id) do update set
    name = excluded.name,
    category = excluded.category,
    sale_price = excluded.sale_price,
    unit_cost = excluded.unit_cost,
    stock_quantity = excluded.stock_quantity,
    min_stock_quantity = excluded.min_stock_quantity,
    active = excluded.active,
    updated_at = now()
  returning * into saved_product;

  stock_delta := target_stock_quantity - coalesce(existing_product.stock_quantity, 0);
  if stock_delta <> 0 then
    movement_kind := case
      when existing_product.id is null or stock_delta > 0 then 'purchase'
      else 'adjustment'
    end;

    insert into public.product_stock_movements (
      business_id,
      product_id,
      movement_type,
      quantity,
      unit_cost,
      notes,
      created_by
    )
    values (
      target_business_id,
      target_product_id,
      movement_kind,
      stock_delta,
      target_unit_cost,
      case
        when existing_product.id is null then 'Estoque inicial cadastrado pelo dono'
        when stock_delta > 0 then 'Entrada manual de estoque'
        else 'Ajuste manual de estoque'
      end,
      (select auth.uid())
    );
  end if;

  return jsonb_build_object(
    'id', saved_product.id,
    'business_id', saved_product.business_id,
    'business_type', saved_product.business_type,
    'name', saved_product.name,
    'category', saved_product.category,
    'sale_price', saved_product.sale_price,
    'unit_cost', saved_product.unit_cost,
    'stock_quantity', saved_product.stock_quantity,
    'min_stock_quantity', saved_product.min_stock_quantity,
    'active', saved_product.active,
    'updated_at', saved_product.updated_at
  );
end;
$$;

create or replace function public.enqueue_product_stock_automation_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  product_record public.products;
  business_record public.businesses;
  payload_data jsonb;
begin
  select * into product_record
  from public.products
  where id = new.product_id;

  if product_record.id is null then
    return new;
  end if;

  select * into business_record
  from public.businesses
  where id = new.business_id;

  payload_data := jsonb_build_object(
    'businessId', new.business_id,
    'businessName', coalesce(business_record.name, ''),
    'businessPhone', coalesce(business_record.phone, ''),
    'productId', product_record.id,
    'productName', product_record.name,
    'category', product_record.category,
    'movementType', new.movement_type,
    'quantity', new.quantity,
    'unitCost', new.unit_cost,
    'stockQuantity', product_record.stock_quantity,
    'minStockQuantity', product_record.min_stock_quantity,
    'salePrice', product_record.sale_price,
    'stockCostValue', product_record.stock_quantity * product_record.unit_cost,
    'stockSaleValue', product_record.stock_quantity * product_record.sale_price,
    'notes', new.notes,
    'ownerContacts', public.product_owner_contacts(new.business_id)
  );

  insert into public.automation_events (
    business_id,
    event_type,
    aggregate_type,
    aggregate_id,
    payload
  )
  values (
    new.business_id,
    'product.stock_movement',
    'product',
    product_record.id,
    payload_data
  );

  if product_record.active
    and product_record.min_stock_quantity > 0
    and product_record.stock_quantity <= product_record.min_stock_quantity
    and not exists (
      select 1
      from public.automation_events event
      where event.business_id = new.business_id
        and event.event_type = 'product.low_stock'
        and event.aggregate_type = 'product'
        and event.aggregate_id = product_record.id
        and event.created_at >= now() - interval '12 hours'
    ) then
    insert into public.automation_events (
      business_id,
      event_type,
      aggregate_type,
      aggregate_id,
      payload
    )
    values (
      new.business_id,
      'product.low_stock',
      'product',
      product_record.id,
      payload_data
    );
  end if;

  return new;
end;
$$;

drop trigger if exists product_stock_movements_enqueue_automation_event
  on public.product_stock_movements;
create trigger product_stock_movements_enqueue_automation_event
after insert on public.product_stock_movements
for each row execute function public.enqueue_product_stock_automation_event();

create or replace function public.get_product_inventory_report(
  target_business_id uuid,
  period_start timestamptz default date_trunc('month', now()),
  period_end timestamptz default now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  report jsonb;
begin
  if not public.has_business_role(
    target_business_id,
    array['owner', 'manager']::public.membership_role[]
  ) then
    raise exception 'Owner or manager access required';
  end if;

  select jsonb_build_object(
    'businessId', target_business_id,
    'periodStart', period_start,
    'periodEnd', period_end,
    'summary', jsonb_build_object(
      'activeProducts', coalesce(count(*) filter (where product.active), 0),
      'lowStockProducts', coalesce(
        count(*) filter (
          where product.active
            and product.min_stock_quantity > 0
            and product.stock_quantity <= product.min_stock_quantity
        ),
        0
      ),
      'stockCostValue', coalesce(sum(product.stock_quantity * product.unit_cost), 0),
      'stockSaleValue', coalesce(sum(product.stock_quantity * product.sale_price), 0),
      'periodProductRevenue', coalesce((
        select sum(sale.product_gross_total)
        from public.sales sale
        where sale.business_id = target_business_id
          and sale.status = 'completed'
          and sale.occurred_at >= period_start
          and sale.occurred_at < period_end
      ), 0),
      'periodProductCost', coalesce((
        select sum(sale.product_cost_total)
        from public.sales sale
        where sale.business_id = target_business_id
          and sale.status = 'completed'
          and sale.occurred_at >= period_start
          and sale.occurred_at < period_end
      ), 0),
      'periodProductProfit', coalesce((
        select sum(sale.product_gross_total - sale.product_cost_total)
        from public.sales sale
        where sale.business_id = target_business_id
          and sale.status = 'completed'
          and sale.occurred_at >= period_start
          and sale.occurred_at < period_end
      ), 0)
    ),
    'products', coalesce(jsonb_agg(
      jsonb_build_object(
        'id', product.id,
        'name', product.name,
        'category', product.category,
        'salePrice', product.sale_price,
        'unitCost', product.unit_cost,
        'stockQuantity', product.stock_quantity,
        'minStockQuantity', product.min_stock_quantity,
        'lowStock', product.active
          and product.min_stock_quantity > 0
          and product.stock_quantity <= product.min_stock_quantity,
        'active', product.active,
        'stockCostValue', product.stock_quantity * product.unit_cost,
        'stockSaleValue', product.stock_quantity * product.sale_price
      )
      order by product.name
    ) filter (where product.id is not null), '[]'::jsonb),
    'movements', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', movement.id,
          'productId', movement.product_id,
          'productName', movement_product.name,
          'movementType', movement.movement_type,
          'quantity', movement.quantity,
          'unitCost', movement.unit_cost,
          'notes', movement.notes,
          'createdAt', movement.created_at
        )
        order by movement.created_at desc
      )
      from (
        select *
        from public.product_stock_movements
        where business_id = target_business_id
          and created_at >= period_start
          and created_at < period_end
        order by created_at desc
        limit 100
      ) movement
      join public.products movement_product on movement_product.id = movement.product_id
    ), '[]'::jsonb)
  )
  into report
  from public.products product
  where product.business_id = target_business_id;

  return report;
end;
$$;

revoke execute on function public.product_owner_contacts(uuid)
  from public, anon, authenticated;
revoke execute on function public.save_product_with_stock_movement(
  uuid, uuid, public.business_type, text, text, numeric, numeric, integer,
  integer, boolean
) from public, anon, authenticated;
grant execute on function public.save_product_with_stock_movement(
  uuid, uuid, public.business_type, text, text, numeric, numeric, integer,
  integer, boolean
) to authenticated;
revoke execute on function public.enqueue_product_stock_automation_event()
  from public, anon, authenticated;
revoke execute on function public.get_product_inventory_report(
  uuid, timestamptz, timestamptz
) from public, anon, authenticated;
grant execute on function public.get_product_inventory_report(
  uuid, timestamptz, timestamptz
) to authenticated;
