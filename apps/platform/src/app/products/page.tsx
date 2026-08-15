import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { listProducts } from '@/features/products/service';
import { ProductForm } from '@/features/products/components/ProductForm';
import { ProductList } from '@/features/products/components/ProductList';
import { LogoutButton } from '@/components/LogoutButton';

export const dynamic = 'force-dynamic';

// Módulo "Catálogo de Produtos e Ofertas (IA)" — origem: adaptado de
// cc-commerce-studio, ver docs/migracao-diagnostico-digital-cc-commerce-studio.
export default async function ProductsPage() {
  const supabase = await createClient();
  const tenantId = await requireCurrentTenantId();
  const products = await listProducts(supabase, tenantId);

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
            <h1>Produtos</h1>
            <p>Cadastre os produtos do cliente — base para gerar ofertas de venda com IA.</p>
          </div>
        </div>

        <ProductForm />
        <ProductList products={products} />
      </main>
    </div>
  );
}
