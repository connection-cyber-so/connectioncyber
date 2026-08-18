import React, { useState } from 'react';
import type { GetServerSideProps } from 'next';
import Layout from '@/components/Layout';
import { isMercadoPagoEnabled } from '@/config/env';

/**
 * Checkout simplificado — demonstra o fluxo de criação de preferência
 * de pagamento e redirecionamento para o Mercado Pago. Em produção,
 * os itens devem vir do carrinho/curso/produto selecionado pelo usuário.
 */
interface CheckoutPageProps {
  paymentsEnabled: boolean;
  itemId: string | null;
  itemType: 'course' | 'product' | null;
}

export default function CheckoutPage({ paymentsEnabled, itemId, itemType }: CheckoutPageProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleCheckout() {
    if (!paymentsEnabled || !itemId || !itemType) return;
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/payments/create-preference', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          items: [{ id: itemId, type: itemType, quantity: 1 }],
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? 'Erro ao iniciar checkout');
      window.location.href = data.checkoutUrl || data.sandboxCheckoutUrl;
    } catch (err: any) {
      setError(err.message ?? 'Erro inesperado');
      setLoading(false);
    }
  }

  return (
    <Layout title="Checkout">
      <section className="section" style={{ textAlign: 'center' }}>
        <div className="container" style={{ maxWidth: 560 }}>
          <h1>Finalizar Pedido</h1>
          <p>
            {paymentsEnabled && itemId && itemType
              ? 'O preço será validado no catálogo e você será redirecionado para o ambiente seguro do Mercado Pago.'
              : 'O pagamento está disponível somente no ambiente de produção.'}
          </p>
          <button
            className="btn btn-primary"
            onClick={handleCheckout}
            disabled={loading || !paymentsEnabled || !itemId || !itemType}
          >
            {loading ? 'Redirecionando…' : 'Pagar com Mercado Pago'}
          </button>
          {error && <p style={{ color: 'var(--cc-danger)', marginTop: 16 }}>{error}</p>}
        </div>
      </section>
    </Layout>
  );
}

export const getServerSideProps: GetServerSideProps<CheckoutPageProps> = async ({ query }) => {
  const itemId = typeof query.id === 'string' && UUID_PATTERN.test(query.id) ? query.id : null;
  const itemType = query.type === 'course' || query.type === 'product' ? query.type : null;

  return {
    props: { paymentsEnabled: isMercadoPagoEnabled, itemId, itemType },
  };
};

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
