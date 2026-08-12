import React from 'react';
import Layout from '@/components/Layout';
import { useLanguage } from '@/context/LanguageContext';

export default function SistemaPage() {
  const { t } = useLanguage();

  return (
    <Layout title={t('nav.system')}>
      <section className="section">
        <div className="container" style={{ maxWidth: 820 }}>
          <div className="eyebrow">{t('nav.system')}</div>
          <h1>Mapa Arquitetural Enterprise</h1>
          <p style={{ fontSize: '1.05rem' }}>
            Visualização interativa dos clusters de negócio, módulos internos, dependências e status da
            arquitetura tecnológica da ConnectionCyber — mapa, heatmap, física, órbitas e modo de segurança.
          </p>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <iframe
            src="/enterprise-system.html"
            title="Sistema Visual Enterprise ConnectionCyber"
            className="enterprise-frame"
          />
        </div>
      </section>
    </Layout>
  );
}
