-- Add real-time inventory summary to product automation events.

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
  month_start timestamptz := date_trunc('month', now());
  inventory_summary jsonb;
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

  select jsonb_build_object(
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
    'monthProductRevenue', coalesce((
      select sum(sale.product_gross_total)
      from public.sales sale
      where sale.business_id = new.business_id
        and sale.status = 'completed'
        and sale.occurred_at >= month_start
        and sale.occurred_at < now()
    ), 0),
    'monthProductCost', coalesce((
      select sum(sale.product_cost_total)
      from public.sales sale
      where sale.business_id = new.business_id
        and sale.status = 'completed'
        and sale.occurred_at >= month_start
        and sale.occurred_at < now()
    ), 0),
    'monthProductProfit', coalesce((
      select sum(sale.product_gross_total - sale.product_cost_total)
      from public.sales sale
      where sale.business_id = new.business_id
        and sale.status = 'completed'
        and sale.occurred_at >= month_start
        and sale.occurred_at < now()
    ), 0)
  )
  into inventory_summary
  from public.products product
  where product.business_id = new.business_id;

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
    'inventorySummary', inventory_summary,
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

revoke execute on function public.enqueue_product_stock_automation_event()
  from public, anon, authenticated;
