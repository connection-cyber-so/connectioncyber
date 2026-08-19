import { StatePanel } from '@/components/StatePanel';

export const dynamic = 'force-dynamic';

export default function AccessDeniedPage() {
  return (
    <StatePanel
      code="403"
      title="Acesso não autorizado para esta empresa"
      description="A sessão é válida, mas não existe uma membership ativa compatível com este endereço."
      action={{ href: '/', label: 'Ir para o portal central' }}
    />
  );
}
