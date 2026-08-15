'use client';

// Adaptado de cc-commerce-studio/features/products/components/ProductForm.tsx — sem
// seletor de marca (brands ainda não migrado) e sem tenant_id/workspace_id hidden.
import { useFormState, useFormStatus } from 'react-dom';
import { createProductAction, type CreateProductActionState } from '../actions';

const initialState: CreateProductActionState = { error: null, success: false };

function SubmitButton() {
  const { pending } = useFormStatus();
  return (
    <button className="pf-button" type="submit" disabled={pending} style={{ width: 'auto' }}>
      {pending ? 'Salvando…' : 'Salvar produto'}
    </button>
  );
}

export function ProductForm() {
  const [state, formAction] = useFormState(createProductAction, initialState);

  return (
    <div className="pf-content-card">
      <form action={formAction}>
        <div className="pf-field">
          <label htmlFor="name">Nome do produto</label>
          <input id="name" name="name" placeholder="Ex: Curso de Marketing Digital" required />
        </div>

        <div className="pf-field">
          <label htmlFor="description">Descrição</label>
          <textarea id="description" name="description" placeholder="Descreva rapidamente este produto" rows={3} />
        </div>

        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Produto criado com sucesso.</p>}

        <SubmitButton />
      </form>
    </div>
  );
}
