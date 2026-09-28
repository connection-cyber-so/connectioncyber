import { notFound, redirect } from 'next/navigation';
import Link from 'next/link';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';
import {
  listCuratorCatalog,
  listGlobalCatalog,
  loadAcademyContext,
} from '@/features/academy/service';
import {
  academyErrorMessage,
  courseStatusLabel,
  type AcademyCatalogCourse,
} from '@/domain/academy';
import '../academia.css';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

function alvoLabel(course: AcademyCatalogCourse): string {
  if (course.publico) return 'Toda empresa';
  const parts: string[] = [];
  if (course.alvo_sistema) parts.push(`Sistema: ${course.alvo_sistema}`);
  if (course.alvo_vertical) parts.push(`Vertical: ${course.alvo_vertical}`);
  return parts.join(' · ') || 'Sem alvo';
}

// M23-G2 — Catálogo (curadoria): criação/edição de cursos, vínculo do catálogo
// global e alvos. Toda escrita sai por POST → public.academy_command (0048); a
// leitura do global acontece pela RLS de descoberta — gestor vê, aluno não.
export default async function AcademiaAdminPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind !== 'authorized') redirect('/login');

  const errorCode = typeof params.erro === 'string' ? params.erro : '';
  const success = typeof params.sucesso === 'string' && params.sucesso.length > 0;

  const tenantId = access.membership.tenantId;
  const supabase = await createClient();
  const context = await loadAcademyContext(supabase, tenantId);

  if (!context.access || !context.manage) {
    return (
      <div>
        <div className="ac-header-bar">
          <div>
            <div className="eyebrow">ConnectionCyber · Academia</div>
            <h1>Catálogo</h1>
          </div>
        </div>
        <div className="ac-banner" role="alert">
          <strong>Curadoria indisponível para {access.membership.tenantName}.</strong>
          Só gestores da Academia (capacidade academy.manage) curam o catálogo aqui.
        </div>
        <Link className="ac-back" href="/academia">← Voltar para a Academia</Link>
      </div>
    );
  }

  const [{ courses, links }, globalCourses, moduleKeysResult] = await Promise.all([
    listCuratorCatalog(supabase, tenantId),
    listGlobalCatalog(supabase),
    supabase.from('module_catalog').select('key, name').order('name', { ascending: true }),
  ]);
  const moduleKeys = (moduleKeysResult.data ?? []) as { key: string; name: string }[];
  const linkByCourse = new Map(links.map((link) => [link.course_id, link]));
  const editable = (course: { tenant_id: string }) =>
    context.staff || course.tenant_id === tenantId;

  return (
    <div>
      <div className="ac-header-bar">
        <div>
          <div className="eyebrow">ConnectionCyber · Academia · Curadoria</div>
          <h1>Catálogo</h1>
        </div>
        <span className="ac-count">
          {courses.length} vinculado(s) · {globalCourses.length} global(is)
        </span>
      </div>

      {success ? (
        <div className="ac-banner" role="status">
          <strong>Ação concluída.</strong>
          O catálogo foi atualizado no banco.
        </div>
      ) : null}
      {errorCode ? (
        <div className="ac-banner" role="alert">
          <strong>Não foi possível concluir.</strong>
          {academyErrorMessage(errorCode)}
        </div>
      ) : null}

      <p className="ac-section-title">Cursos desta empresa</p>
      {courses.length === 0 ? (
        <div className="ac-empty">Nenhum curso vinculado ainda — crie um abaixo ou vincule um global.</div>
      ) : (
        <div className="ac-grid">
          {courses.map((course) => {
            const link = linkByCourse.get(course.id) ?? null;
            const canCurate = editable(course);
            const nextStatus = course.status === 'publicado' ? 'rascunho' : 'publicado';
            return (
              <div className="ac-card" key={course.id}>
                <div className="ac-meta">
                  <span className={`ac-tag${course.status === 'publicado' ? ' live' : ''}`}>
                    {courseStatusLabel(course.status)}
                  </span>
                  <span className="ac-tag">{course.escopo === 'global' ? 'Global' : 'Empresa'}</span>
                  {course.escopo === 'global' ? <span className="ac-tag">{alvoLabel(course)}</span> : null}
                  {link ? <span className="ac-tag">Vínculo {link.origem}</span> : null}
                </div>
                <h3>{course.titulo}</h3>
                <p>{course.descricao || 'Sem descrição.'}</p>
                <div className="ac-actions">
                  <Link className="button ghost compact" href={`/academia/${course.id}`}>
                    Abrir
                  </Link>
                  {canCurate ? (
                    <form method="post" action="/academia/admin/publicar">
                      <input type="hidden" name="course_id" value={course.id} />
                      <input type="hidden" name="status" value={nextStatus} />
                      <button className="button compact" type="submit">
                        {nextStatus === 'publicado' ? 'Publicar' : 'Despublicar'}
                      </button>
                    </form>
                  ) : null}
                </div>
              </div>
            );
          })}
        </div>
      )}

      <p className="ac-section-title">Criar curso</p>
      <form method="post" action="/academia/admin/criar" className="ac-card" style={{ gap: 10 }}>
        <input name="titulo" placeholder="Título (3 a 180 caracteres)" required minLength={3} maxLength={180} />
        <textarea name="descricao" placeholder="Descrição" rows={3} maxLength={5000} />
        <input name="categoria" placeholder="Categoria (padrão: Geral)" maxLength={80} />
        {context.staff ? (
          <>
            <label className="ac-tag" style={{ display: 'flex', justifyContent: 'space-between' }}>
              Escopo
              <select name="escopo" defaultValue="global">
                <option value="global">Global (plataforma)</option>
                <option value="tenant">Só esta empresa</option>
              </select>
            </label>
            <label className="ac-tag" style={{ display: 'flex', justifyContent: 'space-between' }}>
              Público
              <select name="publico" defaultValue="true">
                <option value="true">Toda empresa</option>
                <option value="false">Alvo específico</option>
              </select>
            </label>
            <input name="alvo_sistema" list="ac-module-keys" placeholder="alvo_sistema (preencher só com alvo)" />
            <input name="alvo_vertical" placeholder="alvo_vertical (preencher só com alvo)" />
          </>
        ) : null}
        <div className="ac-actions">
          <button className="button compact" type="submit">Criar curso</button>
        </div>
      </form>

      <p className="ac-section-title">Novo módulo</p>
      <form method="post" action="/academia/admin/modulo" className="ac-card" style={{ gap: 10 }}>
        <select name="course_id" required>
          <option value="">Escolha o curso…</option>
          {courses.filter(editable).map((course) => (
            <option key={course.id} value={course.id}>{course.titulo}</option>
          ))}
        </select>
        <input name="titulo" placeholder="Título do módulo (3 a 180)" required minLength={3} maxLength={180} />
        <label className="ac-tag" style={{ display: 'flex', justifyContent: 'space-between' }}>
          Tipo
          <select name="tipo" defaultValue="texto">
            <option value="texto">Texto</option>
            <option value="video">Vídeo</option>
            <option value="pdf">PDF</option>
            <option value="quiz">Quiz</option>
            <option value="prova">Prova</option>
          </select>
        </label>
        <input name="conteudo_ref" placeholder="conteudo_ref (academy:… ou https://…)" />
        <input name="duracao_min" inputMode="numeric" pattern="[0-9]{1,6}" placeholder="Duração em minutos" />
        <div className="ac-actions">
          <button className="button compact" type="submit">Adicionar módulo</button>
        </div>
      </form>

      <p className="ac-section-title">Catálogo global</p>
      {globalCourses.length === 0 ? (
        <div className="ac-empty">Nenhum curso global no catálogo ainda.</div>
      ) : (
        <div className="ac-grid">
          {globalCourses.map((course) => {
            const link = linkByCourse.get(course.id) ?? null;
            return (
              <div className="ac-card" key={course.id}>
                <div className="ac-meta">
                  <span className={`ac-tag${course.status === 'publicado' ? ' live' : ''}`}>
                    {courseStatusLabel(course.status)}
                  </span>
                  <span className="ac-tag">{alvoLabel(course)}</span>
                  {link ? <span className="ac-tag done">Vinculado · {link.origem}</span> : null}
                </div>
                <h3>{course.titulo}</h3>
                <p>{course.descricao || 'Sem descrição.'}</p>
                <div className="ac-actions">
                  {!link ? (
                    <form method="post" action="/academia/admin/vincular">
                      <input type="hidden" name="course_id" value={course.id} />
                      <input type="hidden" name="op" value="vincular" />
                      <button className="button compact" type="submit">Vincular</button>
                    </form>
                  ) : link.origem === 'manual' ? (
                    <form method="post" action="/academia/admin/vincular">
                      <input type="hidden" name="course_id" value={course.id} />
                      <input type="hidden" name="op" value="desvincular" />
                      <button className="button ghost compact" type="submit">Desvincular</button>
                    </form>
                  ) : (
                    <span className="ac-tag">Vínculo automático (alvo)</span>
                  )}
                </div>
                {context.staff ? (
                  <form method="post" action="/academia/admin/alvos" style={{ display: 'grid', gap: 6 }}>
                    <input type="hidden" name="course_id" value={course.id} />
                    <label className="ac-tag" style={{ display: 'flex', justifyContent: 'space-between' }}>
                      Público
                      <select name="publico" defaultValue={course.publico ? 'true' : 'false'}>
                        <option value="true">Toda empresa</option>
                        <option value="false">Alvo específico</option>
                      </select>
                    </label>
                    <input name="alvo_sistema" list="ac-module-keys" defaultValue={course.alvo_sistema ?? ''} placeholder="alvo_sistema" />
                    <input name="alvo_vertical" defaultValue={course.alvo_vertical ?? ''} placeholder="alvo_vertical" />
                    <div className="ac-actions">
                      <button className="button ghost compact" type="submit">Salvar alvos</button>
                    </div>
                  </form>
                ) : null}
              </div>
            );
          })}
        </div>
      )}

      <datalist id="ac-module-keys">
        {moduleKeys.map((module) => (
          <option key={module.key} value={module.key}>{module.name}</option>
        ))}
      </datalist>

      <div className="ac-banner" style={{ marginTop: 26 }}>
        <strong>Curadoria transacional — tudo via public.academy_command.</strong>
        Criar/publicar/vincular/alvos rodam na regra da 0048: só gestor cura, só a
        plataforma toca em curso global, e o vínculo automático nasce do alvo.
      </div>

      <Link className="ac-back" href="/academia">← Voltar para a Academia</Link>
    </div>
  );
}
