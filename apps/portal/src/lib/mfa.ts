import 'server-only';
import type { createClient } from '@/lib/supabase/server';
import type { AalLevel } from '@/domain/mfa-gate';

type PortalClient = Awaited<ReturnType<typeof createClient>>;

// M18-G22 — espelha o mesmo requires_mfa que a migration 0018 já grava em
// erp_roles (constraint erp_roles_privileged_mfa_required força requires_mfa
// pra papéis 'sensitivity=privileged', ex.: 'owner'). Fail-closed ao
// contrário de canManageBranding: erro aqui deve assumir que MFA É exigido
// (direção mais restritiva), nunca o oposto — a RLS de dado sensível
// continua sendo a autorização real, isto só decide se a UI redireciona pra
// segurança primeiro.
export async function membershipRequiresAal2(
  supabase: PortalClient,
  params: { membershipId: string; tenantId: string }
): Promise<boolean> {
  try {
    const { data: roles, error: rolesError } = await supabase
      .from('erp_membership_roles')
      .select('role_id')
      .eq('tenant_id', params.tenantId)
      .eq('membership_id', params.membershipId);
    if (rolesError) return true;
    if (!roles?.length) return false;

    const roleIds = roles.map((row) => row.role_id as string);
    const { data: privileged, error: privilegedError } = await supabase
      .from('erp_roles')
      .select('id')
      .eq('tenant_id', params.tenantId)
      .eq('requires_mfa', true)
      .in('id', roleIds);
    if (privilegedError) return true;
    return (privileged?.length ?? 0) > 0;
  } catch {
    return true;
  }
}

// Também fail-closed: sem conseguir ler o nível real, nunca assume aal2 —
// o pior caso é mandar quem já validou pra tela de segurança de novo (ela
// detecta e volta sozinha), nunca o oposto.
export async function getCurrentAal(supabase: PortalClient): Promise<AalLevel> {
  try {
    const { data, error } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (error || !data?.currentLevel) return 'aal1';
    return data.currentLevel === 'aal2' ? 'aal2' : 'aal1';
  } catch {
    return 'aal1';
  }
}
