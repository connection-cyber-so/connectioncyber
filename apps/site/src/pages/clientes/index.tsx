import React from 'react';
import Layout from '@/components/Layout';
import ClientCard from '@/components/ClientCard';
import { useLanguage } from '@/context/LanguageContext';
import { clientPortfolio } from '@/config/clients';

export default function ClientesPage() {
  const { t } = useLanguage();

  return (
    <Layout title={t('clients.title')} description={t('clients.description')}>
      <section className="section">
        <div className="container" style={{ maxWidth: 820 }}>
          <div className="eyebrow">{t('nav.clients')}</div>
          <h1>{t('clients.title')}</h1>
          <p style={{ fontSize: '1.05rem' }}>{t('clients.description')}</p>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <div className="grid grid-4">
            {clientPortfolio.map((c) => (
              <ClientCard key={c.id} client={c} />
            ))}
          </div>
        </div>
      </section>
    </Layout>
  );
}
