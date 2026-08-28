-- Somente laboratório sem embeddings reais. Em ambiente usado, aplicar forward-fix.
begin;
do $$begin if exists(select 1 from public.erp_catalog_items where embedding is not null)then raise exception 'Rollback recusado: há embeddings CTR';end if;end$$;
drop function if exists public.match_catalog_hybrid(extensions.vector,text,uuid,integer);
drop index if exists public.erp_catalog_items_embedding_idx,public.erp_catalog_items_fts_idx;
alter table public.erp_catalog_items drop constraint if exists erp_catalog_embedding_metadata_valid;
alter table public.erp_catalog_items drop column if exists fts,drop column if exists embedding_updated_at,drop column if exists embedding_content_hash,drop column if exists embedding_model,drop column if exists embedding;
revoke insert,update on public.erp_catalog_items from authenticated;
grant insert,update on public.erp_catalog_items to authenticated;
commit;
