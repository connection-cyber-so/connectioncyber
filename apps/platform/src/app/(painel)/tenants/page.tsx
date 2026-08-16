import { createClient } from '@/lib/supabase/server';
import { listModuleCatalog, listTenantsWithModules } from '@/features/tenants/service';
import { TenantCard } from '@/features/tenants/components/TenantCard';

export const dynamic = 'force-dynamic';

// Fase 6 do plano de ação: primeira vez que os tenants ficam visíveis fora
// do Supabase Table Editor. Só leitura — CRUD (criar tenant com lookup-cnpj
// embutido) é a Fase 8. Quem vê o quê é decidido pela RLS de public.tenants,
// não por código aqui: equipe ConnectionCyber (is_platform_staff()) vê todos
// os tenants; qualquer outro usuário veria só a própria linha.
// Topbar, menu lateral e rodapé vêm do layout do route group (painel).
export default async function TenantsPage() {
  const supabase = await createClient();
  const [tenants, moduleCatalog] = await Promise.all([
    listTenantsWithModules(supabase),
    listModuleCatalog(supabase),
  ]);

  return (
    <>
      <div className="pf-page-header">
        <div>
          <h1>Tenants</h1>
          <p>
            {tenants.length} cliente{tenants.length === 1 ? '' : 's'} — dado cadastral via{' '}
            <code>lookup-cnpj</code> e módulos habilitados por cliente.
          </p>
        </div>
      </div>

      {tenants.length === 0 ? (
        <div className="pf-empty">
          <strong>Nenhum tenant visível</strong>
          Sua conta não tem papel de equipe (admin/suporte) — só enxerga o próprio tenant, e ele
          ainda não apareceu aqui.
        </div>
      ) : (
        <div className="pf-grid-2">
          {tenants.map((tenant) => (
            <TenantCard key={tenant.id} tenant={tenant} moduleCatalog={moduleCatalog} />
          ))}
        </div>
      )}
    </>
  );
}
