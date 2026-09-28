import 'server-only';
import { createClient } from '@/lib/supabase/server';
import {
  parseAcademyContext,
  type AcademyCatalogCourse,
  type AcademyContext,
  type AcademyCourse,
  type AcademyEnrollment,
  type AcademyLink,
  type AcademyModule,
  type AcademyProgressRow,
} from '@/domain/academy';

type PortalClient = Awaited<ReturnType<typeof createClient>>;

// M23-G2 — colunas de curadoria: catálogo global carrega escopo + alvos da 0048.
const CATALOG_COLUMNS =
  'id, tenant_id, titulo, descricao, categoria, idioma, nivel, status, capa_url, publicado_em, escopo, publico, alvo_sistema, alvo_vertical';

export async function loadAcademyContext(
  supabase: PortalClient,
  tenantId: string
): Promise<AcademyContext> {
  const { data, error } = await supabase.rpc('academy_context', { p_tenant: tenantId });
  if (error) return { access: false, manage: false, capability: false, staff: false };
  return parseAcademyContext(data);
}

// M23-G2 — o catálogo do aluno é resolvido por vínculo (academy_tenant_courses),
// nunca por tenant_id do curso: global nasce no dono e continua visível ao aluno.
export async function listLinkedCourseIds(
  supabase: PortalClient,
  tenantId: string
): Promise<string[]> {
  const { data, error } = await supabase
    .from('academy_tenant_courses')
    .select('course_id')
    .eq('tenant_id', tenantId)
    .eq('ativo', true);
  if (error) return [];
  return (data ?? []).map((row) => String((row as { course_id: unknown }).course_id));
}

export async function listPublishedCourses(
  supabase: PortalClient,
  tenantId: string
): Promise<AcademyCourse[]> {
  const linked = await listLinkedCourseIds(supabase, tenantId);
  if (linked.length === 0) return [];
  const { data, error } = await supabase
    .from('academy_courses')
    .select('id, tenant_id, titulo, descricao, categoria, idioma, nivel, status, capa_url, publicado_em')
    .in('id', linked)
    .eq('status', 'publicado')
    .order('publicado_em', { ascending: false });
  if (error) return [];
  return (data ?? []) as AcademyCourse[];
}

export async function loadCourse(
  supabase: PortalClient,
  tenantId: string,
  courseId: string
): Promise<AcademyCourse | null> {
  const linked = await listLinkedCourseIds(supabase, tenantId);
  if (!linked.includes(courseId)) return null;
  const { data, error } = await supabase
    .from('academy_courses')
    .select('id, tenant_id, titulo, descricao, categoria, idioma, nivel, status, capa_url, publicado_em')
    .eq('id', courseId)
    .maybeSingle();
  if (error || !data) return null;
  return data as AcademyCourse;
}

export async function listMyEnrollments(
  supabase: PortalClient,
  tenantId: string,
  userId: string
): Promise<AcademyEnrollment[]> {
  const { data, error } = await supabase
    .from('academy_enrollments')
    .select('course_id, status, progresso, concluida_em')
    .eq('tenant_id', tenantId)
    .eq('user_id', userId)
    .neq('status', 'cancelada');
  if (error) return [];
  return (data ?? []) as AcademyEnrollment[];
}

export async function loadEnrollment(
  supabase: PortalClient,
  tenantId: string,
  userId: string,
  courseId: string
): Promise<AcademyEnrollment | null> {
  const { data, error } = await supabase
    .from('academy_enrollments')
    .select('course_id, status, progresso, concluida_em')
    .eq('tenant_id', tenantId)
    .eq('user_id', userId)
    .eq('course_id', courseId)
    .maybeSingle();
  if (error || !data) return null;
  return data as AcademyEnrollment;
}

// M23-G2 — módulos são lidos por course_id: o curso global mora no tenant dono e
// o aluno chega até ele pelo vínculo (RLS academy_module_read), não por tenant_id.
export async function listModules(
  supabase: PortalClient,
  courseId: string
): Promise<AcademyModule[]> {
  const { data, error } = await supabase
    .from('academy_modules')
    .select('id, course_id, titulo, tipo, conteudo_ref, duracao_min, ordem')
    .eq('course_id', courseId)
    .order('ordem', { ascending: true });
  if (error) return [];
  return (data ?? []) as AcademyModule[];
}

// M23-G2 — curadoria: cursos vinculados à empresa (inclui rascunho) + estado do vínculo.
export async function listCuratorCatalog(
  supabase: PortalClient,
  tenantId: string
): Promise<{ courses: AcademyCatalogCourse[]; links: AcademyLink[] }> {
  const { data: linkRows, error: linkError } = await supabase
    .from('academy_tenant_courses')
    .select('course_id, origem, ativo')
    .eq('tenant_id', tenantId)
    .eq('ativo', true);
  if (linkError) return { courses: [], links: [] };
  const links = (linkRows ?? []) as AcademyLink[];
  const ids = links.map((link) => link.course_id);
  if (ids.length === 0) return { courses: [], links: [] };
  const { data, error } = await supabase
    .from('academy_courses')
    .select(CATALOG_COLUMNS)
    .in('id', ids)
    .order('titulo', { ascending: true });
  if (error) return { courses: [], links };
  return { courses: (data ?? []) as AcademyCatalogCourse[], links };
}

// M23-G2 — descoberta do catálogo global: a RLS (0048) só devolve o que o gestor
// pode ver (staff vê tudo; gestor enxerga globais para poder vincular).
export async function listGlobalCatalog(
  supabase: PortalClient
): Promise<AcademyCatalogCourse[]> {
  const { data, error } = await supabase
    .from('academy_courses')
    .select(CATALOG_COLUMNS)
    .eq('escopo', 'global')
    .order('titulo', { ascending: true });
  if (error) return [];
  return (data ?? []) as AcademyCatalogCourse[];
}

export async function listProgress(
  supabase: PortalClient,
  tenantId: string,
  userId: string,
  courseId: string
): Promise<AcademyProgressRow[]> {
  const { data, error } = await supabase
    .from('academy_progress')
    .select('module_id, concluido')
    .eq('tenant_id', tenantId)
    .eq('user_id', userId)
    .eq('course_id', courseId);
  if (error) return [];
  return (data ?? []) as AcademyProgressRow[];
}

// M23-G1 — toda escrita passa por public.academy_command (0044): nenhuma tela
// grava direto em academy_* (a RLS nem deixaria — para cliente existe só SELECT).
export async function runAcademyCommand(
  supabase: PortalClient,
  input: { tenantId: string; action: string; courseId?: string | null; data?: Record<string, unknown> }
): Promise<{ ok: true } | { ok: false; code: string }> {
  const { error } = await supabase.rpc('academy_command', {
    p_tenant: input.tenantId,
    p_action: input.action,
    p_course: input.courseId ?? null,
    p_data: input.data ?? {},
  });
  if (!error) return { ok: true };
  const message = (error as { message?: string }).message ?? '';
  const code = /ACADEMY_[A-Z_]+/.exec(message)?.[0];
  return { ok: false, code: code || 'ACADEMY_COMMAND_FAILED' };
}
