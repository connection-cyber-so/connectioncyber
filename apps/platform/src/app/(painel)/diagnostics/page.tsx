import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { getOrCreateMpiProject, listDiagnostics } from '@/features/diagnostics/service';
import { DiagnosticForm } from '@/features/diagnostics/components/DiagnosticForm';
import { DiagnosticList } from '@/features/diagnostics/components/DiagnosticList';

// Depende de sessão a cada request, como a rota "/" — nunca pré-renderizar estático.
export const dynamic = 'force-dynamic';

// Módulo "Diagnóstico Digital (IA)" — origem: adaptado de cc-commerce-studio
// (auditoria de J:\BK_connectioncyber, ver docs/migracao-diagnostico-digital-cc-commerce-studio).
// O tenant nunca vem de query string/formulário aqui — sempre da sessão.
// Topbar, menu lateral e rodapé vêm do layout do route group (painel).
export default async function DiagnosticsPage() {
  const supabase = await createClient();
  const tenantId = await requireCurrentTenantId();

  const project = await getOrCreateMpiProject(supabase, tenantId);
  const diagnostics = await listDiagnostics(supabase, tenantId);

  return (
    <>
      <div className="pf-page-header">
        <div>
          <h1>Diagnóstico Digital</h1>
          <p>Diagnóstico de maturidade digital gerado por IA — recomenda o próximo serviço a contratar.</p>
        </div>
      </div>

      <DiagnosticForm projectId={project.id} />
      <DiagnosticList diagnostics={diagnostics} />
    </>
  );
}
