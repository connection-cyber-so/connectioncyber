import { NextResponse, type NextRequest } from 'next/server';
import { revalidatePath } from 'next/cache';
import { isSameOriginRequest } from '@/domain/request-origin';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';
import { isUuid, type AcademyAction } from '@/domain/academy';
import { runAcademyCommand } from '@/features/academy/service';

type AdminActionOptions = {
  action: AcademyAction | ((formData: FormData) => AcademyAction);
  // create_course é a única ação sem curso ainda (courseRequired false).
  courseRequired?: boolean;
  // Allowlist de campos que viram p_data — qualquer outro campo é ignorado.
  fields?: readonly string[];
  // Campos permitidos a vazio (ex.: alvo para limpar). Os demais vazios são omitidos.
  emptyOk?: readonly string[];
  redirectTo?: string;
};

const MAX_FIELD_CHARS = 5000;

// M23-G2 — curadoria do catálogo: mesmo contrato de segurança do form-action
// (same-origin + membership autorizada + UUID + escrita só via public.academy_command),
// com allowlist de campos no lugar do payload fixo do G1.
export async function runAcademyAdminAction(
  request: NextRequest,
  options: AdminActionOptions
): Promise<NextResponse> {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }

  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') {
    return NextResponse.redirect(new URL('/login', request.url), 303);
  }

  const formData = await request.formData();
  const action =
    typeof options.action === 'function' ? options.action(formData) : options.action;
  const rawCourseId = String(formData.get('course_id') ?? '');
  const courseId = isUuid(rawCourseId) ? rawCourseId : null;
  const back = new URL(options.redirectTo ?? '/academia/admin', request.url);

  if (options.courseRequired !== false && !courseId) {
    back.searchParams.set('erro', 'ACADEMY_INVALID_INPUT');
    return NextResponse.redirect(back, 303);
  }

  const data: Record<string, unknown> = {};
  for (const field of options.fields ?? []) {
    const raw = formData.get(field);
    if (raw === null) continue;
    const value = String(raw).trim();
    if (value.length > MAX_FIELD_CHARS) {
      back.searchParams.set('erro', 'ACADEMY_INVALID_INPUT');
      return NextResponse.redirect(back, 303);
    }
    if (value === '' && !(options.emptyOk ?? []).includes(field)) continue;
    data[field] = value;
  }

  const supabase = await createClient();
  const result = await runAcademyCommand(supabase, {
    tenantId: access.membership.tenantId,
    action,
    courseId,
    data,
  });

  if (!result.ok) {
    back.searchParams.set('erro', result.code);
    return NextResponse.redirect(back, 303);
  }

  revalidatePath('/academia');
  revalidatePath('/academia/admin');
  back.searchParams.set('sucesso', action);
  return NextResponse.redirect(back, 303);
}
