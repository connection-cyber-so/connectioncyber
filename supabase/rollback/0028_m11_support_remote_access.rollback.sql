-- Somente laboratório vazio. Em ambiente com uso, aplicar forward-fix.
begin;
do $$begin if exists(select 1 from public.erp_support_tickets)or exists(select 1 from public.erp_remote_access_grants)or exists(select 1 from public.erp_remote_sessions)then raise exception 'Rollback recusado: há dados M11';end if;end$$;
drop function if exists public.erp_decide_remote_consent(uuid,uuid,text,timestamptz,text),public.erp_revoke_remote_access(uuid,uuid,text,text),public.erp_issue_remote_access_grant(uuid,uuid,uuid,uuid,text[],text,text),public.erp_create_support_ticket(uuid,uuid,uuid,text,text,text,text,text,text);
drop table if exists public.erp_remote_session_artifacts,public.erp_remote_session_events,public.erp_remote_sessions,public.erp_remote_access_grants,public.erp_remote_consents,public.erp_device_identifiers,public.erp_managed_devices,public.erp_ticket_sla_clocks,public.erp_ticket_assignments,public.erp_support_attachments,public.erp_support_messages,public.erp_support_ticket_events,public.erp_support_tickets,public.erp_sla_targets,public.erp_sla_policies,public.erp_support_queue_members,public.erp_support_queues cascade;
delete from public.erp_permissions where key like 'support.%'or key like 'remote.%';
commit;
