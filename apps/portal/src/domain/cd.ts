// M54-G6 — interface do Centro Logístico. Regras puras, sem banco e sem React.
// Cada intenção mapeia para exatamente uma RPC public.cd_api_* (migration 0060).

export const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuidValue(value: unknown): value is string {
  return typeof value === 'string' && UUID_PATTERN.test(value);
}

export const CD_CANAIS = ['web', 'balcao', 'shopee'] as const;
export type CdCanal = (typeof CD_CANAIS)[number];

export const CD_INTENTS = [
  'criar_pedido',
  'alocar_pedido',
  'aprovar_pedido',
  'receber_transferencia',
  'coletar_pedido',
  'despachar_pedido',
] as const;
export type CdIntent = (typeof CD_INTENTS)[number];

export function isCdIntent(value: unknown): value is CdIntent {
  return typeof value === 'string' && (CD_INTENTS as readonly string[]).includes(value);
}

export function isCdCanal(value: unknown): value is CdCanal {
  return typeof value === 'string' && (CD_CANAIS as readonly string[]).includes(value);
}

export const CD_STATUS_LABEL: Record<string, string> = {
  aguardando_aprovacao: 'Aguardando aprovação',
  autorizada: 'Autorizada',
  em_separacao: 'Em separação',
  coletado: 'Coletado',
  despachado: 'Despachado',
  cancelado: 'Cancelado',
  pendente: 'Pendente',
  despachada: 'Despachada',
  recebida: 'Recebida',
};

export const CD_CANAL_LABEL: Record<CdCanal, string> = {
  web: 'Site',
  balcao: 'Balcão',
  shopee: 'Shopee',
};

// Quais ações fazem sentido para cada status (a RPC continua sendo a fonte da verdade).
export function cdNextActions(status: string, canal: string): CdIntent[] {
  if (status === 'aguardando_aprovacao') return ['alocar_pedido', 'aprovar_pedido'];
  if (status === 'autorizada') {
    return canal === 'web' ? ['coletar_pedido'] : ['despachar_pedido'];
  }
  if (status === 'coletado') return ['despachar_pedido'];
  return [];
}

export type CdItemInput = { produto_id: string; qtd: number; preco_unit: number };

// Lê um item do formulário. Retorna null se faltar algo ou se o valor não for positivo/válido.
export function parseCdItem(form: {
  produto_id: unknown;
  qtd: unknown;
  preco_unit: unknown;
}): CdItemInput | null {
  if (!isUuidValue(form.produto_id)) return null;
  const qtd = Number(form.qtd);
  const preco = Number(String(form.preco_unit ?? '').replace(',', '.'));
  if (!Number.isInteger(qtd) || qtd <= 0) return null;
  if (!Number.isFinite(preco) || preco < 0) return null;
  return { produto_id: form.produto_id, qtd, preco_unit: Math.round(preco * 100) / 100 };
}

// Monta a chamada RPC de uma intenção. Retorna null se a intenção pedir campos ausentes.
export function buildCdRpcCall(
  intent: CdIntent,
  input: {
    tenantId: string;
    localId?: string;
    canal?: string;
    item?: CdItemInput;
    pedidoId?: string;
    transferenciaId?: string;
  }
): { fn: string; args: Record<string, unknown> } | null {
  const { tenantId } = input;
  if (!isUuidValue(tenantId)) return null;
  switch (intent) {
    case 'criar_pedido': {
      if (!isUuidValue(input.localId) || !isCdCanal(input.canal) || !input.item) return null;
      return {
        fn: 'cd_api_criar_pedido',
        args: {
          p_tenant_id: tenantId,
          p_local_id: input.localId,
          p_canal: input.canal,
          p_itens: [input.item],
        },
      };
    }
    case 'alocar_pedido':
    case 'aprovar_pedido': {
      if (!isUuidValue(input.pedidoId)) return null;
      return {
        fn: 'cd_api_alocar_pedido',
        args: {
          p_tenant_id: tenantId,
          p_pedido_id: input.pedidoId,
          p_aprovado: intent === 'aprovar_pedido',
        },
      };
    }
    case 'receber_transferencia': {
      if (!isUuidValue(input.transferenciaId)) return null;
      return {
        fn: 'cd_api_receber_transferencia',
        args: { p_tenant_id: tenantId, p_transferencia_id: input.transferenciaId },
      };
    }
    case 'coletar_pedido':
    case 'despachar_pedido': {
      if (!isUuidValue(input.pedidoId)) return null;
      return {
        fn: intent === 'coletar_pedido' ? 'cd_api_coletar_pedido' : 'cd_api_despachar_pedido',
        args: { p_tenant_id: tenantId, p_pedido_id: input.pedidoId },
      };
    }
  }
}

// Mensagem de erro amigável a partir do texto da RPC (sem expor SQL bruto).
export function cdErrorMessage(code: string): string {
  if (code.includes('sem permissão')) return 'Você não tem permissão para esta ação.';
  if (code.includes('capacidade') && code.includes('inativa')) return 'Este módulo não está ativo no seu plano.';
  if (code.includes('não autenticado')) return 'Sessão expirada. Entre novamente.';
  if (code.includes('aguardando') || code.includes('acima do limite')) return 'Pedido aguarda aprovação.';
  if (code.includes('transferência não recebida')) return 'Há transferência pendente para este pedido.';
  if (code.includes('já alocado')) return 'Este pedido já foi alocado.';
  if (code.includes('exige coleta')) return 'Pedido com saída pelo CD precisa ser coletado antes do despacho.';
  return 'Não foi possível concluir a ação. Tente novamente.';
}
