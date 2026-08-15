'use client';

// Adaptado de cc-commerce-studio/features/landing-pages/components/LandingPageForm.tsx
import { useFormState, useFormStatus } from 'react-dom';
import { createLandingPageAction, type CreateLandingPageActionState } from '../actions';
import type { Offer } from '@/features/offers/types';

const initialState: CreateLandingPageActionState = { error: null, success: false };

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button className="pf-button" type="submit" disabled={pending} style={{ width: 'auto' }}>
      {pending ? 'Salvando…' : 'Salvar landing page'}
    </button>
  );
}

export function LandingPageForm({ offers }: { offers: Offer[] }) {
  const [state, formAction] = useFormState(createLandingPageAction, initialState);

  if (offers.length === 0) {
    return (
      <div className="pf-content-card">
        <p className="pf-muted">Cadastre uma oferta antes de criar uma landing page.</p>
      </div>
    );
  }

  return (
    <div className="pf-content-card">
      <form action={formAction}>
        <div className="pf-field">
          <label htmlFor="title">Título</label>
          <input id="title" name="title" placeholder="Ex: Auditoria gratuita de backup" required />
        </div>

        <div className="pf-field">
          <label htmlFor="slug">Slug (URL)</label>
          <input id="slug" name="slug" placeholder="ex-auditoria-gratuita" pattern="[a-z0-9]+(-[a-z0-9]+)*" required />
          <p className="pf-muted" style={{ marginTop: 4 }}>
            Só minúsculas, números e hífens. Único em todo o site — vira{' '}
            <code>connectioncyber.com.br/lp/seu-slug</code>.
          </p>
        </div>

        <div className="pf-field">
          <label htmlFor="offer_id">Oferta de origem</label>
          <select id="offer_id" name="offer_id" defaultValue={offers[0]?.id ?? ''} required>
            {offers.map((offer) => (
              <option key={offer.id} value={offer.id}>
                {offer.title}
              </option>
            ))}
          </select>
        </div>

        <div className="pf-field">
          <label htmlFor="content">Conteúdo da página</label>
          <textarea id="content" name="content" placeholder="Copie e adapte a copy da oferta selecionada" rows={8} />
        </div>

        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Landing page criada como rascunho — publique quando estiver pronta.</p>}

        <SubmitButton />
      </form>
    </div>
  );
}
