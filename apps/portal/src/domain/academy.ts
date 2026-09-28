export type AcademyContext = {
  access: boolean;
  manage: boolean;
  capability: boolean;
  staff: boolean;
};

export type AcademyCourseStatus = 'rascunho' | 'publicado' | 'arquivado';

export type AcademyEnrollmentStatus = 'ativa' | 'cancelada' | 'concluida';

export type AcademyAction =
  | 'enroll'
  | 'unenroll'
  | 'complete_module'
  | 'create_course'
  | 'publish_course'
  | 'add_module'
  | 'link_course'
  | 'unlink_course'
  | 'set_course_targets';

export type AcademyCourseEscopo = 'tenant' | 'global';

export type AcademyModuleKind = 'video' | 'texto' | 'pdf' | 'quiz' | 'prova';

export type AcademyCourse = {
  id: string;
  tenant_id: string;
  titulo: string;
  descricao: string;
  categoria: string;
  idioma: string;
  nivel: string;
  status: AcademyCourseStatus;
  capa_url: string | null;
  publicado_em: string | null;
};

// M23-G2 — leitura de curadoria: curso com o escopo global (alvo + vínculo) da 0048.
export type AcademyCatalogCourse = AcademyCourse & {
  escopo: AcademyCourseEscopo;
  publico: boolean;
  alvo_sistema: string | null;
  alvo_vertical: string | null;
};

export type AcademyLink = {
  course_id: string;
  origem: 'auto' | 'manual';
  ativo: boolean;
};

export type AcademyModule = {
  id: string;
  course_id: string;
  titulo: string;
  tipo: AcademyModuleKind;
  conteudo_ref: string;
  duracao_min: number;
  ordem: number;
};

export type AcademyEnrollment = {
  course_id: string;
  status: AcademyEnrollmentStatus;
  progresso: number;
  concluida_em: string | null;
};

export type AcademyProgressRow = {
  module_id: string;
  concluido: boolean;
};

const UUID_PATTERN = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
const ACADEMY_ACTIONS = new Set<AcademyAction>([
  'enroll',
  'unenroll',
  'complete_module',
  'create_course',
  'publish_course',
  'add_module',
  'link_course',
  'unlink_course',
  'set_course_targets',
]);

// M23-G1 — contexto vindo de public.academy_context: qualquer payload malformado
// vira "sem acesso" (fail-closed igual à RLS da 0044), nunca "true" por omissão.
// M23-G2 — 'staff' (is_platform_staff) segue a mesma regra: só true com true literal.
export function parseAcademyContext(raw: unknown): AcademyContext {
  const record =
    typeof raw === 'object' && raw !== null ? (raw as Record<string, unknown>) : {};
  return {
    access: record.access === true,
    manage: record.manage === true,
    capability: record.capability === true,
    staff: record.staff === true,
  };
}

export function isAcademyAction(value: unknown): value is AcademyAction {
  return typeof value === 'string' && ACADEMY_ACTIONS.has(value as AcademyAction);
}

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID_PATTERN.test(value);
}

export function isAcademyModuleKind(value: unknown): value is AcademyModuleKind {
  return ['video', 'texto', 'pdf', 'quiz', 'prova'].includes(String(value));
}

export function canEnroll(input: {
  context: AcademyContext;
  courseStatus: AcademyCourseStatus;
  enrollment: AcademyEnrollment | null;
}): boolean {
  if (!input.context.access) return false;
  if (input.courseStatus !== 'publicado') return false;
  return !input.enrollment || input.enrollment.status === 'cancelada';
}

export function canCompleteModule(input: {
  context: AcademyContext;
  enrollment: AcademyEnrollment | null;
  moduleDone: boolean;
}): boolean {
  return Boolean(input.context.access && input.enrollment && input.enrollment.status === 'ativa' && !input.moduleDone);
}

