create type public.financial_entry_kind as enum (
  'otherIncome',
  'operatingExpense',
  'tax',
  'ownerWithdrawal',
  'otherExpense'
);

create type public.entry_payment_source as enum ('cash', 'bank', 'other');

alter table public.finance_transactions
add column entry_kind public.financial_entry_kind;

alter table public.finance_transactions
add column payment_source public.entry_payment_source not null default 'bank';

update public.finance_transactions
set entry_kind = case
  when type = 'income' then 'otherIncome'::public.financial_entry_kind
  else 'operatingExpense'::public.financial_entry_kind
end;

alter table public.finance_transactions
alter column entry_kind set not null;
