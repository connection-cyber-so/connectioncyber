'use client';

import { useState, Suspense } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { isSupabaseConfigured } from '@/config/env';

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [status, setStatus] = useState<'idle' | 'sending' | 'error'>('idle');
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setStatus('sending');
    setError(null);
    try {
      const supabase = createClient();
      const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
      if (authError) throw authError;

      const redirectTarget = searchParams.get('redirect') ?? '/';
      router.replace(redirectTarget);
      router.refresh();
    } catch (err: any) {
      setStatus('error');
      setError(err?.message ?? 'Não foi possível entrar. Verifique e-mail e senha.');
    }
  }

  return (
    <div className="pf-shell">
      <main className="pf-main">
        <div className="pf-card">
          <div className="pf-eyebrow">ConnectionCyberSO · Painel Interno</div>
          <h1 className="pf-title">Entrar</h1>

          {!isSupabaseConfigured && (
            <div className="pf-notice">
              Login ainda não está ativo neste ambiente — o Supabase não está configurado
              (<code>NEXT_PUBLIC_SUPABASE_URL</code> / <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code>{' '}
              ausentes). Preencha o <code>.env.local</code> apontando para o projeto de staging.
            </div>
          )}

          <form onSubmit={handleSubmit}>
            <div className="pf-field">
              <label htmlFor="email">E-mail</label>
              <input
                id="email"
                required
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div className="pf-field">
              <label htmlFor="password">Senha</label>
              <input
                id="password"
                required
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            <button className="pf-button" type="submit" disabled={status === 'sending'}>
              {status === 'sending' ? 'Entrando…' : 'Entrar'}
            </button>
            {status === 'error' && <p className="pf-error">{error}</p>}
          </form>
        </div>
      </main>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense fallback={null}>
      <LoginForm />
    </Suspense>
  );
}
