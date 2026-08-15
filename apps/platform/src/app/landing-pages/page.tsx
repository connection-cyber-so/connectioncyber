import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { listOffers } from '@/features/offers/service';
import { listLandingPages } from '@/features/landing-pages/service';
import { LandingPageForm } from '@/features/landing-pages/components/LandingPageForm';
import { LandingPageList } from '@/features/landing-pages/components/LandingPageList';
import { LogoutButton } from '@/components/LogoutButton';

export const dynamic = 'force-dynamic';

// Só a gestão fica aqui. A página publicada é servida por apps/site
// (/lp/[slug], sem login) — apps/platform continua 100% interno.
export default async function LandingPagesPage() {
  const supabase = await createClient();
  const tenantId = await requireCurrentTenantId();

  const [offers, landingPages] = await Promise.all([
    listOffers(supabase, tenantId),
    listLandingPages(supabase, tenantId),
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
            <h1>Landing Pages</h1>
            <p>Página de venda pública a partir de uma oferta. Publicada, fica em connectioncyber.com.br/lp/&lt;slug&gt;.</p>
          </div>
        </div>

        {offers.length === 0 ? (
          <div className="pf-empty">
            <strong>Nenhuma oferta cadastrada</strong>
            <a href="/offers" className="pf-link-btn">Cadastre uma oferta primeiro →</a>
          </div>
        ) : (
          <LandingPageForm offers={offers} />
        )}

        <LandingPageList landingPages={landingPages} />
      </main>
    </div>
  );
}
