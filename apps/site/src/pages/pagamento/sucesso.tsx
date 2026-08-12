import React from 'react';
import Link from 'next/link';
import Layout from '@/components/Layout';
import { routes } from '@/config/routes';

export default function PagamentoSucessoPage() {
  return (
    <Layout title="Pagamento aprovado">
      <section className="section" style={{ textAlign: 'center' }}>
        <div className="container" style={{ maxWidth: 560 }}>
          <div style={{ fontSize: 48, marginBottom: 16 }}>✅</div>
          <h1>Pagamento confirmado!</h1>
          <p>Obrigado. Seu pedido foi processado com sucesso e você receberá a confirmação por e-mail.</p>
          <Link href={routes.home} className="btn btn-primary">
            Voltar ao início
          </Link>
        </div>
      </section>
    </Layout>
  );
}
