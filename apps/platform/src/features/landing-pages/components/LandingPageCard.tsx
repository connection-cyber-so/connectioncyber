'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { updateLandingPageAction, deleteLandingPageAction, togglePublishAction } from '../actions';
import type { LandingPage } from '../types';
import { env } from '@/config/env';

export function LandingPageCard({ landingPage }: { landingPage: LandingPage }) {
  const router = useRouter();
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);
  const [isToggling, setIsToggling] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const publicUrl = `${env.site.url}/lp/${landingPage.slug}`;
  const isPublished = landingPage.status === 'published';

  async function handleSave(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setIsSaving(true);
    setError(null);
    const formData = new FormData(event.currentTarget);

    try {
      await updateLandingPageAction(landingPage.id, {
        title: String(formData.get('title') ?? landingPage.title),
        content: String(formData.get('content') ?? landingPage.content ?? ''),
      });
      setIsEditing(false);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao atualizar landing page.');
    } finally {
      setIsSaving(false);
    }
  }

  async function handleTogglePublish() {
    setIsToggling(true);
    setError(null);
    try {
      await togglePublishAction(landingPage.id, !isPublished);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao publicar/despublicar.');
    } finally {
      setIsToggling(false);
    }
  }

  async function handleDelete() {
    if (!window.confirm(`Excluir a landing page "${landingPage.title}"? Essa ação não pode ser desfeita.`)) return;
    setIsDeleting(true);
    try {
      await deleteLandingPageAction(landingPage.id);
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erro ao excluir landing page.');
      setIsDeleting(false);
    }
  }

  if (isEditing) {
    return (
      <div className="pf-content-card" style={{ marginBottom: 0 }}>
        <form onSubmit={handleSave}>
          <div className="pf-field">
            <label htmlFor={`title-${landingPage.id}`}>Título</label>
            <input id={`title-${landingPage.id}`} name="title" defaultValue={landingPage.title} required />
          </div>
          <div className="pf-field">
            <label htmlFor={`content-${landingPage.id}`}>Conteúdo</label>
            <textarea id={`content-${landingPage.id}`} name="content" defaultValue={landingPage.content ?? ''} rows={8} />
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
          <h3 style={{ margin: '0 0 4px', fontSize: '0.98rem' }}>{landingPage.title}</h3>
          <span className={`pf-pill ${isPublished ? 'pf-pill-generated' : ''}`}>{isPublished ? 'publicada' : 'rascunho'}</span>
        </div>
        <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
          <button className="pf-icon-btn" type="button" onClick={() => setIsEditing(true)} title="Editar" aria-label="Editar">✎</button>
          <button className="pf-icon-btn" type="button" onClick={handleDelete} disabled={isDeleting} title="Excluir" aria-label="Excluir">🗑</button>
        </div>
      </div>

      {isPublished ? (
        <p className="pf-muted" style={{ marginTop: 10, fontSize: '0.85rem' }}>
          <a href={publicUrl} target="_blank" rel="noreferrer">{publicUrl}</a>
        </p>
      ) : (
        <p className="pf-muted" style={{ marginTop: 10, fontSize: '0.85rem' }}>
          Ainda não publicada — <code>/lp/{landingPage.slug}</code> não está no ar.
        </p>
      )}

      <div className="pf-inline-actions">
        <button className="pf-button pf-button-secondary" type="button" onClick={handleTogglePublish} disabled={isToggling}>
          {isToggling ? 'Aguarde…' : isPublished ? 'Despublicar' : 'Publicar'}
        </button>
      </div>

      {error && <p className="pf-error">{error}</p>}
    </div>
  );
}
