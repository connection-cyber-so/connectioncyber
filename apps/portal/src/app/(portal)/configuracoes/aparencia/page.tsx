import { notFound, redirect } from 'next/navigation';
import { canManageBranding, loadTenantBranding } from '@/lib/branding';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

const ERROR_MESSAGES: Record<string, string> = {
  cor: 'A cor precisa estar no formato #rrggbb.',
  logo: 'O link do logo precisa começar com https://.',
  permissao: 'Você não tem permissão para alterar a identidade visual desta empresa.',
};

// M19-G4 — engrenagem de configuração de cor/logo por tenant. A permissão é
// recalculada aqui de novo (o layout já decide se o link aparece) porque
// alguém pode chegar direto na URL sem passar pelo link — nunca redireciona
// quem não tem permissão, só mostra um aviso: a query já é escopada ao
// próprio tenant (access.membership.tenantId), então não há dado de outro
// tenant pra vazar mesmo sem a permissão de escrita.
export default async function AparenciaPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind !== 'authorized') redirect('/login');

  const supabase = await createClient();
  const [branding, canEdit] = await Promise.all([
    loadTenantBranding(supabase, access.membership.tenantId),
    canManageBranding(supabase, {
      membershipId: access.membership.id,
      tenantId: access.membership.tenantId,
    }),
  ]);

  const errorCode = typeof params.erro === 'string' ? params.erro : '';
  const success = params.sucesso === '1';

  return (
    <>
      <div className="content-heading">
        <div>
          <span className="eyebrow">Configurações</span>
          <h1>Identidade visual</h1>
          <p className="lead">
            Cor e logo próprios do portal de <strong>{access.membership.tenantName}</strong>,
            sem afetar os demais clientes. Sem definição, usa o padrão oficial da ConnectionCyber.
          </p>
        </div>
      </div>

      {!canEdit ? (
        <div className="alert danger" role="alert">
          Sua conta não tem permissão para alterar a identidade visual desta empresa. Peça a um
          administrador do tenant.
        </div>
      ) : (
        <>
          {success ? (
            <div className="alert" role="status">Identidade visual salva.</div>
          ) : null}
          {ERROR_MESSAGES[errorCode] ? (
            <div className="alert danger" role="alert">{ERROR_MESSAGES[errorCode]}</div>
          ) : null}

          <form method="post" action="/auth/set-branding" className="form-stack">
            <label>
              Cor principal
              <input type="color" name="primary_color" defaultValue={branding.primaryColor ?? '#f6851f'} />
            </label>
            <label>
              <input type="checkbox" name="reset_color" value="1" /> Restaurar cor oficial da marca
            </label>
            <label>
              Logo (URL https)
              <input
                type="url"
                name="logo_url"
                defaultValue={branding.logoUrl ?? ''}
                pattern="https://.*"
                placeholder="https://..."
              />
            </label>
            <button className="button primary" type="submit">Salvar identidade visual</button>
          </form>
        </>
      )}
    </>
  );
}
