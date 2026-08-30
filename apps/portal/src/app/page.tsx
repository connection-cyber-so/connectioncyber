import { notFound, redirect } from 'next/navigation';
import { StatePanel } from '@/components/StatePanel';
import { loadPortalAccess } from '@/lib/portal-context';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

export default async function PortalEntryPage() {
  const access = await loadPortalAccess();

  switch (access.kind) {
    case 'configuration-missing':
      return (
        <StatePanel
          code="STAGING"
          title="Portal preparado para configuração"
          description="O acesso real permanece protegido. Enquanto isso, visualize o fluxo completo com dados sintéticos locais."
          action={{ href: '/demo', label: 'Abrir demonstração' }}
        />
      );
    case 'service-unavailable':
      return (
        <StatePanel
          code="503"
          title="Não foi possível validar o acesso"
          description="Nenhum contexto foi liberado. Aguarde e tente novamente."
          action={{ href: '/', label: 'Tentar novamente' }}
        />
      );
    case 'not-found':
      notFound();
    case 'login':
      redirect('/login?redirect=%2F');
    case 'forbidden':
      redirect('/acesso-negado');
    case 'no-membership':
      redirect('/sem-empresa');
    case 'select-membership':
      redirect('/selecionar-empresa');
    case 'authorized':
      redirect('/dashboard');
  }
}
