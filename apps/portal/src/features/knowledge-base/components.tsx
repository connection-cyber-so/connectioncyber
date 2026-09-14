import type { ReactNode } from 'react';
import { dimensions, kinds, type Item } from './types';
export function Mutation({
  action,
  item,
  children,
}: {
  action: string;
  item?: Item;
  children: ReactNode;
}) {
  return (
    <form
      action="/api/knowledge-base"
      method="post"
      encType={action === 'upload' ? 'multipart/form-data' : undefined}
      className="kb-form"
    >
      <input type="hidden" name="action" value={action} />
      {item && (
        <>
          <input type="hidden" name="id" value={item.id} />
          <input type="hidden" name="revision" value={item.revision} />
        </>
      )}
      {children}
    </form>
  );
}
export function ContentFields({ item }: { item?: Item }) {
  return (
    <>
      <label>
        Título
        <input name="title" required minLength={3} maxLength={180} defaultValue={item?.title} />
      </label>
      {!item && (
        <label>
          Tipo
          <select name="kind">
            {kinds.map((k) => (
              <option key={k}>{k}</option>
            ))}
          </select>
        </label>
      )}
      <label>
        Link de origem (HTTPS)
        <input name="source_url" type="url" maxLength={2048} defaultValue={item?.source_url} />
      </label>
      <label>
        Conteúdo
        <textarea name="body" rows={10} maxLength={100000} defaultValue={item?.body} />
      </label>
    </>
  );
}
export function TaxonomyFields({ item }: { item: Item }) {
  return (
    <>
      <div className="kb-grid">
        {Object.entries(dimensions).map(([key, label]) => (
          <label key={key}>
            {label}
            <input
              name={key}
              required
              maxLength={180}
              defaultValue={item.taxonomy[key as keyof typeof dimensions] ?? ''}
            />
          </label>
        ))}
      </div>
      <label>
        Tags, separadas por vírgula
        <input name="tags" defaultValue={item.tags.join(', ')} maxLength={1800} />
      </label>
    </>
  );
}
