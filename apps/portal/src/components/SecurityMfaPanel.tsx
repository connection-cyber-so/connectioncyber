'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

// M18-G22 — segundo (e último previsto) uso do client Supabase no browser
// deste app, pela mesma razão de exceção do auth/confirm: cadastro/step-up
// de TOTP é inerentemente interativo (mostrar QR, deixar digitar o código,
// reagir a "código errado" sem recarregar a página) e as chamadas
// enroll/challenge/verify da API de MFA só fazem sentido contra a sessão
// viva no navegador. Todo o resto do app continua servidor + formulário.
type Step =
  | 'loading'
  | 'need-enroll'
  | 'enrolling'
  | 'verify-new'
  | 'verifying-new'
  | 'need-step-up'
  | 'verifying-step-up'
  | 'satisfied'
  | 'error';

type EnrollData = { factorId: string; qrCode: string; secret: string };

export function SecurityMfaPanel({ requiresAal2 }: { requiresAal2: boolean }) {
  const router = useRouter();
  const [step, setStep] = useState<Step>('loading');
  const [enrollData, setEnrollData] = useState<EnrollData | null>(null);
  const [existingFactorId, setExistingFactorId] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const supabase = createClient();
      const [{ data: factorsData, error: factorsError }, { data: aalData, error: aalError }] =
        await Promise.all([
          supabase.auth.mfa.listFactors(),
          supabase.auth.mfa.getAuthenticatorAssuranceLevel(),
        ]);
      if (cancelled) return;
      if (factorsError || aalError || !factorsData || !aalData) {
        setError('Não foi possível carregar o estado de segurança da conta. Recarregue a página.');
        setStep('error');
        return;
      }
      if (aalData.currentLevel === 'aal2') {
        setStep('satisfied');
        return;
      }
      const verifiedTotp = factorsData.totp[0];
      if (verifiedTotp) {
        setExistingFactorId(verifiedTotp.id);
        setStep('need-step-up');
        return;
      }
      setStep('need-enroll');
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  async function handleEnroll() {
    setError(null);
    setStep('enrolling');
    const supabase = createClient();

    // A API de MFA recusa um segundo enroll() de TOTP enquanto um fator
    // anterior, mesmo não verificado, ainda existir ("Ativar" de novo depois
    // de um QR que falhou trava pra sempre sem isto). Limpa qualquer
    // resíduo de tentativa anterior antes de pedir um QR novo.
    const { data: existing } = await supabase.auth.mfa.listFactors();
    const staleTotp = existing?.all.find(
      (factor) => factor.factor_type === 'totp' && factor.status === 'unverified'
    );
    if (staleTotp) {
      await supabase.auth.mfa.unenroll({ factorId: staleTotp.id });
    }

    const { data, error: enrollError } = await supabase.auth.mfa.enroll({ factorType: 'totp' });
    if (enrollError || !data) {
      setError('Não foi possível iniciar o cadastro. Tente de novo.');
      setStep('need-enroll');
      return;
    }
    setEnrollData({ factorId: data.id, qrCode: data.totp.qr_code, secret: data.totp.secret });
    setStep('verify-new');
  }

  async function finishWithChallenge(factorId: string, onError: Step) {
    const supabase = createClient();
    const { error: verifyError } = await supabase.auth.mfa.challengeAndVerify({ factorId, code });
    if (verifyError) {
      setError('Código inválido ou expirado. Confira o app autenticador e tente de novo.');
      setStep(onError);
      return;
    }
    setStep('satisfied');
    router.replace('/dashboard');
    router.refresh();
  }

  async function handleVerifyNew(e: React.FormEvent) {
    e.preventDefault();
    if (!enrollData) return;
    setError(null);
    setStep('verifying-new');
    await finishWithChallenge(enrollData.factorId, 'verify-new');
  }

  async function handleVerifyStepUp(e: React.FormEvent) {
    e.preventDefault();
    if (!existingFactorId) return;
    setError(null);
    setStep('verifying-step-up');
    await finishWithChallenge(existingFactorId, 'need-step-up');
  }

  return (
    <section className="security-card">
      <div>
        <span className="eyebrow">Autenticação em duas etapas</span>
        <h2>
          {step === 'satisfied'
            ? 'Ativa nesta sessão'
            : requiresAal2
              ? 'Obrigatória pro seu papel'
              : 'Recomendada'}
        </h2>
      </div>

      {/* .security-card é um grid de 2 colunas (ver globals.css) — um único
          wrapper aqui do lado direito mantém o mesmo layout de 2 células que
          o card do dashboard usa, mesmo trocando de estado. */}
      <div>
      {error ? <div className="alert danger" role="alert">{error}</div> : null}

      {step === 'loading' ? <p className="lead">Carregando…</p> : null}

      {step === 'need-enroll' || step === 'enrolling' ? (
        <>
          <p className="lead">
            Use um app autenticador (Google Authenticator, Authy, 1Password…) pra proteger sua
            conta com um segundo fator, além da senha.
          </p>
          <button
            className="button primary"
            type="button"
            onClick={handleEnroll}
            disabled={step === 'enrolling'}
          >
            {step === 'enrolling' ? 'Gerando…' : 'Ativar autenticação em duas etapas'}
          </button>
        </>
      ) : null}

      {(step === 'verify-new' || step === 'verifying-new') && enrollData ? (
        <form onSubmit={handleVerifyNew} className="form-stack">
          <p className="lead">Escaneie o QR code no seu app autenticador:</p>
          {/* qr_code vem como SVG cru (não codificado) — a doc da Supabase sugere só
              prefixar "data:image/svg+xml;utf-8,", mas o SVG do QR sempre tem cores em
              hex (fill="#000000"): sem escapar, o primeiro "#" vira fragmento da URL e
              trunca a imagem ali, quebrando silenciosamente (confirmado em produção,
              piloto viu o alt-text no lugar do QR). encodeURIComponent evita isto. */}
          {/* eslint-disable-next-line @next/next/no-img-element -- SVG gerado em runtime pela API de MFA, não uma imagem estática pra next/image otimizar. */}
          <img
            src={`data:image/svg+xml;utf-8,${encodeURIComponent(enrollData.qrCode)}`}
            alt="QR code para cadastro do autenticador"
            width={200}
            height={200}
          />
          <p className="fine-print">
            Ou digite manualmente: <code>{enrollData.secret}</code>
          </p>
          <label>
            Código de 6 dígitos
            <input
              type="text"
              inputMode="numeric"
              pattern="[0-9]{6}"
              maxLength={6}
              required
              autoComplete="one-time-code"
              value={code}
              disabled={step === 'verifying-new'}
              onChange={(e) => setCode(e.target.value)}
            />
          </label>
          <button className="button primary" type="submit" disabled={step === 'verifying-new'}>
            {step === 'verifying-new' ? 'Confirmando…' : 'Confirmar e ativar'}
          </button>
        </form>
      ) : null}

      {step === 'need-step-up' || step === 'verifying-step-up' ? (
        <form onSubmit={handleVerifyStepUp} className="form-stack">
          <p className="lead">Confirme com o código do seu app autenticador pra continuar.</p>
          <label>
            Código de 6 dígitos
            <input
              type="text"
              inputMode="numeric"
              pattern="[0-9]{6}"
              maxLength={6}
              required
              autoComplete="one-time-code"
              value={code}
              disabled={step === 'verifying-step-up'}
              onChange={(e) => setCode(e.target.value)}
            />
          </label>
          <button className="button primary" type="submit" disabled={step === 'verifying-step-up'}>
            {step === 'verifying-step-up' ? 'Confirmando…' : 'Confirmar'}
          </button>
        </form>
      ) : null}

      {step === 'satisfied' ? (
        <p className="lead">Sessão validada com autenticação em duas etapas.</p>
      ) : null}
      {step === 'error' ? <p className="fine-print">Se o problema continuar, fale com o suporte.</p> : null}
      </div>
    </section>
  );
}
