import 'server-only';
import type { createClient } from '@/lib/supabase/server';

type PortalClient = Awaited<ReturnType<typeof createClient>>;

export type TenantBranding = {
  primaryColor: string | null;
  logoUrl: string | null;
};

const DEFAULT_BRANDING: TenantBranding = { primaryColor: null, logoUrl: null };

// M19-G4 — dado cosmético, nunca deve derrubar a renderização do portal:
// qualquer erro/ausência de linha cai fechado pro padrão global (fail open
// pra branding, ao contrário de loadPortalAccess, que fail closed pra auth).
export async function loadTenantBranding(
  supabase: PortalClient,
  tenantId: string
): Promise<TenantBranding> {
  try {
    const { data, error } = await supabase
      .from('erp_tenant_branding')
      .select('primary_color, logo_url')
      .eq('tenant_id', tenantId)
      .maybeSingle();
    if (error || !data) return DEFAULT_BRANDING;
    return {
      primaryColor: (data.primary_color as string | null) ?? null,
      logoUrl: (data.logo_url as string | null) ?? null,
    };
  } catch {
    return DEFAULT_BRANDING;
  }
}

// Só decide se a engrenagem de configuração *aparece* — recalcula o mesmo
// que a RLS de erp_tenant_branding já checa no servidor (papel da membership
// -> erp_role_permissions -> permissão 'branding.manage'), ou equipe. A
// escrita real continua protegida pela RLS/RPC independentemente do que
// esta função concluir; um falso positivo aqui só mostra um botão que a
// própria RPC recusaria em seguida — nunca uma falha de segurança.
export async function canManageBranding(
  supabase: PortalClient,
  params: { membershipId: string; tenantId: string }
): Promise<boolean> {
  try {
    const { data: staff } = await supabase.rpc('is_platform_staff');
    if (staff === true) return true;

    const { data: roles, error: rolesError } = await supabase
      .from('erp_membership_roles')
      .select('role_id')
      .eq('tenant_id', params.tenantId)
      .eq('membership_id', params.membershipId);
    if (rolesError || !roles?.length) return false;

    const { data: permission, error: permissionError } = await supabase
      .from('erp_permissions')
      .select('id')
      .eq('key', 'branding.manage')
      .maybeSingle();
    if (permissionError || !permission) return false;

    const roleIds = roles.map((row) => row.role_id as string);
    const { data: grants, error: grantsError } = await supabase
      .from('erp_role_permissions')
      .select('role_id')
      .eq('tenant_id', params.tenantId)
      .eq('permission_id', permission.id)
      .in('role_id', roleIds);
    if (grantsError) return false;
    return (grants?.length ?? 0) > 0;
  } catch {
    return false;
  }
}
