-- M22 0.1.0: additive; apply only after preflight and local security validation.
begin;
insert into public.erp_permissions(key,name,category) values
 ('knowledge.manage','Curadoria da Biblioteca Técnica','knowledge') on conflict(key) do nothing;
create table public.kb_entitlements (
 tenant_id uuid not null references public.tenants(id), user_id uuid not null references public.users(id),
 status text not null check(status in ('active','suspended','cancelled')), starts_at timestamptz not null,
 ends_at timestamptz not null, external_reference text not null check(length(external_reference) between 1 and 200),
 updated_at timestamptz not null default now(), primary key(tenant_id,user_id), check(ends_at>starts_at)
);
create table public.kb_items (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id),
 author_id uuid not null references public.users(id), content_editor_id uuid not null references public.users(id), title text not null check(length(title) between 3 and 180),
 kind text not null check(kind in ('prompt','link','video','script','code','migration','study','file')),
 body text not null default '' check(length(body)<=100000), source_url text not null default '' check(length(source_url)<=2048),
 taxonomy jsonb not null default '{}' check(jsonb_typeof(taxonomy)='object' and octet_length(taxonomy::text)<=8000),
 tags text[] not null default '{}' check(cardinality(tags)<=30),
 stage integer not null default 0 check(stage between 0 and 4), revision integer not null default 1 check(revision>0),
 score integer not null default 0 check(score between 0 and 100), application text not null default '' check(length(application)<=4000),
 repository text not null default '' check(length(repository)<=250), review jsonb not null default '{}' check(octet_length(review::text)<=8000),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(tenant_id,id),
 search_document tsvector generated always as (to_tsvector('portuguese'::regconfig,title||' '||body||' '||taxonomy::text)) stored
);
create index kb_items_search on public.kb_items using gin(search_document);
create index kb_items_tags on public.kb_items using gin(tags);
create index kb_items_catalog on public.kb_items(tenant_id,stage,updated_at desc,id);
create table public.kb_versions (
 tenant_id uuid not null, item_id uuid not null, revision integer not null,
 snapshot jsonb not null, actor_id uuid not null references public.users(id), created_at timestamptz not null default now(),
 primary key(item_id,revision), foreign key(tenant_id,item_id) references public.kb_items(tenant_id,id)
);
create table public.kb_events (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null, item_id uuid not null,
 actor_id uuid not null references public.users(id), action text not null, revision integer not null,
 detail jsonb not null default '{}', created_at timestamptz not null default now(),
 foreign key(tenant_id,item_id) references public.kb_items(tenant_id,id)
);
create index kb_events_item on public.kb_events(tenant_id,item_id,created_at desc);
create table public.kb_favorites (
 tenant_id uuid not null, item_id uuid not null, user_id uuid not null references public.users(id),
 created_at timestamptz not null default now(), primary key(item_id,user_id),
 foreign key(tenant_id,item_id) references public.kb_items(tenant_id,id)
);
create table public.kb_ratings (
 tenant_id uuid not null, item_id uuid not null, user_id uuid not null references public.users(id),
 rating integer not null check(rating between 1 and 5), comment text not null default '' check(length(comment)<=1000),
 updated_at timestamptz not null default now(), primary key(item_id,user_id),
 foreign key(tenant_id,item_id) references public.kb_items(tenant_id,id)
);
create table public.kb_assets (
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null, item_id uuid not null,
 uploaded_by uuid not null references public.users(id), filename text not null check(length(filename) between 1 and 180),
 mime text not null, size_bytes integer not null check(size_bytes between 1 and 3145728),
 sha256 text not null check(sha256 ~ '^[0-9a-f]{64}$'), object_path text not null unique,
 status text not null default 'pending' check(status in ('pending','quarantined','approved','rejected')),
 created_at timestamptz not null default now(), foreign key(tenant_id,item_id) references public.kb_items(tenant_id,id)
);
create function erp_security.kb_access(p_tenant uuid) returns boolean language sql stable security definer set search_path='' as $$
 select erp_security.is_tenant_member(p_tenant) and exists(select 1 from public.kb_entitlements e
 where e.tenant_id=p_tenant and e.user_id=auth.uid() and e.status='active' and e.starts_at<=now() and e.ends_at>now())
 and not exists(select 1 from public.erp_tenant_memberships m
 join public.erp_membership_roles mr on mr.tenant_id=m.tenant_id and mr.membership_id=m.id
 join public.erp_roles r on r.tenant_id=mr.tenant_id and r.id=mr.role_id
 where m.tenant_id=p_tenant and m.user_id=auth.uid() and m.status='active' and r.active and r.requires_mfa
 and erp_security.current_aal()<>'aal2');
