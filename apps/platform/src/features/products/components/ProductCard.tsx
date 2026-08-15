'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { updateProductAction, deleteProductAction } from '../actions';
import type { MpiProduct } from '../types';

export function ProductCard({ product }: { product: MpiProduct }) {
  const router = useRouter();
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSave(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSaving(true);
    setError(null);
    const formData = new FormData(event.currentTarget);

    try {
      await updateProductAction(product.id, {
        name: String(formData.get('name') ?? product.name),
        description: String(formData.get('description') ?? product.description ?? ''),
      });
      setIsEditing(false);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao atualizar produto.');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleDelete() {
    if (!window.confirm(`Excluir o produto "${product.name}"? Essa ação não pode ser desfeita.`)) return;
    setIsDeleting(true);
    try {
      await deleteProductAction(product.id);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao excluir produto.');
      setIsDeleting(false);
    }
  }

  if (isEditing) {
    return (
      <div className="pf-content-card" style={{ marginBottom: 0 }}>
        <form onSubmit={handleSave}>
          <div className="pf-field">
            <label htmlFor={`name-${product.id}`}>Nome</label>
            <input id={`name-${product.id}`} name="name" defaultValue={product.name} required />
          </div>
          <div className="pf-field">
            <label htmlFor={`description-${product.id}`}>Descrição</label>
            <textarea id={`description-${product.id}`} name="description" defaultValue={product.description ?? ''} rows={3} />
          </div>
          {error && <p className="pf-error">{error}</p>}
          <div className="pf-inline-actions">
            <button className="pf-button" type="submit" disabled={isSaving}>
              {isSaving ? 'Salvando…' : 'Salvar'}
            </button>
            <button className="pf-button pf-button-secondary" type="button" onClick={() => { setError(null); setIsEditing(false); }}>
              Cancelar
            </button>
          </div>
        </form>
      </div>
    );
  }

  return (
    <div className="pf-content-card" style={{ marginBottom: 0 }}>
      <div className="pf-card-head">
        <div style={{ minWidth: 0 }}>
          <h3 style={{ margin: '0 0 4px', fontSize: '0.98rem' }}>{product.name}</h3>
          <span className="pf-pill">{product.status}</span>
        </div>
        <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
          <button className="pf-icon-btn" type="button" onClick={() => setIsEditing(true)} title="Editar" aria-label="Editar">✎</button>
          <button className="pf-icon-btn" type="button" onClick={handleDelete} disabled={isDeleting} title="Excluir" aria-label="Excluir">🗑</button>
        </div>
      </div>
      {product.description && <p className="pf-muted" style={{ marginTop: 12 }}>{product.description}</p>}
      {error && <p className="pf-error">{error}</p>}
    </div>
  );
}
