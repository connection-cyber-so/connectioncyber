import Link from 'next/link';
import { detail } from '@/features/knowledge-base/service';
import { ContentFields, Mutation, TaxonomyFields } from '@/features/knowledge-base/components';
import { gates, dimensions } from '@/features/knowledge-base/types';
import { repositorySuggestion, safeUrl } from '@/features/knowledge-base/validations';
import { message } from '@/features/knowledge-base/messages';
import '../knowledge-base.css';
export const dynamic = 'force-dynamic';
export default async function ItemPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ error?: string; ok?: string }>;
}) {
  const { id } = await params;
  const query = await searchParams;
  let result;
  try {
    result = await detail(id);
  } catch (error) {
    return (
      <p role="status">{message(error instanceof Error ? error.message : 'KB_UNAVAILABLE')}</p>
    );
  }
  const { item, manage, userId } = result;
  const editable = manage || item.author_id === userId;
  const suggestion = repositorySuggestion(item.kind, item.taxonomy.project ?? '');
  let source = '';
  try {
    source = safeUrl(item.source_url);
  } catch {
    /* Legacy unsafe URLs are rendered as text only. */
  }
  return (
    <section className="kb">
      <Link href="/biblioteca">← Biblioteca</Link>
      <header className="kb-header">
        <div>
          <p className="eyebrow">
            {item.kind} · {gates[item.stage]}
          </p>
          <h1>{item.title}</h1>
          <p className="kb-meta">
            Versão {item.revision} · Score técnico {item.score}/100 ·{' '}
            {result.ratings.length
              ? 'Avaliação ' +
                (
                  result.ratings.reduce((sum, r) => sum + r.rating, 0) / result.ratings.length
                ).toFixed(1) +
                '/5'
              : 'Sem avaliações'}
          </p>
        </div>
        {item.stage === 4 && (
          <Link
            prefetch={false}
            className="button primary"
            href={'/api/knowledge-base/' + id + '/download'}
          >
            Baixar conteúdo
          </Link>
        )}
      </header>
      {query.error && (
        <p className="kb-alert" role="alert">
          {message(query.error)}
        </p>
      )}
      {query.ok && <p role="status">Alteração registrada.</p>}
      <div className="kb-panel">
        <h2>Documentação</h2>
        {source && (
          <p>
            <a href={source} rel="noopener noreferrer" target="_blank">
              Abrir referência externa
            </a>
          </p>
        )}
        <pre>{item.body || 'Conteúdo disponibilizado nos anexos ou na referência externa.'}</pre>
        <div>
          {item.tags.map((t) => (
            <span className="kb-tag" key={t}>
              {t}
            </span>
          ))}
        </div>
      </div>
      <div className="kb-grid">
        <section className="kb-panel">
          <h2>Classificação</h2>
          <dl>
            {Object.entries(dimensions).map(([key, label]) => (
              <div key={key}>
                <dt>{label}</dt>
                <dd>{item.taxonomy[key as keyof typeof dimensions] ?? 'Pendente'}</dd>
              </div>
            ))}
          </dl>
        </section>
        <section className="kb-panel">
          <h2>Aplicação e GitHub</h2>
          <p>{item.application || 'Aplicação técnica pendente.'}</p>
          <p>Destino revisado: {item.repository || 'Pendente'}</p>
          <details>
            <summary>Sugestão de organização</summary>
            <p>{suggestion.repository}</p>
            <code>{suggestion.path}</code>
            <p className="kb-meta">{suggestion.reason}</p>
          </details>
        </section>
      </div>
      <section className="kb-panel">
        <h2>Arquivos</h2>
        <p className="kb-meta">
          Até 3 MB por arquivo. Documentos e código são baixados como anexos. Aprovação requer
          inspeção independente.
        </p>
        {result.assets.length === 0 && <p>Nenhum arquivo anexado.</p>}
        <ul className="kb-timeline">
          {result.assets.map((asset) => (
            <li key={asset.id}>
              <strong>{asset.filename}</strong> · {Math.ceil(asset.size_bytes / 1024)} KB ·{' '}
              {asset.status}
              <p className="kb-meta">SHA256: {asset.sha256}</p>
              {item.stage === 4 && asset.status === 'approved' && (
                <Link
                  prefetch={false}
                  href={'/api/knowledge-base/' + id + '/download?asset=' + asset.id}
                >
                  Baixar arquivo
                </Link>
              )}
              {manage && asset.status === 'quarantined' && (
                <p>
                  <Link
                    prefetch={false}
                    href={
                      '/api/knowledge-base/' + id + '/download?asset=' + asset.id + '&inspect=1'
                    }
                  >
                    Baixar para inspeção em ambiente isolado
                  </Link>
                </p>
              )}
              {manage && item.stage < 4 && ['pending', 'quarantined'].includes(asset.status) && (
                <Mutation action="review_asset" item={item}>
                  <input type="hidden" name="asset_id" value={asset.id} />
                  <label>
                    Evidência de inspeção (integridade, malware e segredos)
                    <textarea name="evidence" minLength={20} maxLength={4000} required />
                  </label>
                  <label>
                    Decisão
                    <select name="approved">
                      <option value="false">Rejeitar</option>
                      <option value="true">Aprovar após inspeção</option>
                    </select>
                  </label>
                  <button className="button ghost">Registrar revisão do arquivo</button>
                </Mutation>
              )}
            </li>
          ))}
        </ul>
        {editable && item.stage === 0 && (
          <Mutation action="upload" item={item}>
            <label>
              Anexar arquivo
              <input
                name="file"
                type="file"
                required
                accept=".pdf,.txt,.md,.json,.csv,.zip,.sql,.js,.ts,.py,.sh,.ps1,.mp4,.webm"
              />
            </label>
            <button className="button primary">Enviar à quarentena</button>
          </Mutation>
        )}
      </section>
      {editable && item.stage === 0 && (
        <section className="kb-panel">
          <h2>Classificar material</h2>
          <Mutation action="classify" item={item}>
            <TaxonomyFields item={item} />
            <button className="button primary">Salvar classificação</button>
          </Mutation>
          <details>
            <summary>Sugerir classificação por IA</summary>
            <Mutation action="ai" item={item}>
              <label className="kb-check">
                <input type="checkbox" name="consent" required />
                Autorizo enviar título e até 12.000 caracteres deste conteúdo ao provedor de IA
                configurado.
              </label>
              <p className="kb-meta">
                A sugestão preenche a classificação em M0. Revise os campos antes de solicitar
                aprovação; a IA não libera conteúdo.
              </p>
              <button className="button ghost">Gerar sugestão</button>
            </Mutation>
          </details>
        </section>
      )}
      {manage && item.stage < 4 && (
        <section className="kb-panel">
          <h2>Próximo gate: {gates[item.stage + 1]}</h2>
          <Mutation action="advance" item={item}>
            {item.stage === 0 && (
              <p>
                Confirme que todas as dimensões estão corretas e que a classificação representa o
                material.
              </p>
            )}
            {item.stage === 1 && (
              <>
                <label>
                  Aplicação técnica e evidência de utilidade
                  <textarea
                    name="application"
                    minLength={20}
                    maxLength={4000}
                    required
                    defaultValue={item.application}
                  />
                </label>
                <label>
                  Score técnico (mínimo 60 para avançar)
                  <input
                    name="score"
                    type="number"
                    min="60"
                    max="100"
                    required
                    defaultValue={item.score || 60}
                  />
                </label>
              </>
            )}
            {item.stage === 2 && (
              <label>
                Repositório GitHub de destino
                <input
                  name="repository"
                  type="url"
                  required
                  defaultValue={item.repository || suggestion.repository}
                />
              </label>
            )}
            {item.stage === 3 && (
              <>
                <label className="kb-check">
                  <input name="rights" value="true" type="checkbox" required />
                  Direitos de uso e distribuição verificados
                </label>
                <label className="kb-check">
                  <input name="secrets_checked" value="true" type="checkbox" required />
                  Segredos e dados pessoais revisados
                </label>
                <label className="kb-check">
                  <input name="technical_checked" value="true" type="checkbox" required />
                  Conteúdo validado tecnicamente
                </label>
                <label>
                  Evidências da revisão independente
                  <textarea name="evidence" minLength={20} maxLength={4000} required />
                </label>
              </>
            )}
            <button className="button primary">Aprovar próximo gate</button>
          </Mutation>
        </section>
      )}
      {editable && (
        <details className="kb-panel">
          <summary>Editar e iniciar nova revisão em M0</summary>
          <p>A revisão retira o item do catálogo liberado até nova aprovação.</p>
          <Mutation action="revise" item={item}>
            <ContentFields item={item} />
            <button className="button ghost">Salvar nova revisão</button>
          </Mutation>
        </details>
      )}
      {item.stage === 4 && (
        <section className="kb-panel">
          <h2>Seu uso do material</h2>
          <Mutation action="favorite" item={item}>
            <input type="hidden" name="enabled" value={result.favorite ? 'false' : 'true'} />
            <button className="button ghost">
              {result.favorite ? 'Remover dos favoritos' : 'Salvar nos favoritos'}
            </button>
          </Mutation>
          {item.author_id !== userId && (
            <Mutation action="rate" item={item}>
              <label>
                Avaliação
                <select name="rating" defaultValue="5">
                  {[5, 4, 3, 2, 1].map((n) => (
                    <option key={n} value={n}>
                      {n} de 5
                    </option>
                  ))}
                </select>
              </label>
              <label>
                Comentário
                <textarea name="comment" maxLength={1000} />
              </label>
              <button className="button primary">Salvar avaliação</button>
            </Mutation>
          )}
          <ul>
            {result.ratings
              .filter((r) => r.comment)
              .map((r, index) => (
                <li key={index}>
                  {r.rating}/5 — {r.comment}
                </li>
              ))}
          </ul>
        </section>
      )}
      {editable && (
        <details className="kb-panel">
          <summary>Histórico de versões ({result.versions.length} mais recentes)</summary>
          {result.versions.map((version) => (
            <details key={version.revision}>
              <summary>
                v{version.revision} · {new Date(version.created_at).toLocaleString('pt-BR')}
              </summary>
              <Link href={'/biblioteca/' + id + '/versoes/' + version.revision}>
                Consultar snapshot desta versão
              </Link>
            </details>
          ))}
        </details>
      )}
      <details className="kb-panel">
        <summary>Auditoria ({result.events.length} eventos visíveis mais recentes)</summary>
        <ol className="kb-timeline">
          {result.events.map((event) => (
            <li key={event.id}>
              {event.action} · v{event.revision} ·{' '}
              {new Date(event.created_at).toLocaleString('pt-BR')}
              <pre>{JSON.stringify(event.detail, null, 2)}</pre>
            </li>
          ))}
        </ol>
        <small>
          Download registra solicitação autorizada; não comprova transferência concluída.
        </small>
      </details>
    </section>
  );
}
