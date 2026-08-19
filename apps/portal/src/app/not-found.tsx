import { StatePanel } from '@/components/StatePanel';

export default function NotFoundPage() {
  return (
    <StatePanel
      code="404"
      title="Este endereço não está ativo"
      description="O portal não reconheceu um domínio empresarial válido. Nenhuma tela de login ou informação privada foi liberada."
      action={{ href: 'https://www.connectioncyber.com.br', label: 'Site ConnectionCyber' }}
    />
  );
}
