import { StatePanel } from '@/components/StatePanel';

export const dynamic = 'force-dynamic';

export default function NoCompanyPage() {
  return (
    <StatePanel
      code="SEM VÍNCULO"
      title="Sua conta ainda não possui empresa autorizada"
      description="Nenhum dado empresarial foi exibido. Solicite à ConnectionCyber a ativação da sua membership."
      action={{ href: '/login', label: 'Voltar ao acesso' }}
    />
  );
}
