import Link from 'next/link';
import { version } from '@/features/knowledge-base/service';
import { message } from '@/features/knowledge-base/messages';
import '../../../knowledge-base.css';
export const dynamic = 'force-dynamic';
export default async function VersionPage({
  params,
}: {
  params: Promise<{ id: string; revision: string }>;
}) {
  const { id, revision } = await params;
  try {
    const record = await version(id, Number(revision));
    return (
      <section className="kb">
        <Link href={'/biblioteca/' + id}>← Item atual</Link>
        <h1>Snapshot da versão {record.revision}</h1>
        <p>
          Registro imutável de {new Date(record.created_at).toLocaleString('pt-BR')}. Esta versão
          histórica não constitui liberação do conteúdo ou dos anexos.
        </p>
        <pre>{JSON.stringify(record.snapshot, null, 2)}</pre>
      </section>
    );
  } catch (error) {
    return (
      <p role="status">{message(error instanceof Error ? error.message : 'KB_UNAVAILABLE')}</p>
    );
  }
}
