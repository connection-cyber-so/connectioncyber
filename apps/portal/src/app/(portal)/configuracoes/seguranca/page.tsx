import { redirect } from 'next/navigation';
import { loadPortalAccess } from '@/lib/portal-context';
import { membershipRequiresAal2 } from '@/lib/mfa';
import { createClient } from '@/lib/supabase/server';
import { SecurityMfaPanel } from '@/components/SecurityMfaPanel';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

// M18-G22 — fecha o portão: até aqui não existia NENHUMA tela onde a pessoa
// convidada pudesse cadastrar o MFA que decidePortalAccess/RLS já exigem
// (erp_roles.requires_mfa, migration 0018). O layout redireciona pra cá
// sozinho quando o papel exige aal2 e a sessão ainda está em aal1
// (decideMfaGate) — chegar aqui direto também funciona pra quem quiser
// ativar/gerenciar MFA por conta própria, mesmo sem ser exigido.
export default async function SegurancaPage() {
  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') redirect('/login');

  const supabase = await createClient();
  const requiresAal2 = await membershipRequiresAal2(supabase, {
    membershipId: access.membership.id,
    tenantId: access.membership.tenantId,
  });

  return (
    <>
      <div className="content-heading">
        <div>
          <span className="eyebrow">Configurações</span>
          <h1>Segurança da conta</h1>
          <p className="lead">
            Autenticação em duas etapas (TOTP) da sua conta em{' '}
            <strong>{access.membership.tenantName}</strong>.
          </p>
        </div>
      </div>
      <SecurityMfaPanel requiresAal2={requiresAal2} />
    </>
  );
}
