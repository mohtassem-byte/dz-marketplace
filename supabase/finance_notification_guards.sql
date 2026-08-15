-- Sprint 2.5-E
-- Review against the deployed schema before running in production.

create or replace function public.guard_order_financial_fields()
returns trigger language plpgsql security invoker as $$
begin
  if tg_op = 'UPDATE' then
    if new.total_dzd is distinct from old.total_dzd
       or new.platform_fee_dzd is distinct from old.platform_fee_dzd
       or new.buyer_id is distinct from old.buyer_id
       or new.provider_id is distinct from old.provider_id then
      raise exception 'Financial and ownership fields are immutable after order creation';
    end if;
  end if;
  if new.total_dzd < 0 or new.platform_fee_dzd < 0 or new.platform_fee_dzd > new.total_dzd then
    raise exception 'Invalid order financial values';
  end if;
  return new;
end;
$$;

drop trigger if exists orders_finance_guard on public.orders;
create trigger orders_finance_guard
before insert or update on public.orders
for each row execute function public.guard_order_financial_fields();

-- Automatic notification when an order status changes.
create or replace function public.notify_order_status_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    insert into public.notifications(user_id,title,body,created_at)
    values
      (new.buyer_id,'تحديث حالة الطلب','تم تحديث حالة طلبك إلى: ' || new.status,now()),
      (new.provider_id,'تحديث حالة الطلب','تم تحديث حالة الطلب إلى: ' || new.status,now());
  end if;
  return new;
end;
$$;

drop trigger if exists orders_status_notification on public.orders;
create trigger orders_status_notification
after update of status on public.orders
for each row execute function public.notify_order_status_change();

-- Complaint must belong to the authenticated order participant.
create or replace function public.guard_complaint_order()
returns trigger language plpgsql security invoker as $$
declare o public.orders%rowtype;
begin
  select * into o from public.orders where id = new.order_id;
  if o.id is null then raise exception 'Order not found'; end if;
  if new.user_id <> o.buyer_id and new.user_id <> o.provider_id then
    raise exception 'Complaint user is not an order participant';
  end if;
  return new;
end;
$$;

drop trigger if exists complaints_order_guard on public.complaints;
create trigger complaints_order_guard
before insert or update on public.complaints
for each row execute function public.guard_complaint_order();
