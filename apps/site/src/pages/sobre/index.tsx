import React from 'react';
import Layout from '@/components/Layout';
import { useLanguage } from '@/context/LanguageContext';

export default function SobrePage() {
  const { t } = useLanguage();
  const values = t('about.values') as string[];

  return (
    <Layout title={t('about.title')} description={t('about.intro')}>
      <section className="section">
        <div className="container" style={{ maxWidth: 820 }}>
          <div className="eyebrow">{t('nav.about')}</div>
          <h1>{t('about.title')}</h1>
          <p style={{ fontSize: '1.05rem' }}>{t('about.intro')}</p>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <div className="grid grid-2">
            <div className="card">
              <h3>{t('about.missionTitle')}</h3>
              <p>{t('about.mission')}</p>
            </div>
            <div className="card">
              <h3>{t('about.visionTitle')}</h3>
              <p>{t('about.vision')}</p>
            </div>
          </div>
        </div>
      </section>

      <section className="section">
        <div className="container">
          <div className="stripe-accent" />
          <h2>{t('about.valuesTitle')}</h2>
          <div className="grid grid-3" style={{ marginTop: 24 }}>
            {values.map((v) => (
              <div key={v} className="card">
                {v}
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container" style={{ maxWidth: 820 }}>
          <div className="stripe-accent" />
          <h2>{t('about.historyTitle')}</h2>
          <p style={{ fontSize: '1.05rem' }}>{t('about.history')}</p>
        </div>
      </section>
    </Layout>
  );
}
