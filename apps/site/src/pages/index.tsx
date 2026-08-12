import React from 'react';
import Link from 'next/link';
import Layout from '@/components/Layout';
import ServiceCard from '@/components/ServiceCard';
import ClientCard from '@/components/ClientCard';
import { useLanguage } from '@/context/LanguageContext';
import { routes } from '@/config/routes';
import { clientPortfolio } from '@/config/clients';

export default function HomePage() {
  const { t } = useLanguage();
  const services = t('services.items') as { title: string; description: string; bullets: string[] }[];
  const differentiators = t('home.differentiators') as string[];

  return (
    <Layout>
      {/* Hero */}
      <section
        className="section"
        style={{
          background: 'linear-gradient(135deg, var(--cc-primary-dark), var(--cc-primary))',
          color: '#fff',
        }}
      >
        <div className="container" style={{ maxWidth: 780 }}>
          <div className="eyebrow" style={{ color: 'var(--cc-teal)' }}>
            {t('brand.slogan')}
          </div>
          <h1 style={{ color: '#fff' }}>{t('home.heroTitle')}</h1>
          <p style={{ color: 'rgba(255,255,255,0.82)', fontSize: '1.1rem' }}>{t('home.heroSubtitle')}</p>
          <div style={{ display: 'flex', gap: 16, marginTop: 28, flexWrap: 'wrap' }}>
            <Link href={routes.contato} className="btn btn-primary">
              {t('home.ctaPrimary')}
            </Link>
            <Link href={routes.servicos} className="btn btn-outline">
              {t('home.ctaSecondary')}
            </Link>
          </div>
        </div>
      </section>

      {/* Sobre resumo */}
      <section className="section">
        <div className="container" style={{ maxWidth: 820 }}>
          <div className="stripe-accent" />
          <h2>{t('home.aboutTitle')}</h2>
          <p style={{ fontSize: '1.05rem' }}>{t('home.aboutText')}</p>
        </div>
      </section>

      {/* Serviços */}
      <section className="section section-alt">
        <div className="container">
          <div className="stripe-accent" />
          <h2>{t('home.servicesTitle')}</h2>
          <div className="grid grid-3" style={{ marginTop: 32 }}>
            {services.map((s) => (
              <ServiceCard key={s.title} title={s.title} description={s.description} bullets={s.bullets} />
            ))}
          </div>
        </div>
      </section>

      {/* Diferenciais */}
      <section className="section">
        <div className="container">
          <div className="stripe-accent" />
          <h2>{t('home.differentiatorsTitle')}</h2>
          <div className="grid grid-2" style={{ marginTop: 24 }}>
            {differentiators.map((d) => (
              <div key={d} className="card" style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <span
                  style={{
                    width: 10,
                    height: 10,
                    borderRadius: '50%',
                    background: 'var(--cc-teal)',
                    flexShrink: 0,
                  }}
                />
                <span>{d}</span>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Clientes */}
      <section className="section section-alt">
        <div className="container">
          <div className="stripe-accent" />
          <h2>{t('home.clientsTitle')}</h2>
          <div className="grid grid-4" style={{ marginTop: 32 }}>
            {clientPortfolio.slice(0, 8).map((c) => (
              <ClientCard key={c.id} client={c} />
            ))}
          </div>
          <div style={{ marginTop: 28 }}>
            <Link href={routes.clientes} className="btn btn-outline-dark">
              {t('nav.clients')} →
            </Link>
          </div>
        </div>
      </section>

      {/* CTA final */}
      <section
        className="section"
        style={{ background: 'var(--cc-primary-dark)', color: '#fff', textAlign: 'center' }}
      >
        <div className="container">
          <h2 style={{ color: '#fff' }}>{t('home.finalCtaTitle')}</h2>
          <p style={{ color: 'rgba(255,255,255,0.82)', maxWidth: 560, margin: '0 auto 28px' }}>
            {t('home.finalCtaSubtitle')}
          </p>
          <Link href={routes.contato} className="btn btn-primary">
            {t('home.finalCtaButton')}
          </Link>
        </div>
      </section>
    </Layout>
  );
}
