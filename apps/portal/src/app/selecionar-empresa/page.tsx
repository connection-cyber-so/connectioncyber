import { notFound, redirect } from 'next/navigation';
import { PublicFrame } from '@/components/PublicFrame';
import { loadPortalAccess } from '@/lib/portal-context';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type SelectionPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function SelectCompanyPage({ searchParams }: SelectionPageProps) {
  const params = await searchParams;
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind === 'login') redirect('/login?redirect=%2Fselecionar-empresa');
  if (access.kind === 'forbidden') redirect('/acesso-negado');
  if (access.kind === 'no-membership') redirect('/sem-empresa');
  if (access.kind === 'authorized') redirect('/dashboard');
  if (access.kind === 'configuration-missing' || access.kind === 'service-unavailable') {
    redirect('/');
  }

  return (
    <PublicFrame>
      <span className="eyebrow">Conta multiempresa</span>
      <h1>Selecionar empresa</h1>
      <p className="lead">Somente vínculos ativos da sua conta aparecem nesta lista.</p>
      {params.erro ? (
        <div className="alert danger" role="alert">
          Não foi possível selecionar essa empresa. O acesso permaneceu bloqueado.
        </div>
      ) : null}
      <div className="tenant-list">
        {access.memberships.map((membership) => (
          <form method="post" action="/auth/select-membership" key={membership.id}>
            <input type="hidden" name="membership_id" value={membership.id} />
            <div>
              <strong>{membership.tenantName}</strong>
              <span>{membership.tenantSlug}</span>
            </div>
            <button type="submit" className="button secondary">Acessar</button>
          </form>
        ))}
      </div>
    </PublicFrame>
  );
}
