import React from 'react';
import Link from 'next/link';
import Layout from '@/components/Layout';
import ServiceCard from '@/components/ServiceCard';
import { useLanguage } from '@/context/LanguageContext';
import { routes } from '@/config/routes';

export default function ServicosPage() {
  const { t } = useLanguage();
  const services = t('services.items') as { title: string; description: string; bullets: string[] }[];

  return (
    <Layout title={t('services.title')} description={t('services.subtitle')}>
      <section className="section">
        <div className="container" style={{ maxWidth: 780 }}>
          <div className="eyebrow">{t('nav.services')}</div>
          <h1>{t('services.title')}</h1>
          <p style={{ fontSize: '1.05rem' }}>{t('services.subtitle')}</p>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <div className="grid grid-3">
            {services.map((s) => (
              <ServiceCard key={s.title} title={s.title} description={s.description} bullets={s.bullets} />
            ))}
          </div>
        </div>
      </section>

      <section className="section" style={{ textAlign: 'center' }}>
        <div className="container">
          <h2>{t('home.finalCtaTitle')}</h2>
          <Link href={routes.contato} className="btn btn-primary">
            {t('home.ctaPrimary')}
          </Link>
        </div>
      </section>
    </Layout>
  );
}
