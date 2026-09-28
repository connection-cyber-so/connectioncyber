import { NextResponse, type NextRequest } from 'next/server';
import { revalidatePath } from 'next/cache';
import { isSameOriginRequest } from '@/domain/request-origin';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';
import { isUuid, type AcademyAction } from '@/domain/academy';
import { runAcademyCommand } from '@/features/academy/service';

type AcademyFormOptions = {
  action: AcademyAction;
  requireModule?: boolean;
  redirectTo: (courseId: string | null) => string;
};

// M23-G1 — mesmas regras das rotas de cadastro do portal (M21-G2): same-origin
// obrigatório, tenant sempre da membership autorizada, validação de UUID antes de
// qualquer chamada e escrita exclusivamente via public.academy_command.
export async function runAcademyFormAction(
  request: NextRequest,
  options: AcademyFormOptions
): Promise<NextResponse> {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }

  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') {
    return NextResponse.redirect(new URL('/login', request.url), 303);
  }

  const formData = await request.formData();
  const rawCourseId = String(formData.get('course_id') ?? '');
  const rawModuleId = String(formData.get('module_id') ?? '');
  const courseId = isUuid(rawCourseId) ? rawCourseId : null;
  const back = new URL(options.redirectTo(courseId), request.url);

  if (!courseId) {
    back.searchParams.set('erro', 'ACADEMY_INVALID_INPUT');
    return NextResponse.redirect(back, 303);
  }
  if (options.requireModule && !isUuid(rawModuleId)) {
    back.searchParams.set('erro', 'ACADEMY_MODULE_REQUIRED');
    return NextResponse.redirect(back, 303);
  }

  const supabase = await createClient();
  const result = await runAcademyCommand(supabase, {
    tenantId: access.membership.tenantId,
    action: options.action,
    courseId,
    data: options.requireModule ? { module_id: rawModuleId } : {},
  });

  if (!result.ok) {
    back.searchParams.set('erro', result.code);
    return NextResponse.redirect(back, 303);
  }

  revalidatePath('/academia');
  revalidatePath(`/academia/${courseId}`);
  back.searchParams.set('sucesso', options.action);
  return NextResponse.redirect(back, 303);
}
