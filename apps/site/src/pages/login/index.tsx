import React, { useState } from 'react';
import { useRouter } from 'next/router';
import Layout from '@/components/Layout';
import { isSupabaseConfigured } from '@/config/env';
import { signInWithPassword } from '@/lib/auth';
import { routes } from '@/config/routes';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [status, setStatus] = useState<'idle' | 'sending' | 'error'>('idle');
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus('sending');
    setError(null);
    try {
      await signInWithPassword(email, password);
      const redirectTarget =
        typeof router.query.redirect === 'string' ? router.query.redirect : routes.membros;
      router.replace(redirectTarget);
    } catch (err: any) {
      setStatus('error');
      setError(err?.message ?? 'Não foi possível entrar. Verifique e-mail e senha.');
    }
  }

  return (
    <Layout title="Entrar">
      <section className="section" style={{ minHeight: '60vh', display: 'flex', alignItems: 'center' }}>
        <div className="container" style={{ maxWidth: 420 }}>
          <div className="eyebrow">Área de Alunos</div>
          <h1>Entrar</h1>

          {!isSupabaseConfigured && (
            <div
              className="card"
              style={{ marginBottom: 20, borderColor: 'var(--cc-warning)', background: 'var(--cc-bg-alt)' }}
            >
              <p style={{ margin: 0, fontSize: '0.85rem' }}>
                Login ainda não está ativo neste ambiente — o Supabase não está configurado
                (<code>NEXT_PUBLIC_SUPABASE_URL</code> / <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code>
                ausentes). Preencha o <code>.env.local</code> para habilitar a autenticação real.
              </p>
            </div>
          )}

          <form onSubmit={handleSubmit} className="card" style={{ display: 'grid', gap: 14 }}>
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
