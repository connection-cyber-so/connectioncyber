import React from 'react';
import { ClientEntry } from '@/config/clients';
import { useLanguage } from '@/context/LanguageContext';

export default function ClientCard({ client }: { client: ClientEntry }) {
  const { t } = useLanguage();

  return (
    <div className="card" style={{ textAlign: 'center' }}>
      <div
        style={{
          width: 64,
          height: 64,
          margin: '0 auto 16px',
          borderRadius: '50%',
          background: 'var(--cc-bg-alt)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontWeight: 800,
          color: 'var(--cc-primary)',
          overflow: 'hidden',
        }}
      >
        {client.logoUrl ? (
          <img src={client.logoUrl} alt={client.nome} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        ) : (
          client.nome.charAt(0)
        )}
      </div>
      <h4 style={{ marginBottom: 4 }}>{client.nome}</h4>
      <span className="badge">
        {client.anosParceria} {t('clients.yearsLabel')}
      </span>
      <p style={{ fontSize: '0.85rem', marginTop: 12 }}>{client.segmento}</p>
      <p style={{ fontSize: '0.8rem', color: 'var(--cc-text-muted)' }}>{client.servicos.join(' · ')}</p>
    </div>
  );
}
