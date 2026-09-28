import { notFound, redirect } from 'next/navigation';
import Link from 'next/link';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';
import { listTrainingCourses, loadAcademyContext } from '@/features/academy/service';
import { courseLevelLabel, type AcademyCatalogCourse } from '@/domain/academy';
import '../academia/academia.css';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

// M23-G3 — porta 2 da Academia: o Treinamento agrupa o catalogo da empresa pela origem
// do alvo. "Do seu sistema" = cursos trazidos pelo modulo contratado (alvo_sistema);
// "Gerais" = publicos ou por vertical. Leitura direta pela mesma RLS da 0048 (vinculo
// ativo + publicado); a matricula continua na pagina do curso (/academia/[id]).
export default async function TreinamentoPage() {
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind !== 'authorized') redirect('/login');

  const tenantId = access.membership.tenantId;
  const supabase = await createClient();
  const [context, catalog] = await Promise.all([
    loadAcademyContext(supabase, tenantId),
    listTrainingCourses(supabase, tenantId),
  ]);
  const total = catalog.sistema.length + catalog.gerais.length;

  const renderCourse = (course: AcademyCatalogCourse) => (
    <div className="ac-card" key={course.id}>
      <div className="ac-meta">
        <span className="ac-tag live">{course.categoria}</span>
        <span className="ac-tag">{courseLevelLabel(course.nivel)}</span>
        {course.alvo_sistema ? <span className="ac-tag">{course.alvo_sistema}</span> : null}
      </div>
      <h3>{course.titulo}</h3>
      <p>{course.descricao || 'Sem descrição.'}</p>
      <div className="ac-actions">
        <Link className="button ghost compact" href={`/academia/${course.id}`}>Ver curso</Link>
      </div>
    </div>
  );

  return (
    <div>
      <div className="ac-header-bar">
        <div>
          <div className="eyebrow">ConnectionCyber · Academia</div>
          <h1>Treinamento</h1>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          <Link className="button ghost compact" href="/academia">Academia</Link>
          <span className="ac-count">
            {context.access ? `${total} curso(s) publicado(s)` : 'Módulo de ensino'}
          </span>
        </div>
      </div>

      {!context.access ? (
        <div className="ac-banner" role="status">
          <strong>Treinamento indisponível para {access.membership.tenantName}.</strong>
          {context.capability
            ? 'Sua conta não tem permissão de leitura aqui — peça acesso a um administrador do tenant.'
            : 'A capacidade academy.courses não está contratada para esta empresa. Fale com o time ConnectionCyber para ativar.'}
        </div>
      ) : (
        <>
          <p className="ac-section-title">Do seu sistema</p>
          {catalog.sistema.length === 0 ? (
            <div className="ac-empty">
              Nenhum curso do sistema contratado está publicado agora.
            </div>
          ) : (
            <div className="ac-grid">{catalog.sistema.map(renderCourse)}</div>
          )}

          <p className="ac-section-title">Gerais</p>
          {catalog.gerais.length === 0 ? (
            <div className="ac-empty">Nenhum curso geral publicado agora.</div>
          ) : (
            <div className="ac-grid">{catalog.gerais.map(renderCourse)}</div>
          )}
        </>
      )}
    </div>
  );
}
