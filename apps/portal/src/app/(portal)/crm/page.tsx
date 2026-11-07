import { redirect } from 'next/navigation';

export const dynamic = 'force-dynamic';

// "Painel CRM" ainda não tem painel próprio: envia para a primeira tela real.
export default function CrmHomePage() {
  redirect('/crm/clientes');
}
