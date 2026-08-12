import React, { useState } from 'react';
import Layout from '@/components/Layout';

/**
 * Checkout simplificado — demonstra o fluxo de criação de preferência
 * de pagamento e redirecionamento para o Mercado Pago. Em produção,
 * os itens devem vir do carrinho/curso/produto selecionado pelo usuário.
 */
export default function CheckoutPage() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleCheckout() {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/payments/create-preference', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          items: [{ id: 'curso-demo', title: 'Treinamento ConnectionCyber', quantity: 1, unitPrice: 497 }],
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
          <p>Você será redirecionado para o ambiente seguro do Mercado Pago para concluir o pagamento.</p>
          <button className="btn btn-primary" onClick={handleCheckout} disabled={loading}>
            {loading ? 'Redirecionando…' : 'Pagar com Mercado Pago'}
          </button>
          {error && <p style={{ color: 'var(--cc-danger)', marginTop: 16 }}>{error}</p>}
        </div>
      </section>
    </Layout>
  );
}
