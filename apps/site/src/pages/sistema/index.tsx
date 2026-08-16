import React, { useRef, useState } from 'react';
import Layout from '@/components/Layout';
import { useLanguage } from '@/context/LanguageContext';

const MAP_MODES: { key: string; label: string }[] = [
  { key: 'enterprise', label: 'Enterprise' },
  { key: 'heatmap', label: 'Heatmap' },
  { key: 'fisica', label: 'Física' },
  { key: 'orbita', label: 'Órbita' },
  { key: 'ia', label: 'IA' },
  { key: 'seguranca', label: 'Segurança' },
];

export default function SistemaPage() {
  const { t } = useLanguage();
  const iframeRef = useRef<HTMLIFrameElement>(null);
  const [activeMode, setActiveMode] = useState('enterprise');

  function handleModeChange(modeKey: string) {
    setActiveMode(modeKey);
    // O mapa roda dentro de um <iframe> same-origin (public/enterprise-system.html) —
    // postMessage troca o modo ao vivo, sem recarregar o iframe nem perder zoom/posição.
    iframeRef.current?.contentWindow?.postMessage(
      { type: 'connectioncyber:set-mode', mode: modeKey },
      window.location.origin
    );
  }

  return (
    <Layout title={t('nav.system')}>
      <section className="section">
        <div className="container" style={{ maxWidth: 1000 }}>
          <div className="eyebrow">{t('nav.system')}</div>
          <h1>Mapa Arquitetural Enterprise</h1>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 24, alignItems: 'flex-start', justifyContent: 'space-between' }}>
            <p style={{ fontSize: '1.05rem', flex: '1 1 420px', margin: 0 }}>
              Visualização interativa dos clusters de negócio, módulos internos, dependências e status da
              arquitetura tecnológica da ConnectionCyber — mapa, heatmap, física, órbitas e modo de segurança.
            </p>

            <div className="card" style={{ padding: 16, width: 240, flexShrink: 0 }}>
              <div
                style={{
                  fontSize: '0.7rem',
                  textTransform: 'uppercase',
                  letterSpacing: '0.08em',
                  color: 'var(--cc-text-muted)',
                  fontWeight: 700,
                  marginBottom: 10,
                }}
              >
                Estilo do mapa
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {MAP_MODES.map((m) => (
                  <button
                    key={m.key}
                    type="button"
                    onClick={() => handleModeChange(m.key)}
                    aria-pressed={activeMode === m.key}
                    style={{
                      padding: '6px 12px',
                      borderRadius: 999,
                      border: '1.5px solid var(--cc-orange)',
                      background: activeMode === m.key ? 'var(--cc-primary)' : 'transparent',
                      color: activeMode === m.key ? 'var(--cc-white)' : 'var(--cc-text)',
                      fontSize: '0.78rem',
                      fontWeight: 600,
                      cursor: 'pointer',
                    }}
                  >
                    {m.label}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <iframe
            ref={iframeRef}
            src="/enterprise-system.html"
            title="Sistema Visual Enterprise ConnectionCyber"
            className="enterprise-frame"
          />
        </div>
      </section>
    </Layout>
  );
}
