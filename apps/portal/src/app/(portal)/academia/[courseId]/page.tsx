import { notFound, redirect } from 'next/navigation';
import Link from 'next/link';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';
import {
  listModules,
  listProgress,
  loadAcademyContext,
  loadCourse,
  loadEnrollment,
} from '@/features/academy/service';
import {
  academyErrorMessage,
  canCompleteModule,
  canEnroll,
  courseLevelLabel,
  courseStatusLabel,
  enrollmentStatusLabel,
  formatDuration,
  formatProgress,
  isUuid,
  moduleKindLabel,
} from '@/domain/academy';
import '../academia.css';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type PageProps = {
  params: Promise<{ courseId: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

export default async function AcademyCoursePage({ params, searchParams }: PageProps) {
  const { courseId } = await params;
  const sp = await searchParams;
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind !== 'authorized') redirect('/login');
  if (!isUuid(courseId)) notFound();

  const tenantId = access.membership.tenantId;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  const userId = user?.id ?? '';

  const context = await loadAcademyContext(supabase, tenantId);
  if (!context.access) notFound();

  const course = await loadCourse(supabase, tenantId, courseId);
  if (!course) notFound();

  const [enrollment, modules, progress] = await Promise.all([
    userId ? loadEnrollment(supabase, tenantId, userId, courseId) : Promise.resolve(null),
    listModules(supabase, courseId),
    userId ? listProgress(supabase, tenantId, userId, courseId) : Promise.resolve([]),
  ]);
  const doneModules = new Set(progress.filter((row) => row.concluido).map((row) => row.module_id));
  const enrollable = canEnroll({ context, courseStatus: course.status, enrollment });
  const errorCode = typeof sp.erro === 'string' ? sp.erro : '';
  const success = typeof sp.sucesso === 'string' && sp.sucesso.length > 0;

  return (
    <div>
      <div className="ac-header-bar">
        <div>
          <div className="eyebrow">ConnectionCyber · Academia</div>
          <h1>{course.titulo}</h1>
        </div>
        <span className="ac-count">{courseStatusLabel(course.status)}</span>
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

      <div className="ac-meta" style={{ marginTop: 16 }}>
        <span className="ac-tag live">{course.categoria}</span>
        <span className="ac-tag">{courseLevelLabel(course.nivel)}</span>
        <span className="ac-tag">{course.idioma}</span>
        <span className={`ac-tag${enrollment?.status === 'concluida' ? ' done' : ''}`}>
          {enrollment ? `${enrollmentStatusLabel(enrollment.status)} · ${formatProgress(enrollment.progresso)}` : 'Sem matrícula'}
        </span>
      </div>

      {course.descricao ? <p style={{ marginTop: 14, lineHeight: 1.6 }}>{course.descricao}</p> : null}

      <div className="ac-actions" style={{ marginTop: 8 }}>
        {enrollable ? (
          <form method="post" action="/academia/matricular">
            <input type="hidden" name="course_id" value={course.id} />
            <button className="button compact" type="submit">Matricular neste curso</button>
          </form>
        ) : null}
        {enrollment && enrollment.status === 'ativa' ? (
          <form method="post" action="/academia/cancelar-matricula">
            <input type="hidden" name="course_id" value={course.id} />
            <button className="button ghost compact" type="submit">Cancelar matrícula</button>
          </form>
        ) : null}
      </div>

      <p className="ac-section-title">Módulos · {modules.length}</p>
      {modules.length === 0 ? (
        <div className="ac-empty">Este curso ainda não tem módulos publicados.</div>
      ) : (
        <div>
          {modules.map((module, index) => {
            const done = doneModules.has(module.id);
            const completable = canCompleteModule({ context, enrollment, moduleDone: done });
            return (
              <div className={`ac-module ${done ? 'done' : 'todo'}`} key={module.id}>
                <div className="ac-module-main">
                  <strong>
                    {index + 1}. {module.titulo}
                  </strong>
                  <small>
                    {moduleKindLabel(module.tipo)} · {formatDuration(module.duracao_min)}
                    {module.conteudo_ref ? ` · ${module.conteudo_ref}` : ''}
                  </small>
                </div>
                {done ? (
                  <span className="ac-tag done">Concluído</span>
                ) : completable ? (
                  <form method="post" action="/academia/concluir-modulo">
                    <input type="hidden" name="course_id" value={course.id} />
                    <input type="hidden" name="module_id" value={module.id} />
                    <button className="button compact" type="submit">Concluir módulo</button>
                  </form>
                ) : (
                  <span className="ac-tag">Pendente</span>
                )}
              </div>
            );
          })}
        </div>
      )}

      <Link className="ac-back" href="/academia">← Voltar para a Academia</Link>
    </div>
  );
}
