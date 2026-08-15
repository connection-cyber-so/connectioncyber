import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { listProducts } from '@/features/products/service';
import { listOffers } from '@/features/offers/service';
import { OfferForm } from '@/features/offers/components/OfferForm';
import { OfferList } from '@/features/offers/components/OfferList';
import { LogoutButton } from '@/components/LogoutButton';

export const dynamic = 'force-dynamic';

export default async function OffersPage() {
  const supabase = await createClient();
  const tenantId = await requireCurrentTenantId();

  const [products, offers] = await Promise.all([
    listProducts(supabase, tenantId),
    listOffers(supabase, tenantId),
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
            <h1>Ofertas</h1>
            <p>Gere copy de oferta de venda por IA a partir dos produtos cadastrados.</p>
          </div>
        </div>

        {products.length === 0 ? (
          <div className="pf-empty">
            <strong>Nenhum produto cadastrado</strong>
            <a href="/products" className="pf-link-btn">Cadastre um produto primeiro →</a>
          </div>
        ) : (
          <OfferForm products={products} />
        )}

        <OfferList offers={offers} />
      </main>
    </div>
  );
}