$$;
create function erp_security.kb_manage(p_tenant uuid) returns boolean language sql stable security definer set search_path='' as $$
 select erp_security.kb_access(p_tenant) and erp_security.has_permission_at_aal(p_tenant,'knowledge.manage','aal2');
$$;
create function erp_security.kb_read(p_tenant uuid,p_item uuid) returns boolean language sql stable security definer set search_path='' as $$
 select erp_security.kb_access(p_tenant) and exists(select 1 from public.kb_items i where i.id=p_item and i.tenant_id=p_tenant
 and (i.stage=4 or i.author_id=auth.uid() or erp_security.kb_manage(p_tenant)));
$$;
create function public.kb_context(p_tenant uuid) returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('access',erp_security.kb_access(p_tenant),'manage',erp_security.kb_manage(p_tenant));
$$;
-- No DML privileges for clients: all state transitions use the locked command below.
do $$ declare t text; begin
 foreach t in array array['kb_entitlements','kb_items','kb_versions','kb_events','kb_favorites','kb_ratings','kb_assets'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('grant all on public.%I to service_role',t);
 end loop;
end $$;
create policy kb_entitlement_read on public.kb_entitlements for select to authenticated using(user_id=auth.uid() and erp_security.is_tenant_member(tenant_id));
create policy kb_item_read on public.kb_items for select to authenticated using(erp_security.kb_read(tenant_id,id));
-- Old versions are curator/author-only: a current release never publishes unreviewed old drafts.
create policy kb_version_read on public.kb_versions for select to authenticated using(erp_security.kb_read(tenant_id,item_id) and
 (erp_security.kb_manage(tenant_id) or exists(select 1 from public.kb_items i where i.id=item_id and i.author_id=auth.uid())));
create policy kb_event_read on public.kb_events for select to authenticated using(erp_security.kb_read(tenant_id,item_id) and (actor_id=auth.uid() or erp_security.kb_manage(tenant_id)));
create policy kb_favorite_read on public.kb_favorites for select to authenticated using(user_id=auth.uid() and erp_security.kb_read(tenant_id,item_id));
create policy kb_rating_read on public.kb_ratings for select to authenticated using(erp_security.kb_read(tenant_id,item_id));
create policy kb_asset_read on public.kb_assets for select to authenticated using(erp_security.kb_read(tenant_id,item_id) and
 (status='approved' or uploaded_by=auth.uid() or erp_security.kb_manage(tenant_id)));
create function public.kb_command(p_tenant uuid,p_action text,p_item uuid default null,p_revision integer default null,p_data jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare i public.kb_items; a public.kb_assets; uid uuid:=auth.uid(); manager boolean;
 tx jsonb; k text; next_stage integer; asset_id uuid; obj text;
begin
 if not coalesce(erp_security.kb_access(p_tenant),false) then raise exception 'KB_ACCESS_DENIED' using errcode='42501'; end if;
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>150000 then raise exception 'KB_INVALID_INPUT'; end if;
 manager:=erp_security.kb_manage(p_tenant);
 -- Serialize per user/tenant before enforcing the rolling budget, including AI requests.
 perform pg_advisory_xact_lock(hashtextextended(p_tenant::text||uid::text,0));
 if (select count(*) from public.kb_events where tenant_id=p_tenant and actor_id=uid and created_at>now()-interval '1 minute')>=120 then raise exception 'KB_RATE_LIMIT'; end if;
 if p_action='create' then
 insert into public.kb_items(tenant_id,author_id,content_editor_id,title,kind,body,source_url) values
 (p_tenant,uid,uid,btrim(p_data->>'title'),p_data->>'kind',coalesce(p_data->>'body',''),coalesce(p_data->>'source_url','')) returning * into i;
 else
 select * into i from public.kb_items where tenant_id=p_tenant and id=p_item for update;
 if i.id is null or not erp_security.kb_read(p_tenant,i.id) then raise exception 'KB_NOT_FOUND' using errcode='42501'; end if;
 if p_action='ai_request' then
 if i.stage<>0 or (not manager and i.author_id<>uid) then raise exception 'KB_ACCESS_DENIED' using errcode='42501'; end if;
 if (select count(*) from public.kb_events where tenant_id=p_tenant and actor_id=uid and action='ai_request' and created_at>now()-interval '1 minute')>=3 then raise exception 'KB_RATE_LIMIT'; end if;
 insert into public.kb_events(tenant_id,item_id,actor_id,action,revision) values(p_tenant,i.id,uid,p_action,i.revision);
 return to_jsonb(i)-'search_document';
 end if;
 if p_action in ('favorite','rate','download','inspect') then
 if p_action='inspect' and not manager then raise exception 'KB_CURATOR_REQUIRED' using errcode='42501'; end if;
 if p_action<>'inspect' and i.stage<>4 then raise exception 'KB_NOT_RELEASED'; end if;
 if p_action='favorite' then
 if p_data->>'enabled'='true' then insert into public.kb_favorites values(p_tenant,i.id,uid,now()) on conflict do nothing;
 else delete from public.kb_favorites where item_id=i.id and user_id=uid; end if;
 elsif p_action='rate' then
 if i.author_id=uid then raise exception 'KB_SELF_RATING'; end if;
 insert into public.kb_ratings values(p_tenant,i.id,uid,(p_data->>'rating')::integer,coalesce(p_data->>'comment',''),now())
 on conflict(item_id,user_id) do update set rating=excluded.rating,comment=excluded.comment,updated_at=now();
 else
 asset_id:=(p_data->>'asset_id')::uuid;
 if asset_id is not null and not exists(select 1 from public.kb_assets where id=asset_id and item_id=i.id and tenant_id=p_tenant and (status='approved' or (p_action='inspect' and manager and status='quarantined'))) then raise exception 'KB_ASSET_DENIED'; end if;
 end if;
 insert into public.kb_events(tenant_id,item_id,actor_id,action,revision,detail) values(p_tenant,i.id,uid,p_action,i.revision,
 case when p_action in ('download','inspect') then jsonb_build_object('asset_id',asset_id,'meaning','authorized_request') else '{}'::jsonb end);
 return to_jsonb(i);
 end if;
 if p_revision is null or p_revision<>i.revision then raise exception 'KB_REVISION_CONFLICT' using errcode='40001'; end if;
 if not manager and i.author_id<>uid then raise exception 'KB_CURATOR_REQUIRED' using errcode='42501'; end if;
 if p_action='revise' then
 i.title:=coalesce(p_data->>'title',i.title); i.body:=coalesce(p_data->>'body',i.body); i.source_url:=coalesce(p_data->>'source_url',i.source_url);
 i.stage:=0; i.review:='{}'; i.score:=0; i.content_editor_id:=uid;
 elsif p_action='classify' then
 if i.stage<>0 then raise exception 'KB_GATE_ORDER'; end if;
 tx:=p_data->'taxonomy';
 if tx is null or jsonb_typeof(tx)<>'object' then raise exception 'KB_TAXONOMY_REQUIRED'; end if;
 foreach k in array array['ai','sector','segment','theme','project','technical_application','repository'] loop
 if coalesce(length(btrim(tx->>k)),0) not between 1 and 180 then raise exception 'KB_TAXONOMY_REQUIRED'; end if;
 end loop;
 i.taxonomy:=tx; i.tags:=array(select jsonb_array_elements_text(coalesce(p_data->'tags','[]')));
 elsif p_action='advance' then
 if not manager then raise exception 'KB_CURATOR_REQUIRED' using errcode='42501'; end if;
 next_stage:=i.stage+1;
 if next_stage>4 then raise exception 'KB_GATE_ORDER'; end if;
 if next_stage=1 then
 foreach k in array array['ai','sector','segment','theme','project','technical_application','repository'] loop
 if coalesce(length(btrim(i.taxonomy->>k)),0)=0 then raise exception 'KB_TAXONOMY_REQUIRED'; end if;
 end loop;
 elsif next_stage=2 then
 i.application:=btrim(p_data->>'application'); i.score:=(p_data->>'score')::integer;
 if coalesce(length(i.application),0)<20 or i.score is null or i.score<60 then raise exception 'KB_APPLICATION_REQUIRED'; end if;
 elsif next_stage=3 then
 i.repository:=coalesce(p_data->>'repository','');
 if i.repository !~ '^https://github[.]com/[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$' then raise exception 'KB_REPOSITORY_REQUIRED'; end if;
 elsif next_stage=4 then
 if uid=i.author_id or uid=i.content_editor_id then raise exception 'KB_INDEPENDENT_REVIEW_REQUIRED'; end if;
 if coalesce(p_data->>'rights','')<>'true' or coalesce(p_data->>'secrets_checked','')<>'true' or coalesce(p_data->>'technical_checked','')<>'true'
 or coalesce(length(btrim(p_data->>'evidence')),0)<20 then raise exception 'KB_RELEASE_REVIEW_REQUIRED'; end if;
 if exists(select 1 from public.kb_assets where item_id=i.id and status not in ('approved','rejected')) then raise exception 'KB_ASSETS_PENDING'; end if;
 if i.kind='file' and not exists(select 1 from public.kb_assets where item_id=i.id and status='approved') then raise exception 'KB_FILE_REQUIRED'; end if;
 i.review:=jsonb_build_object('rights',true,'secrets_checked',true,'technical_checked',true,'evidence',p_data->>'evidence','reviewer',uid,'reviewed_at',now());
 end if;
 i.stage:=next_stage;
 elsif p_action='reserve_asset' then
 if i.stage<>0 then raise exception 'KB_REVISE_BEFORE_UPLOAD'; end if;
 if (select count(*) from public.kb_assets where item_id=i.id)>=30 then raise exception 'KB_ASSET_LIMIT'; end if;
 asset_id:=gen_random_uuid(); obj:=p_tenant::text||'/'||i.id::text||'/'||asset_id::text;
 insert into public.kb_assets(id,tenant_id,item_id,uploaded_by,filename,mime,size_bytes,sha256,object_path)
 values(asset_id,p_tenant,i.id,uid,p_data->>'filename',p_data->>'mime',(p_data->>'size_bytes')::integer,p_data->>'sha256',obj);
 elsif p_action='finalize_asset' then
 select * into a from public.kb_assets where id=(p_data->>'asset_id')::uuid and tenant_id=p_tenant and item_id=i.id for update;
 if a.id is null or a.status<>'pending' or a.uploaded_by<>uid or i.stage<>0 then raise exception 'KB_ASSET_DENIED'; end if;
 if not exists(select 1 from storage.objects where bucket_id='knowledge-base' and name=a.object_path) then raise exception 'KB_UPLOAD_MISSING'; end if;
 update public.kb_assets set status='quarantined' where id=a.id;
 elsif p_action='review_asset' then
 if not manager or coalesce(length(p_data->>'evidence'),0)<20 or i.stage=4 then raise exception 'KB_ASSET_REVIEW_REQUIRED'; end if;
 select * into a from public.kb_assets where id=(p_data->>'asset_id')::uuid and item_id=i.id and tenant_id=p_tenant for update;
 if a.id is null or a.uploaded_by=uid or a.status not in ('quarantined','pending') then raise exception 'KB_INDEPENDENT_REVIEW_REQUIRED'; end if;
 if p_data->>'approved'='true' and a.status<>'quarantined' then raise exception 'KB_UPLOAD_MISSING'; end if;
 update public.kb_assets set status=case when p_data->>'approved'='true' then 'approved' else 'rejected' end where id=a.id;
 else raise exception 'KB_UNKNOWN_COMMAND'; end if;
 i.revision:=i.revision+1;
 end if;
 if length(btrim(i.title))<3 or length(i.title)>180 or length(i.body)>100000 then raise exception 'KB_INVALID_CONTENT'; end if;
 -- External links are references only; never fetched or executed by the server.
 if i.source_url<>'' and (i.source_url !~ '^https://[^/@[:space:]]+[.][^/@[:space:]]+' or i.source_url ~ '[[:space:]]') then raise exception 'KB_INVALID_URL'; end if;
 if i.kind in ('link','video') and i.source_url='' then raise exception 'KB_URL_REQUIRED'; end if;
 update public.kb_items set content_editor_id=i.content_editor_id,title=i.title,body=i.body,source_url=i.source_url,taxonomy=i.taxonomy,tags=i.tags,stage=i.stage,
 revision=i.revision,score=i.score,application=i.application,repository=i.repository,review=i.review,updated_at=now()
 where id=i.id returning * into i;
 insert into public.kb_versions(tenant_id,item_id,revision,snapshot,actor_id) values(p_tenant,i.id,i.revision,(to_jsonb(i)-'search_document')||jsonb_build_object('assets',coalesce((select jsonb_agg(to_jsonb(asset) order by asset.created_at,asset.id) from public.kb_assets asset where asset.item_id=i.id),'[]'::jsonb)),uid);
 insert into public.kb_events(tenant_id,item_id,actor_id,action,revision,detail) values(p_tenant,i.id,uid,p_action,i.revision,
 case when p_action='classify' then jsonb_build_object('source',coalesce(p_data->>'provider','human'),'model',left(p_data->>'model',100))
 when p_action='reserve_asset' then jsonb_build_object('asset_id',asset_id,'sha256',p_data->>'sha256')
 when p_action='finalize_asset' then jsonb_build_object('asset_id',a.id)
 when p_action='review_asset' then jsonb_build_object('asset_id',a.id,'approved',p_data->>'approved','evidence',left(p_data->>'evidence',4000)) else '{}'::jsonb end);
 return (to_jsonb(i)-'search_document')||jsonb_build_object('reserved_asset_id',asset_id,'reserved_path',obj);
end $$;
-- Explicit grants, including private helpers used by RLS. No anonymous execute.
revoke all on function erp_security.kb_access(uuid),erp_security.kb_manage(uuid),erp_security.kb_read(uuid,uuid),public.kb_context(uuid),public.kb_command(uuid,text,uuid,integer,jsonb) from public,anon;
grant execute on function erp_security.kb_access(uuid),erp_security.kb_manage(uuid),erp_security.kb_read(uuid,uuid),public.kb_context(uuid),public.kb_command(uuid,text,uuid,integer,jsonb) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit) values('knowledge-base','knowledge-base',false,3145728);
create policy kb_storage_insert on storage.objects for insert to authenticated with check(bucket_id='knowledge-base' and exists(
 select 1 from public.kb_assets a join public.kb_items i on i.id=a.item_id where a.object_path=name and a.status='pending'
 and a.uploaded_by=auth.uid() and erp_security.kb_access(a.tenant_id) and i.stage=0));
create policy kb_storage_select on storage.objects for select to authenticated using(bucket_id='knowledge-base' and exists(
 select 1 from public.kb_assets a join public.kb_items i on i.id=a.item_id where a.object_path=name and erp_security.kb_read(a.tenant_id,a.item_id)
 and ((a.status='approved' and i.stage=4) or erp_security.kb_manage(a.tenant_id))
 and exists(select 1 from public.kb_events e where e.tenant_id=a.tenant_id and e.item_id=a.item_id
 and e.actor_id=auth.uid() and e.action in ('download','inspect') and e.detail->>'asset_id'=a.id::text
 and e.created_at>now()-interval '60 seconds')));
-- Restrictive policies also protect this bucket from unrelated permissive policies.
create policy kb_storage_no_update on storage.objects as restrictive for update to authenticated using(bucket_id<>'knowledge-base') with check(bucket_id<>'knowledge-base');
create policy kb_storage_no_delete on storage.objects as restrictive for delete to authenticated using(bucket_id<>'knowledge-base');
create policy kb_storage_anon_guard on storage.objects as restrictive for all to anon using(bucket_id<>'knowledge-base') with check(bucket_id<>'knowledge-base');
-- No object UPDATE/DELETE policy: immutable objects; new content always gets a new path.
commit;
