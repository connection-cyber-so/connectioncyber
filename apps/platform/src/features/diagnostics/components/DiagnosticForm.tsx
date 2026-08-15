'use client';

// Adaptado de cc-commerce-studio/features/diagnostic-engine/components/DiagnosticForm.tsx
// — reescrito com os tokens .pf-* do apps/platform em vez de Tailwind (apps/platform
// não usa Tailwind; ver apps/platform/README.md). Sem input hidden de tenant_id/workspace_id
// — a action deriva o tenant da sessão (ver features/diagnostics/actions.ts).
import { useState } from 'react';
import { useFormState, useFormStatus } from 'react-dom';
import { createDiagnosticAction, generateDiagnosticSummaryAction, type CreateDiagnosticActionState } from '../actions';

const initialState: CreateDiagnosticActionState = { error: null, success: false };

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button className="pf-button" type="submit" disabled={pending} style={{ width: 'auto' }}>
      {pending ? 'Salvando…' : 'Salvar diagnóstico'}
    </button>
  );
}

export function DiagnosticForm({ projectId }: { projectId: string }) {
  const [state, formAction] = useFormState(createDiagnosticAction, initialState);
  const [canaisDigitais, setCanaisDigitais] = useState('');
  const [publicoAlvo, setPublicoAlvo] = useState('');
  const [concorrentes, setConcorrentes] = useState('');
  const [objetivoPrincipal, setObjetivoPrincipal] = useState('aumentar_vendas');
  const [maturidadeDigital, setMaturidadeDigital] = useState('iniciante');
  const [summary, setSummary] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);

  async function handleGenerate() {
    setIsGenerating(true);
    setGenerateError(null);

    const result = await generateDiagnosticSummaryAction({
      canais_digitais: canaisDigitais,
      publico_alvo: publicoAlvo,
      concorrentes: concorrentes || undefined,
      objetivo_principal: objetivoPrincipal,
      maturidade_digital: maturidadeDigital,
    });

    if (result.error) setGenerateError(result.error);
    else if (result.summary) setSummary(result.summary);

    setIsGenerating(false);
  }

  return (
    <div className="pf-content-card">
      <form action={formAction}>
        <input type="hidden" name="project_id" value={projectId} />
        <input type="hidden" name="summary" value={summary} />

        <div className="pf-field">
          <label htmlFor="title">Título do diagnóstico</label>
          <input id="title" name="title" placeholder="Ex: Diagnóstico inicial" required />
        </div>

        <div className="pf-field">
          <label htmlFor="canais_digitais">Canais digitais atuais</label>
          <textarea
            id="canais_digitais"
            name="canais_digitais"
            value={canaisDigitais}
            onChange={(e) => setCanaisDigitais(e.target.value)}
            placeholder="Ex: Instagram, site institucional, WhatsApp Business"
            rows={2}
            required
          />
        </div>

        <div className="pf-field">
          <label htmlFor="publico_alvo">Público-alvo</label>
          <textarea
            id="publico_alvo"
            name="publico_alvo"
            value={publicoAlvo}
            onChange={(e) => setPublicoAlvo(e.target.value)}
            placeholder="Descreva quem é o cliente ideal"
            rows={2}
            required
          />
        </div>

        <div className="pf-field">
          <label htmlFor="concorrentes">Concorrentes diretos (opcional)</label>
          <textarea
            id="concorrentes"
            name="concorrentes"
            value={concorrentes}
            onChange={(e) => setConcorrentes(e.target.value)}
            placeholder="Liste concorrentes conhecidos"
            rows={2}
          />
        </div>

        <div className="pf-field">
          <label htmlFor="objetivo_principal">Objetivo principal</label>
          <select
            id="objetivo_principal"
            name="objetivo_principal"
            value={objetivoPrincipal}
            onChange={(e) => setObjetivoPrincipal(e.target.value)}
            required
          >
            <option value="aumentar_vendas">Aumentar vendas</option>
            <option value="gerar_leads">Gerar leads</option>
            <option value="construir_marca">Construir marca</option>
            <option value="outro">Outro</option>
          </select>
        </div>

        <div className="pf-field">
          <label htmlFor="maturidade_digital">Maturidade digital</label>
          <select
            id="maturidade_digital"
            name="maturidade_digital"
            value={maturidadeDigital}
            onChange={(e) => setMaturidadeDigital(e.target.value)}
            required
          >
            <option value="iniciante">Iniciante</option>
            <option value="intermediario">Intermediário</option>
            <option value="avancado">Avançado</option>
          </select>
        </div>

        <div className="pf-field">
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <label htmlFor="summary_display">Síntese do diagnóstico</label>
            <button
              type="button"
              className="pf-link-btn"
              onClick={handleGenerate}
              disabled={isGenerating || !canaisDigitais || !publicoAlvo}
            >
              {isGenerating ? 'Gerando…' : 'Gerar diagnóstico com IA'}
            </button>
          </div>
          <textarea
            id="summary_display"
            value={summary}
            onChange={(e) => setSummary(e.target.value)}
            placeholder="Preencha os campos acima e clique em &quot;Gerar diagnóstico com IA&quot;"
            rows={6}
          />
          {generateError && <p className="pf-error">{generateError}</p>}
        </div>

        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Diagnóstico criado com sucesso.</p>}

        <SubmitButton />
      </form>
    </div>
  );
}
