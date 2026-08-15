import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { listOffers } from '@/features/offers/service';
import { listVideoScripts } from '@/features/video-scripts/service';
import { VideoScriptForm } from '@/features/video-scripts/components/VideoScriptForm';
import { VideoScriptList } from '@/features/video-scripts/components/VideoScriptList';
import { LogoutButton } from '@/components/LogoutButton';

export const dynamic = 'force-dynamic';

export default async function VideoScriptsPage() {
  const supabase = await createClient();
  const tenantId = await requireCurrentTenantId();

  const [offers, videoScripts] = await Promise.all([
    listOffers(supabase, tenantId),
    listVideoScripts(supabase, tenantId),
  ]);

  return (
    <div className="pf-page">
      <header className="pf-topbar">
        <div className="pf-brand">
          <span className="dot" />
          ConnectionCyberSO
        </div>
        <LogoutButton />
      </header>
      <main className="pf-content">
        <div className="pf-page-header">
          <div>
            <h1>Roteiros de Vídeo</h1>
            <p>Gere um roteiro de vídeo de venda (estilo VSL) por IA a partir de uma oferta.</p>
          </div>
        </div>

        {offers.length === 0 ? (
          <div className="pf-empty">
            <strong>Nenhuma oferta cadastrada</strong>
            <a href="/offers" className="pf-link-btn">Cadastre uma oferta primeiro →</a>
          </div>
        ) : (
          <VideoScriptForm offers={offers} />
        )}

        <VideoScriptList videoScripts={videoScripts} />
      </main>
    </div>
  );
}
