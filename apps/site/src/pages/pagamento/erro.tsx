import React from 'react';
import Link from 'next/link';
import Layout from '@/components/Layout';
import { routes } from '@/config/routes';

export default function PagamentoErroPage() {
  return (
    <Layout title="Falha no pagamento">
      <section className="section" style={{ textAlign: 'center' }}>
        <div className="container" style={{ maxWidth: 560 }}>
          <div style={{ fontSize: 48, marginBottom: 16 }}>⚠️</div>
          <h1>Não foi possível concluir o pagamento</h1>
          <p>Verifique os dados informados ou tente novamente. Se o problema persistir, fale com nosso suporte.</p>
          <div style={{ display: 'flex', gap: 12, justifyContent: 'center' }}>
            <Link href={routes.checkout} className="btn btn-primary">
              Tentar novamente
            </Link>
            <Link href={routes.contato} className="btn btn-outline-dark">
              Falar com suporte
            </Link>
          </div>
        </div>
      </section>
    </Layout>
  );
}
