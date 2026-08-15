// Fase 6 do plano de ação: lista de tenants, só leitura — CRUD (criar tenant
// com lookup-cnpj embutido) é a Fase 8, não esta.
//
// Sem filtro por tenant_id explícito: a RLS de public.tenants já resolve
// quem vê o quê — "usuário vê o próprio tenant" (linha única) ou "equipe
// ConnectionCyber vê todos os tenants" (is_platform_staff()). Mesmo padrão
// dos módulos anteriores: nunca decidir escopo de tenant no código, sempre
// deixar o banco decidir via RLS.
import type { SupabaseClient } from '@supabase/supabase-js';
import type { ModuleCatalogEntry, TenantWithModules } from './types';

export async function listTenantsWithModules(supabase: SupabaseClient): Promise<TenantWithModules[]> {
  const { data, error } = await supabase
    .from('tenants')
    .select('*, tenant_modules(module_key, status)')
    .order('nome', { ascending: true });

  if (error) throw new Error(error.message);
  return (data ?? []) as TenantWithModules[];
}

export async function listModuleCatalog(supabase: SupabaseClient): Promise<ModuleCatalogEntry[]> {
  const { data, error } = await supabase.from('module_catalog').select('key, name');
  if (error) throw new Error(error.message);
  return data ?? [];
}
