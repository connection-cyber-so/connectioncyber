'use client';

// Adaptado de cc-commerce-studio/features/offer-engine/components/OfferForm.tsx —
// sem seletor de marca (brands não migrado), sem tenant_id hidden.
import { useState } from 'react';
import { useFormState, useFormStatus } from 'react-dom';
import { createOfferAction, generateOfferCopyAction, type CreateOfferActionState } from '../actions';
import type { MpiProduct } from '@/features/products/types';

const initialState: CreateOfferActionState = { error: null, success: false };

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button className="pf-button" type="submit" disabled={pending} style={{ width: 'auto' }}>
      {pending ? 'Salvando…' : 'Salvar oferta'}
    </button>
  );
}

export function OfferForm({ products }: { products: MpiProduct[] }) {
  const [state, formAction] = useFormState(createOfferAction, initialState);
  const [productId, setProductId] = useState(products[0]?.id ?? '');
  const [copy, setCopy] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const [generateError, setGenerateError] = useState<string | null>(null);

  async function handleGenerate() {
    if (!productId) return;
    setIsGenerating(true);
    setGenerateError(null);

    const result = await generateOfferCopyAction(productId);
    if (result.error) setGenerateError(result.error);
    else if (result.copy) setCopy(result.copy);

    setIsGenerating(false);
  }

  if (products.length === 0) {
    return (
      <div className="pf-content-card">
        <p className="pf-muted">Cadastre um produto antes de criar uma oferta.</p>
      </div>
    );
  }

  return (
    <div className="pf-content-card">
      <form action={formAction}>
        <input type="hidden" name="copy" value={copy} />

        <div className="pf-field">
          <label htmlFor="title">Título da oferta</label>
          <input id="title" name="title" placeholder="Ex: Oferta de lançamento" required />
        </div>

        <div className="pf-field">
          <label htmlFor="product_id">Produto</label>
          <select id="product_id" name="product_id" value={productId} onChange={(e) => setProductId(e.target.value)} required>
            {products.map((product) => (
              <option key={product.id} value={product.id}>
                {product.name}
              </option>
            ))}
          </select>
        </div>

        <div className="pf-field">
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <label htmlFor="copy_display">Copy da oferta</label>
            <button type="button" className="pf-link-btn" onClick={handleGenerate} disabled={isGenerating || !productId}>
              {isGenerating ? 'Gerando…' : 'Gerar copy com IA'}
            </button>
          </div>
          <textarea id="copy_display" value={copy} onChange={(e) => setCopy(e.target.value)} placeholder="Escreva a copy ou clique em &quot;Gerar copy com IA&quot;" rows={6} />
          {generateError && <p className="pf-error">{generateError}</p>}
        </div>

        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Oferta criada com sucesso.</p>}

        <SubmitButton />
      </form>
    </div>
  );
}
