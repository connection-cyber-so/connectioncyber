'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { PublicFrame } from '@/components/PublicFrame';
import { createClient } from '@/lib/supabase/client';

// M18-G22 — único lugar do app que precisa de client Supabase no browser:
// convite/link mágico do Supabase Auth manda o token no FRAGMENTO da URL
// (#access_token=...), que nunca chega ao servidor (Server Component/Route
// Handler não veem location.hash) — então ler o fragmento e chamar
// setSession() é obrigatoriamente client-side. Depois disso, tudo volta a
// ser 100% servidor: a própria troca de senha e a ativação da membership
// (RPC erp_accept_pending_memberships_v1, migration 0036) usam a sessão
// que setSession() acabou de estabelecer, validada de novo no servidor.
type Step = 'checking' | 'error' | 'set-password' | 'saving' | 'done';

const ERROR_MESSAGES: Record<string, string> = {
  otp_expired: 'Este link já foi usado ou expirou. Peça um novo convite.',
  access_denied: 'Não foi possível confirmar o acesso. Peça um novo convite.',
};

export default function ConfirmPage() {
  const router = useRouter();
  const [step, setStep] = useState<Step>('checking');
  const [error, setError] = useState<string | null>(null);
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  useEffect(() => {
    const hash = new URLSearchParams(window.location.hash.replace(/^#/, ''));
    const errorCode = hash.get('error_code') ?? hash.get('error');
    if (errorCode) {
      setError(ERROR_MESSAGES[errorCode] ?? 'Não foi possível confirmar o acesso. Peça um novo convite.');
      setStep('error');
      return;
    }

    const accessToken = hash.get('access_token');
    const refreshToken = hash.get('refresh_token');
    if (!accessToken || !refreshToken) {
      setError('Link incompleto. Peça um novo convite.');
      setStep('error');
      return;
    }

    const supabase = createClient();
    supabase.auth.setSession({ access_token: accessToken, refresh_token: refreshToken }).then(({ error: sessionError }) => {
      // Limpa o token da URL assim que possível — nunca deixar sobreviver
      // em histórico do navegador, referrer ou compartilhamento de tela.
      window.history.replaceState(null, '', window.location.pathname);
      if (sessionError) {
        setError('Não foi possível confirmar o acesso. Peça um novo convite.');
        setStep('error');
        return;
      }
      setStep('set-password');
    });
  }, []);

  async function handleSetPassword(e: React.FormEvent) {
    e.preventDefault();
    if (password.length < 8) {
      setError('A senha precisa ter pelo menos 8 caracteres.');
      return;
    }
    if (password !== confirmPassword) {
      setError('As senhas não coincidem.');
      return;
    }
    setError(null);
    setStep('saving');
    const supabase = createClient();
    const { error: updateError } = await supabase.auth.updateUser({ password });
    if (updateError) {
      setError('Não foi possível salvar a senha. Tente de novo.');
      setStep('set-password');
      return;
    }
    // Ativa a(s) própria membership(s) invited — sem isto o login funciona
    // mas o portal continua recusando acesso (status fica 'invited').
    const { error: acceptError } = await supabase.rpc('erp_accept_pending_memberships_v1');
    if (acceptError) {
      setError('Senha salva, mas não foi possível ativar o acesso à empresa. Fale com o suporte.');
      setStep('set-password');
      return;
    }
    setStep('done');
    router.replace('/');
    router.refresh();
  }

  return (
    <PublicFrame>
      <span className="eyebrow">Acesso certificado</span>
      <h1>Confirmar acesso</h1>

      {step === 'checking' && <p className="lead">Confirmando seu convite…</p>}

      {step === 'error' && (
        <>
          <div className="alert danger" role="alert">{error}</div>
          <p className="fine-print">Peça pra equipe reenviar o convite com o e-mail certo.</p>
        </>
      )}

      {(step === 'set-password' || step === 'saving') && (
        <>
          <p className="lead">Convite confirmado. Defina sua senha pra entrar.</p>
          {error ? <div className="alert danger" role="alert">{error}</div> : null}
          <form onSubmit={handleSetPassword} className="form-stack">
            <label>
              Nova senha
              <input
                type="password"
                minLength={8}
                required
                autoComplete="new-password"
                value={password}
                disabled={step === 'saving'}
                onChange={(e) => setPassword(e.target.value)}
              />
            </label>
            <label>
              Confirmar senha
              <input
                type="password"
                minLength={8}
                required
                autoComplete="new-password"
                value={confirmPassword}
                disabled={step === 'saving'}
                onChange={(e) => setConfirmPassword(e.target.value)}
              />
            </label>
            <button className="button primary" type="submit" disabled={step === 'saving'}>
              {step === 'saving' ? 'Salvando…' : 'Salvar senha e entrar'}
            </button>
          </form>
        </>
      )}

      {step === 'done' && <p className="lead">Tudo certo. Entrando…</p>}
    </PublicFrame>
  );
}
