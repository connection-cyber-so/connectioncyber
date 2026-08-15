'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { updateVideoScriptAction, deleteVideoScriptAction } from '../actions';
import type { VideoScript } from '../types';

export function VideoScriptCard({ videoScript }: { videoScript: VideoScript }) {
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
      await updateVideoScriptAction(videoScript.id, {
        title: String(formData.get('title') ?? videoScript.title),
        script: String(formData.get('script') ?? videoScript.script ?? ''),
      });
      setIsEditing(false);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao atualizar roteiro.');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleDelete() {
    if (!window.confirm(`Excluir o roteiro "${videoScript.title}"? Essa ação não pode ser desfeita.`)) return;
    setIsDeleting(true);
    try {
      await deleteVideoScriptAction(videoScript.id);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao excluir roteiro.');
      setIsDeleting(false);
    }
  }

  if (isEditing) {
    return (
      <div className="pf-content-card" style={{ marginBottom: 0 }}>
        <form onSubmit={handleSave}>
          <div className="pf-field">
            <label htmlFor={`title-${videoScript.id}`}>Título</label>
            <input id={`title-${videoScript.id}`} name="title" defaultValue={videoScript.title} required />
          </div>
          <div className="pf-field">
            <label htmlFor={`script-${videoScript.id}`}>Roteiro</label>
            <textarea id={`script-${videoScript.id}`} name="script" defaultValue={videoScript.script ?? ''} rows={8} />
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
          <h3 style={{ margin: '0 0 4px', fontSize: '0.98rem' }}>{videoScript.title}</h3>
          <span className={`pf-pill ${videoScript.status === 'generated' ? 'pf-pill-generated' : ''}`}>{videoScript.status}</span>
        </div>
        <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
          <button className="pf-icon-btn" type="button" onClick={() => setIsEditing(true)} title="Editar" aria-label="Editar">✎</button>
          <button className="pf-icon-btn" type="button" onClick={handleDelete} disabled={isDeleting} title="Excluir" aria-label="Excluir">🗑</button>
        </div>
      </div>
      {videoScript.script && <p className="pf-muted" style={{ marginTop: 12, whiteSpace: 'pre-line', lineHeight: 1.6 }}>{videoScript.script}</p>}
      {error && <p className="pf-error">{error}</p>}
    </div>
  );
}
