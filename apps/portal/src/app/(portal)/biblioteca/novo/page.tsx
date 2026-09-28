import Link from 'next/link';
import { context } from '@/features/knowledge-base/service';
import { ContentFields, Mutation } from '@/features/knowledge-base/components';
import { message } from '@/features/knowledge-base/messages';
import '../knowledge-base.css';
export const dynamic = 'force-dynamic';
export default async function NewItem() {
  try {
    await context();
  } catch (error) {
    return (
      <p role="status">{message(error instanceof Error ? error.message : 'KB_UNAVAILABLE')}</p>
    );
  }
  return (
    <section className="kb">
      <Link href="/biblioteca">← Biblioteca</Link>
      <header>
        <p className="eyebrow">M0 · Entrada</p>
        <h1>Adicionar conhecimento</h1>
        <p>Registre o material e sua origem. Anexe arquivos na página do item após salvar.</p>
      </header>
      <div className="kb-panel">
        <Mutation action="create">
          <ContentFields />
          <p className="kb-meta">
            Envie somente conteúdo que pode compartilhar. Não inclua senhas, tokens ou dados
            pessoais. Scripts são armazenados como documentação e nunca executados.
          </p>
          <button className="button primary">Criar entrada</button>
        </Mutation>
      </div>
    </section>
  );
}
