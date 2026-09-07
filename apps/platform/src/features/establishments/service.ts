import type { SupabaseClient } from '@supabase/supabase-js';

// M20-G4 — leitura real de estabelecimentos para /vendas e /servicos, que já
// consultam Supabase direto (não passam pelo transporte visual de M18-G11/G12).
export interface EstablishmentOption { id: string; code: string; trade_name: string; vertical_code: string | null }

export async function listEstablishments(client: SupabaseClient, tenantId: string): Promise<EstablishmentOption[]> {
  const { data, error } = await client
    .from('erp_establishments')
    .select('id,code,trade_name,vertical_code')
    .eq('tenant_id', tenantId)
    .eq('active', true)
    .order('trade_name');
  if (error) throw new Error(error.message);
  return (data ?? []) as EstablishmentOption[];
}
