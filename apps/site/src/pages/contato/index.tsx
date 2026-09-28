import React, { useState } from 'react';
import Layout from '@/components/Layout';
import { useLanguage } from '@/context/LanguageContext';
import { socialLinks } from '@/config/routes';

export default function ContatoPage() {
  const { t } = useLanguage();
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle');
  const [form, setForm] = useState({ nome: '', email: '', telefone: '', empresa: '', mensagem: '' });

  function update<K extends keyof typeof form>(key: K, value: string) {
    setForm((f) => ({ ...f, [key]: value }));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus('sending');
    try {
      const res = await fetch('/api/contato', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form),
      });
      if (!res.ok) throw new Error('Falha no envio');
      setStatus('sent');
      setForm({ nome: '', email: '', telefone: '', empresa: '', mensagem: '' });
    } catch {
      setStatus('error');
    }
  }

  return (
    <Layout title={t('contact.title')} description={t('contact.subtitle')}>
      <section className="section">
        <div className="container" style={{ maxWidth: 780 }}>
          <div className="eyebrow">{t('nav.contact')}</div>
          <h1>{t('contact.title')}</h1>
          <p style={{ fontSize: '1.05rem' }}>{t('contact.subtitle')}</p>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <div className="grid grid-2" style={{ alignItems: 'flex-start' }}>
            <form onSubmit={handleSubmit} className="card" style={{ display: 'grid', gap: 14 }}>
              <input
                name="website"
                autoComplete="off"
                tabIndex={-1}
                aria-hidden="true"
                style={{ position: 'absolute', left: '-10000px' }}
              />
              <input
                required
                placeholder={t('contact.formName')}
                value={form.nome}
                onChange={(e) => update('nome', e.target.value)}
                style={inputStyle}
              />
              <input
                required
                type="email"
                placeholder={t('contact.formEmail')}
                value={form.email}
                onChange={(e) => update('email', e.target.value)}
                style={inputStyle}
              />
              <input
                placeholder={t('contact.formPhone')}
                value={form.telefone}
                onChange={(e) => update('telefone', e.target.value)}
                style={inputStyle}
              />
              <input
                placeholder={t('contact.formCompany')}
                value={form.empresa}
                onChange={(e) => update('empresa', e.target.value)}
                style={inputStyle}
              />
              <textarea
                required
                rows={5}
                placeholder={t('contact.formMessage')}
                value={form.mensagem}
                onChange={(e) => update('mensagem', e.target.value)}
                style={inputStyle}
              />
              <button type="submit" className="btn btn-primary" disabled={status === 'sending'}>
                {status === 'sending' ? '…' : t('contact.formSubmit')}
              </button>
              {status === 'sent' && (
                <p style={{ color: 'var(--cc-success)' }}>Mensagem enviada com sucesso!</p>
              )}
              {status === 'error' && (
                <p style={{ color: 'var(--cc-danger)' }}>
                  Não foi possível enviar agora. Tente novamente ou use o WhatsApp.
                </p>
              )}
            </form>

            <div className="card">
              <h3>Canais diretos</h3>
              <p>{t('contact.location')}</p>
              <p>
                <a href={`tel:${t('contact.phone').replace(/[^\d+]/g, '')}`}>{t('contact.phone')}</a>
              </p>
              <p>
                <a href={socialLinks.whatsapp} target="_blank" rel="noreferrer">
                  WhatsApp
                </a>
              </p>
              <p>
                <a href={`mailto:${t('contact.email')}`}>{t('contact.email')}</a>
              </p>
            </div>
          </div>
        </div>
      </section>
    </Layout>
  );
}

const inputStyle: React.CSSProperties = {
  padding: '12px 14px',
  border: '1px solid var(--cc-teal)',
  borderRadius: 8,
  fontSize: '0.95rem',
  fontFamily: 'inherit',
};
