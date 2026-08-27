-- Somente laboratório vazio. Em ambiente com uso, aplicar forward-fix.
begin;
do $$begin if exists(select 1 from public.erp_service_orders)or exists(select 1 from public.erp_appointments)or exists(select 1 from public.erp_assets)then raise exception 'Rollback recusado: há dados M09';end if;end$$;
drop function if exists public.erp_complete_service_order(uuid,uuid,text),public.erp_schedule_appointment(uuid,uuid,uuid,uuid,text,timestamptz,timestamptz,text,text,text);
drop table if exists public.erp_warranty_events,public.erp_service_warranties,public.erp_service_approvals,public.erp_service_attachments,public.erp_inspection_items,public.erp_inspections,public.erp_work_logs,public.erp_service_assignments,public.erp_service_order_events,public.erp_service_order_items,public.erp_service_orders,public.erp_appointment_resources,public.erp_appointments,public.erp_vehicles,public.erp_asset_meter_readings,public.erp_asset_identifiers,public.erp_assets cascade;
delete from public.erp_permissions where key like 'services.%';
commit;
