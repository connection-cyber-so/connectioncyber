import Link from 'next/link';
import { catalog, dashboard } from '@/features/knowledge-base/service';
import { gates, kinds, dimensions, type Filters } from '@/features/knowledge-base/types';
import { message } from '@/features/knowledge-base/messages';
import './knowledge-base.css';
export const dynamic = 'force-dynamic';
export default async function Library({
  searchParams,
}: {
  searchParams: Promise<Filters & { error?: string }>;
}) {
  const filters = await searchParams;
  let result, stats;
  try {
    [result, stats] = await Promise.all([catalog(filters), dashboard()]);
  } catch (error) {
    return (
      <section className="kb">
        <h1>Biblioteca Técnica</h1>
        <p role="status" className="kb-alert">
          {message(error instanceof Error ? error.message : 'KB_UNAVAILABLE')}
        </p>
      </section>
    );
  }
  function pageHref(page: number) {
    const params = new URLSearchParams(
      Object.entries(filters).filter(([, value]) => typeof value === 'string') as [
        string,
        string,
      ][],
    );
    params.set('page', String(page));
    return '/biblioteca?' + params.toString();
  }
  return (
    <section className="kb">
      <header className="kb-header">
        <div>
          <p className="eyebrow">Conhecimento reutilizável</p>
          <h1>Biblioteca Técnica</h1>
          <p className="lead">
            Encontre documentação, código e referências para aplicar nos seus projetos.
          </p>
        </div>
        <div className="kb-actions">
          <Link className="button primary" href="/biblioteca/novo">
            Adicionar conteúdo
          </Link>
          {result.manage && (
            <Link className="button ghost" href="/biblioteca/admin">
              Curadoria
            </Link>
          )}
        </div>
      </header>
      {filters.error && (
        <p role="alert" className="kb-alert">
          {message(filters.error)}
        </p>
      )}
      <div className="kb-stats">
        {gates.map((gate, index) => (
          <div className="kb-stat" key={gate}>
            <span>{gate}</span>
            <strong>{stats.counts[index]}</strong>
          </div>
        ))}
      </div>
      <p className="kb-meta">
        {stats.downloads} solicitações de download visíveis · {stats.favorites} favoritos pessoais
      </p>
      <form className="kb-panel kb-form">
        <div className="kb-grid">
          <label>
            Pesquisar conteúdo
            <input
              name="q"
              defaultValue={filters.q}
              placeholder="Ex.: migração PostgreSQL"
              maxLength={200}
            />
          </label>
          <label>
            Tipo
            <select name="kind" defaultValue={filters.kind ?? ''}>
              <option value="">Todos</option>
              {kinds.map((k) => (
                <option key={k}>{k}</option>
              ))}
            </select>
          </label>
          <label>
            Gate
            <select name="stage" defaultValue={filters.stage ?? ''}>
              <option value="">Todos os visíveis</option>
              {gates.map((g, i) => (
                <option key={g} value={i}>
                  {g}
                </option>
              ))}
            </select>
          </label>
          <label>
            Tag
            <input name="tag" defaultValue={filters.tag} />
          </label>
        </div>
        <details>
          <summary>Filtros avançados</summary>
          <div className="kb-grid">
            {Object.entries(dimensions).map(([key, label]) => (
              <label key={key}>
                {label}
                <input name={key} defaultValue={filters[key as keyof Filters]} />
              </label>
            ))}
            <label>
              Score mínimo
              <input name="score" type="number" min="0" max="100" defaultValue={filters.score} />
            </label>
            <label>
              Ordenar
              <select name="sort" defaultValue={filters.sort}>
                <option value="updated">Atualização</option>
                <option value="score">Score técnico</option>
              </select>
            </label>
            <label>
              Favoritos
              <select name="favorite" defaultValue={filters.favorite}>
                <option value="">Todos</option>
                <option value="1">Meus favoritos</option>
              </select>
            </label>
          </div>
        </details>
        <div className="kb-actions">
          <button className="button primary">Pesquisar</button>
          <Link href="/biblioteca" className="button ghost">
            Limpar
          </Link>
        </div>
      </form>
      <p className="kb-meta">
        {result.count} resultados · Página {result.page} · Totais refletem sua permissão.
      </p>
      <div className="kb-grid">
        {result.items.map((item) => (
          <article className="kb-card" key={item.id}>
            <span className="eyebrow">
              {item.kind} · {gates[item.stage]}
            </span>
            <h2>
              <Link href={'/biblioteca/' + item.id}>{item.title}</Link>
            </h2>
            <p className="kb-meta">
              {item.taxonomy.theme ?? 'Classificação pendente'} · Score {item.score}/100 · v
              {item.revision}
            </p>
            <div>
              {item.tags.map((tag) => (
                <span className="kb-tag" key={tag}>
                  {tag}
                </span>
              ))}
            </div>
            <small>Atualizado em {new Date(item.updated_at).toLocaleDateString('pt-BR')}</small>
          </article>
        ))}
      </div>
      {!result.items.length && (
        <div className="kb-panel">
          <h2>Nenhum conteúdo encontrado</h2>
          <p>Ajuste os filtros ou registre o primeiro material para revisão.</p>
        </div>
      )}
      <nav className="kb-actions" aria-label="Paginação">
        {result.page > 1 && (
          <Link className="button ghost" href={pageHref(result.page - 1)}>
            Anterior
          </Link>
        )}
        {result.page * 24 < result.count && (
          <Link className="button ghost" href={pageHref(result.page + 1)}>
            Próxima
          </Link>
        )}
      </nav>
    </section>
  );
}
