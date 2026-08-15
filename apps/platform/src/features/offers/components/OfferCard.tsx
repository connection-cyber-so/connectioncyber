'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { updateOfferAction, deleteOfferAction } from '../actions';
import type { Offer } from '../types';

export function OfferCard({ offer }: { offer: Offer }) {
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
      await updateOfferAction(offer.id, {
        title: String(formData.get('title') ?? offer.title),
        copy: String(formData.get('copy') ?? offer.copy ?? ''),
      });
      setIsEditing(false);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao atualizar oferta.');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleDelete() {
    if (!window.confirm(`Excluir a oferta "${offer.title}"? Essa ação não pode ser desfeita.`)) return;
    setIsDeleting(true);
    try {
      await deleteOfferAction(offer.id);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao excluir oferta.');
      setIsDeleting(false);
    }
  }

  if (isEditing) {
    return (
      <div className="pf-content-card" style={{ marginBottom: 0 }}>
        <form onSubmit={handleSave}>
          <div className="pf-field">
            <label htmlFor={`title-${offer.id}`}>Título</label>
            <input id={`title-${offer.id}`} name="title" defaultValue={offer.title} required />
          </div>
          <div className="pf-field">
            <label htmlFor={`copy-${offer.id}`}>Copy</label>
            <textarea id={`copy-${offer.id}`} name="copy" defaultValue={offer.copy ?? ''} rows={5} />
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
          <h3 style={{ margin: '0 0 4px', fontSize: '0.98rem' }}>{offer.title}</h3>
          <span className={`pf-pill ${offer.status === 'generated' ? 'pf-pill-generated' : ''}`}>{offer.status}</span>
        </div>
        <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
          <button className="pf-icon-btn" type="button" onClick={() => setIsEditing(true)} title="Editar" aria-label="Editar">✎</button>
          <button className="pf-icon-btn" type="button" onClick={handleDelete} disabled={isDeleting} title="Excluir" aria-label="Excluir">🗑</button>
        </div>
      </div>
      {offer.copy && <p className="pf-muted" style={{ marginTop: 12, whiteSpace: 'pre-line', lineHeight: 1.6 }}>{offer.copy}</p>}
      {error && <p className="pf-error">{error}</p>}
    </div>
  );
}
