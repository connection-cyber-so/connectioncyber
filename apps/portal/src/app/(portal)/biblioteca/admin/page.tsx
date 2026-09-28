import Link from 'next/link';
import { catalog, dashboard } from '@/features/knowledge-base/service';
import { gates } from '@/features/knowledge-base/types';
import { message } from '@/features/knowledge-base/messages';
import '../knowledge-base.css';
export const dynamic = 'force-dynamic';
export default async function Admin() {
  try {
    const result = await catalog({ sort: 'updated' });
    if (!result.manage) return <p>A curadoria exige permissão e MFA.</p>;
    const stats = await dashboard();
    return (
      <section className="kb">
        <Link href="/biblioteca">← Biblioteca</Link>
        <h1>Curadoria e governança</h1>
        <p>
          Revise a classificação, a aplicação técnica e o destino de cada material. A liberação
          exige um curador diferente do autor.
        </p>
        <div className="kb-stats">
          {gates.map((gate, i) => (
            <Link key={gate} className="kb-stat" href={'/biblioteca?stage=' + i}>
              {gate}
              <strong>{stats.counts[i]}</strong>
            </Link>
          ))}
        </div>
        <div className="kb-panel">
          <h2>Fila recente</h2>
          <ul className="kb-timeline">
            {result.items
              .filter((i) => i.stage < 4)
              .map((i) => (
                <li key={i.id}>
                  <Link href={'/biblioteca/' + i.id}>{i.title}</Link> · {gates[i.stage]} · v
                  {i.revision}
                </li>
              ))}
          </ul>
          <p>Selecione um gate acima para consultar a fila completa.</p>
        </div>
        <div className="kb-panel">
          <h2>Política de acesso</h2>
          <p>
            Assinaturas e papéis são provisionados pelo operador autorizado. A curadoria não concede
            assinatura, não executa scripts e não publica em repositórios.
          </p>
          <p>
            Os eventos e versões estão na página de cada item. Arquivos em quarentena exigem
            evidência de inspeção de segurança antes da aprovação.
          </p>
        </div>
      </section>
    );
  } catch (error) {
    return <p>{message(error instanceof Error ? error.message : 'KB_UNAVAILABLE')}</p>;
  }
}
