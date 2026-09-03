import React, { useState } from 'react';
import { useRouter } from 'next/router';
import Layout from '@/components/Layout';
import { isSupabaseConfigured } from '@/config/env';
import { signInWithPassword } from '@/lib/auth';
import { safeSiteRedirect } from '@/domain/redirect';
import { buildCompanyPortalLoginUrl } from '@/domain/companyPortal';

// M19-G5 — "Fazer Login" virou um seletor de 3 caminhos, sem lookup de
// e-mail pré-login (ver STATUS-MESTRE-DESENVOLVIMENTO.md, M19-G5, pro
// porquê): aluno/academy autentica aqui mesmo; equipe é só texto — sem
// link — preservando a decisão de apps/platform não ter ponto de entrada
// público; empresa digita o próprio slug/domínio e navega pro portal dela,
// onde a autenticação real acontece (apps/portal já hardened, sem mudança).
export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [status, setStatus] = useState<'idle' | 'sending' | 'error'>('idle');
  const [error, setError] = useState<string | null>(null);

  const [companyInput, setCompanyInput] = useState('');
  const [companyError, setCompanyError] = useState<string | null>(null);

  async function handleAlunoSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus('sending');
    setError(null);
    try {
      await signInWithPassword(email, password);
      router.replace(safeSiteRedirect(router.query.redirect));
    } catch (err: any) {
      setStatus('error');
      setError(err?.message ?? 'Não foi possível entrar. Verifique e-mail e senha.');
    }
  }

  function handleCompanySubmit(e: React.FormEvent) {
    e.preventDefault();
    const url = buildCompanyPortalLoginUrl(companyInput);
    if (!url) {
      setCompanyError('Digite o nome (slug) da empresa ou o domínio completo do portal.');
      return;
    }
    setCompanyError(null);
    window.location.href = url;
  }

  return (
    <Layout title="Entrar">
      <section className="section" style={{ minHeight: '60vh' }}>
        <div className="container" style={{ maxWidth: 640 }}>
          <div className="eyebrow">Acesso</div>
          <h1>Como você quer entrar?</h1>

          <div className="card" style={{ marginTop: 20 }}>
            <h2 style={{ marginTop: 0, fontSize: '1.05rem' }}>Sou aluno ou faço parte da Academy</h2>

            {!isSupabaseConfigured && (
              <div
                className="card"
                style={{ marginBottom: 16, borderColor: 'var(--cc-warning)', background: 'var(--cc-bg-alt)' }}
              >
                <p style={{ margin: 0, fontSize: '0.85rem' }}>
                  Login ainda não está ativo neste ambiente — o Supabase não está configurado
                  (<code>NEXT_PUBLIC_SUPABASE_URL</code> / <code>NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY</code>
                  ausentes). Preencha o <code>.env.local</code> para habilitar a autenticação real.
                </p>
              </div>
            )}

            <form onSubmit={handleAlunoSubmit} style={{ display: 'grid', gap: 14 }}>
              <input
                required
                type="email"
                placeholder="E-mail"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                style={inputStyle}
              />
              <input
                required
                type="password"
                placeholder="Senha"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                style={inputStyle}
              />
              <button type="submit" className="btn btn-primary" disabled={status === 'sending'}>
                {status === 'sending' ? 'Entrando…' : 'Entrar'}
              </button>
              {status === 'error' && <p style={{ color: 'var(--cc-danger)', margin: 0 }}>{error}</p>}
            </form>
          </div>

          <div className="card" style={{ marginTop: 16 }}>
            <h2 style={{ marginTop: 0, fontSize: '1.05rem' }}>Sou da equipe ConnectionCyber</h2>
            <p style={{ margin: 0, fontSize: '0.9rem', color: 'var(--cc-text-muted)' }}>
              Acesse diretamente pelo endereço{' '}
              <code>platform.connectioncyber.com.br</code> — o painel interno não fica acessível
              por link público neste site.
            </p>
          </div>

          <div className="card" style={{ marginTop: 16 }}>
            <h2 style={{ marginTop: 0, fontSize: '1.05rem' }}>Sou empresa com portal próprio</h2>
            <p style={{ margin: '0 0 14px', fontSize: '0.9rem', color: 'var(--cc-text-muted)' }}>
              Digite o nome (slug) da sua empresa ou o domínio completo do seu portal. A
              autenticação real acontece lá — nada é enviado por aqui.
            </p>
            <form onSubmit={handleCompanySubmit} style={{ display: 'grid', gap: 14 }}>
              <input
                required
                type="text"
                placeholder="ex: suaempresa"
                value={companyInput}
                onChange={(e) => setCompanyInput(e.target.value)}
                style={inputStyle}
              />
              <button type="submit" className="btn btn-primary">
                Ir para o portal da empresa
              </button>
              {companyError && <p style={{ color: 'var(--cc-danger)', margin: 0 }}>{companyError}</p>}
            </form>
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
