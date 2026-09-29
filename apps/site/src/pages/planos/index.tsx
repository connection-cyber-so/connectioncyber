import React, { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/router';
import type { GetServerSideProps } from 'next';
import Layout from '@/components/Layout';
import { isMercadoPagoEnabled } from '@/config/env';
import { getCurrentSession } from '@/lib/auth';
import { getSupabaseClient } from '@/lib/supabaseClient';
import { parseTenantSignup, slugify, VERTICALS } from '@/lib/subscriptionValidation';

interface PlanRow {
  id: string;
  code: string;
  name: string;
  description: string | null;
  price_cents: number;
  currency: string;
  trial_days: number;
  capabilities: string[];
}

interface PlanosPageProps {
  paymentsEnabled: boolean;
}

const EMPTY_FORM = {
  displayName: '',
  legalName: '',
  cnpj: '',
  stateRegistration: '',
  vertical: 'varejo',
  slug: '',
  domain: '',
};

export default function PlanosPage({ paymentsEnabled }: PlanosPageProps) {
  const router = useRouter();
  const [plans, setPlans] = useState<PlanRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [selectedPlan, setSelectedPlan] = useState<string | null>(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [slugEdited, setSlugEdited] = useState(false);
  const [domainEdited, setDomainEdited] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const supabase = getSupabaseClient();
    supabase
      .from('saas_plans')
      .select(
        'id, code, name, description, price_cents, currency, trial_days, saas_plan_capabilities(capability_key)',
      )
      .eq('active', true)
      .order('price_cents')
      .then(({ data, error }) => {
        if (error) {
          setLoadError('Não foi possível carregar os planos agora.');
          return;
        }
        const rows: PlanRow[] = (data ?? []).map(
          (row: Record<string, unknown>) => ({
            id: String(row.id),
            code: String(row.code),
            name: String(row.name),
            description: (row.description as string | null) ?? null,
            price_cents: Number(row.price_cents),
            currency: String(row.currency ?? 'BRL'),
            trial_days: Number(row.trial_days ?? 0),
            capabilities: ((row.saas_plan_capabilities as Array<{ capability_key: string }>) ?? []).map(
              (cap) => cap.capability_key,
            ),
          }),
        );
        setPlans(rows);
        setSelectedPlan((current) => current ?? rows[0]?.code ?? null);
      });
  }, []);

  const slugPreview = useMemo(
    () => slugify(form.displayName || '') || 'sua-empresa',
    [form.displayName],
  );

  function update(field: keyof typeof EMPTY_FORM, value: string) {
    setForm((current) => {
      const next = { ...current, [field]: value };
      if (field === 'displayName') {
        if (!slugEdited) next.slug = slugify(value);
        if (!domainEdited) next.domain = `${slugify(value)}.connectioncyber.com.br`;
      }
      return next;
    });
    setError(null);
  }

  async function handleSubscribe() {
    setError(null);
    const slug = form.slug || slugPreview;
    const tenant = parseTenantSignup({
      ...form,
      slug,
      domain: form.domain || `${slug}.connectioncyber.com.br`,
    });
    if (!tenant) {
      setError('Revise os dados da empresa: nome, razão social, CNPJ e Inscrição Estadual são obrigatórios.');
      return;
    }
    setSubmitting(true);
    try {
      const session = await getCurrentSession();
      if (!session) {
        router.push('/login?redirect=/planos');
        return;
      }
      const res = await fetch('/api/payments/create-subscription', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({ planCode: selectedPlan, tenant }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? 'Não foi possível iniciar a assinatura');
      window.location.href = data.checkoutUrl;
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro inesperado');
      setSubmitting(false);
    }
  }

  return (
    <Layout title="Planos">
      <section className="section">
        <div className="container" style={{ maxWidth: 900 }}>
          <div className="eyebrow">Assinatura mensal</div>
          <h1>Planos ConnectionCyber</h1>
          <p style={{ fontSize: '1.05rem' }}>
            Pague com cartão salvo no Mercado Pago. Assim que o primeiro pagamento for aprovado,
            sua empresa é criada automaticamente e você recebe acesso com credenciais próprias.
          </p>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container" style={{ maxWidth: 900 }}>
          {loadError && <p style={{ color: 'var(--cc-danger)' }}>{loadError}</p>}
          {!plans && !loadError && <p>Carregando planos…</p>}
          {plans && plans.length === 0 && <p>Nenhum plano disponível no momento.</p>}

          {plans && plans.length > 0 && (
            <div className="grid grid-2" style={{ gap: 18 }}>
              {plans.map((plan) => {
                const selected = plan.code === selectedPlan;
                return (
                  <div
                    key={plan.id}
                    className="card"
                    style={{
                      display: 'grid',
                      gap: 10,
                      cursor: 'pointer',
                      outline: selected ? '2px solid var(--cc-primary, #4f8cff)' : undefined,
                    }}
                    onClick={() => setSelectedPlan(plan.code)}
                  >
                    <h3 style={{ margin: 0 }}>{plan.name}</h3>
                    <p style={{ margin: 0, fontSize: '1.6rem', fontWeight: 700 }}>
                      R$ {(plan.price_cents / 100).toFixed(2).replace('.', ',')}
                      <span style={{ fontSize: '0.95rem', fontWeight: 400 }}> /mês</span>
                    </p>
                    {plan.description && <p style={{ margin: 0 }}>{plan.description}</p>}
                    <ul style={{ margin: 0, paddingLeft: 18, fontSize: '0.95rem' }}>
                      {plan.capabilities.map((capability) => (
                        <li key={capability}>{capability}</li>
                      ))}
                    </ul>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </section>

      <section className="section">
        <div className="container" style={{ maxWidth: 780 }}>
          <h2>Dados da sua empresa</h2>
          <form
            className="card"
            style={{ display: 'grid', gap: 14 }}
            onSubmit={(event) => {
              event.preventDefault();
              void handleSubscribe();
            }}
          >
            <input
              required
              placeholder="Nome da empresa (como será exibida)"
              value={form.displayName}
              onChange={(event) => update('displayName', event.target.value)}
            />
            <input
              required
              placeholder="Razão social"
              value={form.legalName}
              onChange={(event) => update('legalName', event.target.value)}
            />
            <input
              required
              inputMode="numeric"
              placeholder="CNPJ (somente números)"
              value={form.cnpj}
              onChange={(event) =>
                update('cnpj', event.target.value.replace(/[^\d]/g, '').slice(0, 14))
              }
            />
            <input
              required
              placeholder="Inscrição Estadual"
              value={form.stateRegistration}
              onChange={(event) =>
                update('stateRegistration', event.target.value.toUpperCase().slice(0, 20))
              }
            />
            <select
              value={form.vertical}
              onChange={(event) => update('vertical', event.target.value)}
              aria-label="Segmento"
            >
              {VERTICALS.map((vertical) => (
                <option key={vertical} value={vertical}>
                  {vertical}
                </option>
              ))}
            </select>
            <input
              placeholder={`Identificador (slug): ${slugPreview}`}
              value={form.slug}
              onChange={(event) => {
                setSlugEdited(true);
                update('slug', event.target.value.toLowerCase());
              }}
            />
            <input
              placeholder="Domínio do portal da empresa"
              value={form.domain}
              onChange={(event) => {
                setDomainEdited(true);
                update('domain', event.target.value.toLowerCase());
              }}
            />
            {error && <p style={{ color: 'var(--cc-danger)', margin: 0 }}>{error}</p>}
            <button
              type="submit"
              className="btn btn-primary"
              disabled={!paymentsEnabled || submitting || !selectedPlan}
            >
              {paymentsEnabled
                ? submitting
                  ? 'Redirecionando…'
                  : 'Assinar agora'
                : 'Assinatura disponível apenas em produção'}
            </button>
            <p style={{ margin: 0, fontSize: '0.9rem', opacity: 0.8 }}>
              Cobrança mensal recorrente. Após o pagamento, seu acesso é criado automaticamente
              e as credenciais são enviadas por e-mail.
            </p>
          </form>
        </div>
      </section>
    </Layout>
  );
}

export const getServerSideProps: GetServerSideProps<PlanosPageProps> = async () => ({
  props: { paymentsEnabled: isMercadoPagoEnabled },
});
