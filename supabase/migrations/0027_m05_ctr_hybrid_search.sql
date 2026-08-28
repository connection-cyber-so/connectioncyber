-- ConnectionCyber — M05: CTR e Busca Híbrida para Catálogo Multiempresa.
BEGIN;

-- 1. Extensão em schema determinístico do Supabase.
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;
DO $$
DECLARE
  v_schema text;
BEGIN
  SELECT n.nspname INTO v_schema
  FROM pg_extension e
  JOIN pg_namespace n ON n.oid = e.extnamespace
  WHERE e.extname = 'vector';

  IF v_schema IS DISTINCT FROM 'extensions' THEN
    ALTER EXTENSION vector SET SCHEMA extensions;
  END IF;
END $$;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_extension e JOIN pg_namespace n ON n.oid=e.extnamespace
    WHERE e.extname='vector' AND n.nspname='extensions'
  ) THEN
    RAISE EXCEPTION 'vector extension must be installed in extensions schema';
  END IF;
END $$;

-- 2. Preparar a Tabela do Catálogo para o CTR (Vetor + Lexical)
ALTER TABLE public.erp_catalog_items
ADD COLUMN IF NOT EXISTS embedding extensions.vector(1536),
ADD COLUMN IF NOT EXISTS embedding_model text,
ADD COLUMN IF NOT EXISTS embedding_content_hash text,
ADD COLUMN IF NOT EXISTS embedding_updated_at timestamptz,
ADD COLUMN IF NOT EXISTS fts tsvector GENERATED ALWAYS AS (
  to_tsvector('portuguese', coalesce(code, '') || ' ' || coalesce(name, '') || ' ' || coalesce(description, ''))
) STORED,
ADD CONSTRAINT erp_catalog_embedding_metadata_valid CHECK (
  (embedding IS NULL AND embedding_model IS NULL AND embedding_content_hash IS NULL AND embedding_updated_at IS NULL)
  OR
  (embedding IS NOT NULL AND embedding_model IS NOT NULL AND embedding_content_hash ~ '^[a-f0-9]{64}$' AND embedding_updated_at IS NOT NULL)
);

-- 3. Índices de Alta Performance
-- Índice HNSW para busca semântica ultrarrápida
DROP INDEX IF EXISTS public.erp_catalog_items_embedding_idx;
CREATE INDEX erp_catalog_items_embedding_idx ON public.erp_catalog_items
USING hnsw (embedding extensions.vector_cosine_ops) WHERE embedding IS NOT NULL;
-- Índice GIN para busca lexical exata de palavras-chave
CREATE INDEX IF NOT EXISTS erp_catalog_items_fts_idx ON public.erp_catalog_items USING gin (fts);

-- 4. Motor de Busca Híbrida (RPC - Remote Procedure Call)
-- Utiliza SECURITY INVOKER para respeitar as políticas de RLS automaticamente.
CREATE OR REPLACE FUNCTION public.match_catalog_hybrid(
  query_embedding extensions.vector(1536),
  query_text text,
  p_tenant_id uuid,
  match_count int DEFAULT 5
)
RETURNS TABLE (
  id uuid,
  code text,
  name text,
  description text,
  similarity float,
  rank real
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF NOT erp_security.has_permission(p_tenant_id,'catalog.read') AND NOT public.is_platform_staff() THEN
    RAISE EXCEPTION 'permission denied';
  END IF;
  IF match_count NOT BETWEEN 1 AND 50 THEN RAISE EXCEPTION 'match_count must be between 1 and 50'; END IF;
  IF length(coalesce(query_text,'')) > 500 THEN RAISE EXCEPTION 'query_text too long'; END IF;
  IF query_embedding IS NULL AND btrim(coalesce(query_text,'')) = '' THEN RAISE EXCEPTION 'query required'; END IF;

  RETURN QUERY
  WITH semantic_ranked AS (
    SELECT c.id,
      row_number() over(order by c.embedding OPERATOR(extensions.<=>) query_embedding) AS position,
      1-(c.embedding OPERATOR(extensions.<=>) query_embedding) AS similarity_value
    FROM public.erp_catalog_items c
    WHERE query_embedding IS NOT NULL AND c.tenant_id=p_tenant_id AND c.status='active' AND c.embedding IS NOT NULL
    ORDER BY c.embedding OPERATOR(extensions.<=>) query_embedding
    LIMIT match_count*4
  ), lexical_ranked AS (
    SELECT c.id,
      row_number() over(order by ts_rank(c.fts,websearch_to_tsquery('portuguese',query_text)) desc) AS position,
      ts_rank(c.fts,websearch_to_tsquery('portuguese',query_text)) AS lexical_rank
    FROM public.erp_catalog_items c
    WHERE btrim(coalesce(query_text,''))<>'' AND c.tenant_id=p_tenant_id AND c.status='active'
      AND c.fts@@websearch_to_tsquery('portuguese',query_text)
    ORDER BY lexical_rank desc
    LIMIT match_count*4
  ), candidates AS (
    SELECT id FROM semantic_ranked UNION SELECT id FROM lexical_ranked
  )
  SELECT c.id,c.code,c.name,c.description,
    coalesce(s.similarity_value,0)::float AS similarity,
    (coalesce(1.0/(60+s.position),0)+coalesce(1.0/(60+l.position),0))::real AS rank
  FROM candidates x
  JOIN public.erp_catalog_items c ON c.id=x.id AND c.tenant_id=p_tenant_id
  LEFT JOIN semantic_ranked s ON s.id=x.id
  LEFT JOIN lexical_ranked l ON l.id=x.id
  ORDER BY 6 DESC,c.code
  LIMIT match_count;
END;
$$;

-- 5. Conceder permissões de execução
REVOKE ALL ON FUNCTION public.match_catalog_hybrid(extensions.vector, text, uuid, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.match_catalog_hybrid(extensions.vector, text, uuid, int) TO authenticated, service_role;

-- Embeddings são server-only. O formulário autenticado não pode inserir ou atualizar metadados vetoriais.
REVOKE INSERT,UPDATE ON public.erp_catalog_items FROM authenticated;
GRANT INSERT(id,tenant_id,kind,code,name,description,base_unit_id,track_inventory,allows_fraction,status,metadata)
  ON public.erp_catalog_items TO authenticated;
GRANT UPDATE(kind,code,name,description,base_unit_id,track_inventory,allows_fraction,status,metadata)
  ON public.erp_catalog_items TO authenticated;

COMMIT;
