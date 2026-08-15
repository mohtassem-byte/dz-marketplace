-- Sprint 2.5-D: database-side order transition guard.
-- Review column names against the deployed schema before running.

create or replace function public.enforce_order_transition()
returns trigger
language plpgsql
security invoker
as $$
begin
  if new.status is distinct from old.status then
    if old.status = 'pending' and new.status not in ('in_progress','cancelled') then
      raise exception 'Invalid order transition: pending -> %', new.status;
    elsif old.status = 'in_progress' and new.status not in ('delivered','cancelled') then
      raise exception 'Invalid order transition: in_progress -> %', new.status;
    elsif old.status = 'delivered' and new.status <> 'completed' then
      raise exception 'Invalid order transition: delivered -> %', new.status;
    elsif old.status in ('completed','cancelled') then
      raise exception 'Order is already closed';
    end if;
  end if;

  if new.total_dzd < 0 or new.platform_fee_dzd < 0 then
    raise exception 'Order amounts cannot be negative';
  end if;

  if new.total_dzd < new.platform_fee_dzd then
    raise exception 'Platform fee cannot exceed order total';
  end if;

  return new;
end;
$$;

drop trigger if exists orders_state_guard on public.orders;
create trigger orders_state_guard
before update on public.orders
for each row execute function public.enforce_order_transition();

-- A review should only be created for a completed order by one of its participants.
-- This trigger assumes reviews.order_id and reviews.reviewer_id exist.
create or replace function public.enforce_review_for_completed_order()
returns trigger
language plpgsql
security invoker
as $$
declare o public.orders%rowtype;
begin
  select * into o from public.orders where id = new.order_id;
  if o.id is null then raise exception 'Order not found'; end if;
  if o.status <> 'completed' then raise exception 'Only completed orders can be reviewed'; end if;
  if new.reviewer_id <> o.buyer_id and new.reviewer_id <> o.provider_id then
    raise exception 'Reviewer is not an order participant';
  end if;
  if new.rating < 1 or new.rating > 5 then raise exception 'Rating must be between 1 and 5'; end if;
  return new;
end;
$$;

drop trigger if exists reviews_completed_order_guard on public.reviews;
create trigger reviews_completed_order_guard
before insert on public.reviews
for each row execute function public.enforce_review_for_completed_order();
