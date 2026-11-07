import 'server-only';
import { createClient } from '@/lib/supabase/server';
import {
  isValidPin,
  parseAlcadaResult,
  type AlcadaResult,
} from '@/domain/pdv-alcada';

type PortalClient = Awaited<ReturnType<typeof createClient>>;

export type DiscountAuthorizationInput = {
  establishmentId: string;
  saleId: string | null;
  requestedBy: string;
  discountAmount: number;
  discountPercent: number;
  reason: string;
  pin: string;
};

export type CashAuthorizationInput = {
  cashSessionId: string;
  kind: 'withdrawal' | 'close';
  amount: number;
  requestedBy: string;
  reason: string;
  pin: string;
};

export class PdvAlcadaError extends Error {
  constructor(
    message: string,
    readonly sqlstate?: string
  ) {
    super(message);
    this.name = 'PdvAlcadaError';
  }
}

function assertPin(pin: string): void {
  if (!isValidPin(pin)) {
    throw new PdvAlcadaError('PIN deve ter de 4 a 6 dígitos.', '22023');
  }
}

// Chamadas usam a sessão do usuário (RLS + checagens da própria RPC). Tenant vem do contexto do portal.
export async function authorizeDiscount(
  supabase: PortalClient,
  tenantId: string,
  input: DiscountAuthorizationInput
): Promise<AlcadaResult> {
  assertPin(input.pin);
  const { data, error } = await supabase.rpc('erp_authorize_discount', {
    p_tenant_id: tenantId,
    p_establishment_id: input.establishmentId,
    p_sale_id: input.saleId,
    p_requested_by: input.requestedBy,
    p_discount_amount: input.discountAmount,
    p_discount_percent: input.discountPercent,
    p_reason: input.reason,
    p_pin: input.pin,
  });
  if (error) throw new PdvAlcadaError('Falha ao autorizar desconto.', error.code);
  return parseAlcadaResult(data);
}

export async function authorizeCashAction(
  supabase: PortalClient,
  tenantId: string,
  input: CashAuthorizationInput
): Promise<AlcadaResult> {
  assertPin(input.pin);
  const { data, error } = await supabase.rpc('erp_authorize_cash_action', {
    p_tenant_id: tenantId,
    p_cash_session_id: input.cashSessionId,
    p_kind: input.kind,
    p_amount: input.amount,
    p_requested_by: input.requestedBy,
    p_reason: input.reason,
    p_pin: input.pin,
  });
  if (error) throw new PdvAlcadaError('Falha ao autorizar caixa.', error.code);
  return parseAlcadaResult(data);
}

// Só o gerente (memberships.manage). O PIN nunca é lido de volta: só o hash fica guardado.
export async function managerSetApproverPin(
  supabase: PortalClient,
  tenantId: string,
  targetUserId: string,
  pin: string
): Promise<'ok'> {
  assertPin(pin);
  const { data, error } = await supabase.rpc('erp_manager_set_approver_pin', {
    p_tenant_id: tenantId,
    p_target_user_id: targetUserId,
    p_new_pin: pin,
  });
  if (error) throw new PdvAlcadaError('Falha ao cadastrar PIN.', error.code);
  if (data !== 'ok') throw new PdvAlcadaError('Resposta inesperada ao cadastrar PIN.');
  return 'ok';
}
