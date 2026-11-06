import 'server-only';
import { createClient } from '@/lib/supabase/server';

type PortalClient = Awaited<ReturnType<typeof createClient>>;

export type CdLocal = { id: string; codigo: string; nome: string };
export type CdPedido = {
  id: string;
  canal: string;
  status: string;
  total_qtd: number;
  total_valor: number;
  created_at: string;
};
export type CdTransferencia = {
  id: string;
  status: string;
  pedido_cd_id: string | null;
  origem_local_id: string;
  destino_local_id: string;
};

// M54-G6 — leitura direta por RLS (SELECT da 0055/0057). Escrita só pelas RPCs cd_api_*.
export async function listCdLocals(supabase: PortalClient, tenantId: string): Promise<CdLocal[]> {
  const { data, error } = await supabase
    .from('locais')
    .select('id, codigo, nome')
    .eq('tenant_id', tenantId)
    .eq('tipo', 'cd')
    .eq('ativo', true)
    .order('codigo');
  if (error) return [];
  return (data ?? []) as CdLocal[];
}

export async function listCdPedidos(supabase: PortalClient, tenantId: string): Promise<CdPedido[]> {
  const { data, error } = await supabase
    .from('pedidos_cd')
    .select('id, canal, status, total_qtd, total_valor, created_at')
    .eq('tenant_id', tenantId)
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) return [];
  return (data ?? []) as CdPedido[];
}

export async function listTransferenciasAbertas(
  supabase: PortalClient,
  tenantId: string
): Promise<CdTransferencia[]> {
  const { data, error } = await supabase
    .from('transferencias')
    .select('id, status, pedido_cd_id, origem_local_id, destino_local_id')
    .eq('tenant_id', tenantId)
    .in('status', ['pendente', 'despachada'])
    .order('created_at', { ascending: false })
    .limit(50);
  if (error) return [];
  return (data ?? []) as CdTransferencia[];
}
