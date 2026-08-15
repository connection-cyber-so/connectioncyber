'use client';

// Adaptado de cc-commerce-studio/features/video-script-engine/components/VideoScriptForm.tsx
import { useState } from 'react';
import { useFormState, useFormStatus } from 'react-dom';
import { createVideoScriptAction, generateVideoScriptAction, type CreateVideoScriptActionState } from '../actions';
import type { Offer } from '@/features/offers/types';

const initialState: CreateVideoScriptActionState = { error: null, success: false };

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button className="pf-button" type="submit" disabled={pending} style={{ width: 'auto' }}>
      {pending ? 'Salvando…' : 'Salvar roteiro'}
    </button>
  );
}

export function VideoScriptForm({ offers }: { offers: Offer[] }) {
  const [state, formAction] = useFormState(createVideoScriptAction, initialState);
  const [offerId, setOfferId] = useState(offers[0]?.id ?? '');
  const [script, setScript] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);

  async function handleGenerate() {
    if (!offerId) return;
    setIsGenerating(true);
    setGenerateError(null);

    const result = await generateVideoScriptAction(offerId);
    if (result.error) setGenerateError(result.error);
    else if (result.script) setScript(result.script);

    setIsGenerating(false);
  }

  if (offers.length === 0) {
    return (
      <div className="pf-content-card">
        <p className="pf-muted">Cadastre uma oferta antes de criar um roteiro de vídeo.</p>
      </div>
    );
  }

  return (
    <div className="pf-content-card">
      <form action={formAction}>
        <input type="hidden" name="script" value={script} />

        <div className="pf-field">
          <label htmlFor="title">Título do roteiro</label>
          <input id="title" name="title" placeholder="Ex: VSL de lançamento" required />
        </div>

        <div className="pf-field">
          <label htmlFor="offer_id">Oferta de origem</label>
          <select id="offer_id" name="offer_id" value={offerId} onChange={(e) => setOfferId(e.target.value)} required>
            {offers.map((offer) => (
              <option key={offer.id} value={offer.id}>
                {offer.title}
              </option>
            ))}
          </select>
        </div>

        <div className="pf-field">
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <label htmlFor="script_display">Roteiro</label>
            <button type="button" className="pf-link-btn" onClick={handleGenerate} disabled={isGenerating || !offerId}>
              {isGenerating ? 'Gerando…' : 'Gerar roteiro com IA'}
            </button>
          </div>
          <textarea id="script_display" value={script} onChange={(e) => setScript(e.target.value)} placeholder="Escreva o roteiro ou clique em &quot;Gerar roteiro com IA&quot;" rows={8} />
          {generateError && <p className="pf-error">{generateError}</p>}
          <p className="pf-muted" style={{ marginTop: 6 }}>Gera um roteiro estilo VSL (Gancho, Problema, Solução, Prova, Chamada para ação) a partir da copy da oferta selecionada.</p>
        </div>

        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Roteiro criado com sucesso.</p>}

        <SubmitButton />
      </form>
    </div>
  );
}
