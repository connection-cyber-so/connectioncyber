'use client';

// Adaptado de cc-commerce-studio/features/diagnostic-engine/components/DiagnosticCard.tsx
import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { updateDiagnosticAction, deleteDiagnosticAction } from '../actions';
import type { Diagnostic } from '../types';

export function DiagnosticCard({ diagnostic }: { diagnostic: Diagnostic }) {
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
      await updateDiagnosticAction(diagnostic.id, {
        title: String(formData.get('title') ?? diagnostic.title),
        summary: String(formData.get('summary') ?? diagnostic.summary ?? ''),
      });
      setIsEditing(false);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao atualizar diagnóstico.');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleDelete() {
    if (!window.confirm(`Excluir o diagnóstico "${diagnostic.title}"? Essa ação não pode ser desfeita.`)) return;

    setIsDeleting(true);
    try {
      await deleteDiagnosticAction(diagnostic.id);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao excluir diagnóstico.');
      setIsDeleting(false);
    }
  }

  if (isEditing) {
    return (
      <div className="pf-content-card" style={{ marginBottom: 0 }}>
        <form onSubmit={handleSave}>
          <div className="pf-field">
            <label htmlFor={`title-${diagnostic.id}`}>Título</label>
            <input id={`title-${diagnostic.id}`} name="title" defaultValue={diagnostic.title} required />
          </div>
          <div className="pf-field">
            <label htmlFor={`summary-${diagnostic.id}`}>Síntese</label>
            <textarea id={`summary-${diagnostic.id}`} name="summary" defaultValue={diagnostic.summary ?? ''} rows={5} />
          </div>
          {error && <p className="pf-error">{error}</p>}
          <div className="pf-inline-actions">
            <button className="pf-button" type="submit" disabled={isSaving}>
              {isSaving ? 'Salvando…' : 'Salvar'}
            </button>
            <button
              className="pf-button pf-button-secondary"
              type="button"
              onClick={() => {
                setError(null);
                setIsEditing(false);
              }}
            >
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
          <h3 style={{ margin: '0 0 4px', fontSize: '0.98rem' }}>{diagnostic.title}</h3>
          <span className={`pf-pill ${diagnostic.status === 'generated' ? 'pf-pill-generated' : ''}`}>
            {diagnostic.status === 'generated' ? 'gerado' : 'rascunho'}
          </span>
        </div>
        <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
          <button className="pf-icon-btn" type="button" onClick={() => setIsEditing(true)} title="Editar" aria-label="Editar">
            ✎
          </button>
          <button className="pf-icon-btn" type="button" onClick={handleDelete} disabled={isDeleting} title="Excluir" aria-label="Excluir">
            🗑
          </button>
        </div>
      </div>

      <dl className="pf-muted" style={{ marginTop: 12, fontSize: '0.85rem' }}>
        <div>
          <strong>Canais: </strong>
          {diagnostic.answers.canais_digitais}
        </div>
        <div>
          <strong>Público-alvo: </strong>
          {diagnostic.answers.publico_alvo}
        </div>
      </dl>

      {diagnostic.summary && (
        <p className="pf-muted" style={{ marginTop: 12, whiteSpace: 'pre-line', lineHeight: 1.6 }}>
          {diagnostic.summary}
        </p>
      )}

      {error && <p className="pf-error">{error}</p>}
    </div>
  );
}