export function formatProgress(value: unknown): string {
  const numeric = typeof value === 'number' && Number.isFinite(value) ? value : 0;
  const clamped = Math.min(100, Math.max(0, numeric));
  return `${Math.round(clamped)}%`;
}

export function enrollmentStatusLabel(status: unknown): string {
  if (status === 'ativa') return 'Matriculado';
  if (status === 'concluida') return 'Concluído';
  if (status === 'cancelada') return 'Matrícula cancelada';
  return 'Sem matrícula';
}

export function courseStatusLabel(status: unknown): string {
  if (status === 'publicado') return 'Publicado';
  if (status === 'rascunho') return 'Rascunho';
  if (status === 'arquivado') return 'Arquivado';
  return '—';
}

export function courseLevelLabel(nivel: unknown): string {
  if (nivel === 'intermediario') return 'Intermediário';
  if (nivel === 'avancado') return 'Avançado';
  return 'Iniciante';
}

export function moduleKindLabel(tipo: unknown): string {
  if (tipo === 'video') return 'Vídeo';
  if (tipo === 'texto') return 'Texto';
  if (tipo === 'pdf') return 'PDF';
  if (tipo === 'quiz') return 'Quiz';
  if (tipo === 'prova') return 'Prova';
  return 'Conteúdo';
}

export function formatDuration(minutes: unknown): string {
  const value = typeof minutes === 'number' && Number.isFinite(minutes) && minutes > 0 ? minutes : 0;
  if (value === 0) return 'Duração não informada';
  return value === 1 ? '1 minuto' : `${Math.round(value)} minutos`;
}

const ACADEMY_ERROR_MESSAGES: Record<string, string> = {
  ACADEMY_ACCESS_DENIED: 'Sua conta não tem acesso à Academia neste tenant.',
  ACADEMY_CONTEXT_MISSING: 'Sessão inválida — entre de novo pelo portal.',
  ACADEMY_INVALID_INPUT: 'Dados inválidos — confira e tente de novo.',
  ACADEMY_COURSE_NOT_FOUND: 'Curso não encontrado.',
  ACADEMY_COURSE_NOT_AVAILABLE: 'Este curso não está publicado.',
  ACADEMY_NOT_ENROLLED: 'Você não tem matrícula ativa neste curso.',
  ACADEMY_MODULE_NOT_FOUND: 'Módulo não encontrado.',
  ACADEMY_MODULE_REQUIRED: 'Módulo inválido.',
  ACADEMY_CURATOR_REQUIRED: 'Só gestores da Academia podem curar cursos.',
  ACADEMY_RATE_LIMIT: 'Muitas ações em um minuto — aguarde um instante e tente de novo.',
  ACADEMY_TITLE_REQUIRED: 'Informe um título de curso válido.',
  ACADEMY_COURSE_EMPTY: 'Publique ao menos um módulo antes de publicar o curso.',
  ACADEMY_PLATFORM_REQUIRED: 'Só a equipe ConnectionCyber cria ou configura curso global.',
  ACADEMY_GLOBAL_TARGET_REQUIRED: 'Curso global sem público precisa de alvo (sistema e/ou vertical).',
  ACADEMY_INVALID_TARGET: 'Alvo inválido — confira o módulo do sistema e a vertical.',
  ACADEMY_TARGET_ONLY_GLOBAL: 'Alvos só se aplicam a curso global.',
  ACADEMY_LINK_ONLY_GLOBAL: 'Só curso global pode ser vinculado a uma empresa.',
  ACADEMY_LINK_AUTO: 'Este vínculo é automático — ajuste os alvos do curso global.',
  ACADEMY_COURSE_NOT_LINKED: 'Este curso não está vinculado à empresa.',
};

export function academyErrorMessage(code: unknown): string {
  if (typeof code === 'string' && ACADEMY_ERROR_MESSAGES[code]) {
    return ACADEMY_ERROR_MESSAGES[code];
  }
  return 'Não foi possível concluir a ação agora.';
}
