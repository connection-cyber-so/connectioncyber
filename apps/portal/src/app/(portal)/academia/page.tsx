import { notFound, redirect } from 'next/navigation';
import Link from 'next/link';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';
import {
  listMyEnrollments,
  listPublishedCourses,
  loadAcademyContext,
} from '@/features/academy/service';
import {
  academyErrorMessage,
  canEnroll,
  courseLevelLabel,
  enrollmentStatusLabel,
  formatProgress,
} from '@/domain/academy';
import './academia.css';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

// M23-G1 — porta 1 da Academia no portal do cliente: catálogo + minhas matrículas.
// Leitura direta (RLS da 0044 só concede SELECT) e qualquer escrita acontece nas
// rotas POST que chamam public.academy_command — nunca insert/update na tela.
export default async function AcademiaPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind !== 'authorized') redirect('/login');

  const errorCode = typeof params.erro === 'string' ? params.erro : '';
  const success = typeof params.sucesso === 'string' && params.sucesso.length > 0;

  const tenantId = access.membership.tenantId;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const userId = user?.id ?? '';

  const [context, courses, enrollments] = await Promise.all([
    loadAcademyContext(supabase, tenantId),
    listPublishedCourses(supabase, tenantId),
    userId ? listMyEnrollments(supabase, tenantId, userId) : Promise.resolve([]),
  ]);
  const enrollmentByCourse = new Map(enrollments.map((item) => [item.course_id, item]));

  return (
    <div>
      <div className="ac-header-bar">
        <div>
          <div className="eyebrow">ConnectionCyber · Academia</div>
          <h1>Academia</h1>
        </div>
        <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
          {context.manage ? (
            <Link className="button ghost compact" href="/academia/admin">Catálogo</Link>
          ) : null}
          <span className="ac-count">
            {context.access ? `${courses.length} curso(s) publicado(s)` : 'Módulo de ensino'}
          </span>
        </div>
      </div>

      {success ? (
        <div className="ac-banner" role="status">
          <strong>Ação concluída.</strong>
          Matrícula e progresso atualizados no banco.
        </div>
      ) : null}
      {errorCode ? (
        <div className="ac-banner" role="alert">
          <strong>Não foi possível concluir.</strong>
          {academyErrorMessage(errorCode)}
        </div>
      ) : null}

      {!context.access ? (
        <div className="ac-banner" role="status">
          <strong>Academia indisponível para {access.membership.tenantName}.</strong>
          {context.capability
            ? 'Sua conta não tem permissão de leitura aqui — peça acesso a um administrador do tenant.'
            : 'A capacidade academy.courses não está contratada para esta empresa. Fale com o time ConnectionCyber para ativar.'}
        </div>
      ) : (
        <>
          <p className="ac-section-title">Minhas matrículas</p>
          {enrollments.length === 0 ? (
            <div className="ac-empty">Nenhuma matrícula ainda — escolha um curso abaixo para começar.</div>
          ) : (
            <div className="ac-grid">
              {enrollments.map((enrollment) => {
                const course = courses.find((item) => item.id === enrollment.course_id);
                return (
                  <div className="ac-card" key={enrollment.course_id}>
                    <div className="ac-meta">
                      <span className={`ac-tag${enrollment.status === 'concluida' ? ' done' : ''}`}>
                        {enrollmentStatusLabel(enrollment.status)}
                      </span>
                      <span className="ac-tag">{formatProgress(enrollment.progresso)}</span>
                    </div>
                    <h3>{course?.titulo ?? 'Curso'}</h3>
                    <div className="ac-progress" aria-hidden="true">
                      <span style={{ width: `${Math.min(100, Math.max(0, enrollment.progresso))}%` }} />
                    </div>
                    <div className="ac-actions">
                      <Link className="button compact" href={`/academia/${enrollment.course_id}`}>
                        Continuar
                      </Link>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          <p className="ac-section-title">Catálogo</p>
          {courses.length === 0 ? (
            <div className="ac-empty">
              Nenhum curso publicado ainda. Gestores da Academia podem criar e publicar cursos por aqui.
            </div>
          ) : (
            <div className="ac-grid">
              {courses.map((course) => {
                const enrollment = enrollmentByCourse.get(course.id) ?? null;
                const enrollable = canEnroll({ context, courseStatus: course.status, enrollment });
                return (
                  <div className="ac-card" key={course.id}>
                    <div className="ac-meta">
                      <span className="ac-tag live">{course.categoria}</span>
                      <span className="ac-tag">{courseLevelLabel(course.nivel)}</span>
                      {enrollment ? (
                        <span className={`ac-tag${enrollment.status === 'concluida' ? ' done' : ''}`}>
                          {enrollmentStatusLabel(enrollment.status)} · {formatProgress(enrollment.progresso)}
                        </span>
                      ) : null}
                    </div>
                    <h3>{course.titulo}</h3>
                    <p>{course.descricao || 'Sem descrição.'}</p>
                    <div className="ac-actions">
                      <Link className="button ghost compact" href={`/academia/${course.id}`}>
                        Ver curso
                      </Link>
                      {enrollable ? (
                        <form method="post" action="/academia/matricular">
                          <input type="hidden" name="course_id" value={course.id} />
                          <button className="button compact" type="submit">Matricular</button>
                        </form>
                      ) : null}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </>
      )}

      <div className="ac-banner" style={{ marginTop: 26 }}>
        <strong>Grava direto no banco — não é uma demonstração.</strong>
        Matrícula e conclusão de módulo passam por <code>public.academy_command</code> com a regra
        transacional da fundação do M23-G0.
      </div>
    </div>
  );
}
