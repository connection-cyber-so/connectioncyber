import { NextResponse, type NextRequest } from 'next/server';
import { isValidHexColor, isValidLogoUrl, normalizeHexColor, normalizeLogoUrl } from '@/domain/branding';
import { isSameOriginRequest } from '@/domain/request-origin';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';

function settingsError(request: NextRequest, code: string) {
  const url = new URL('/configuracoes/aparencia', request.url);
  url.searchParams.set('erro', code);
  return NextResponse.redirect(url, 303);
}

// M19-G4 — mesmo idioma de apps/portal/src/app/auth/select-membership/route.ts:
// formulário sem JS, same-origin obrigatório, tenant sempre vem da sessão
// (nunca de input do form), revalida tudo no servidor mesmo já validado no
// browser, e a RLS/RPC de supabase/migrations/0035 continua sendo a
// fronteira real — este handler não confia na própria checagem de
// permissão, só decide qual mensagem de erro mostrar.
export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }

  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') {
    return NextResponse.redirect(new URL('/login', request.url), 303);
  }

  const formData = await request.formData();
  const resetColor = String(formData.get('reset_color') ?? '') === '1';
  const rawColor = String(formData.get('primary_color') ?? '');
  const rawLogo = String(formData.get('logo_url') ?? '');

  const primaryColor = resetColor ? null : normalizeHexColor(rawColor);
  if (!resetColor && rawColor.trim() && !isValidHexColor(rawColor.trim())) {
    return settingsError(request, 'cor');
  }

  const logoUrl = normalizeLogoUrl(rawLogo);
  if (rawLogo.trim() && !isValidLogoUrl(rawLogo.trim())) {
    return settingsError(request, 'logo');
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc('erp_set_tenant_branding', {
    p_tenant_id: access.membership.tenantId,
    p_primary_color: primaryColor,
    p_logo_url: logoUrl,
  });
  // Erro genérico de propósito — não distingue "sem permissão" de "formato
  // recusado pela função no banco" de qualquer outra falha da RPC.
  if (error) return settingsError(request, 'permissao');

  return NextResponse.redirect(new URL('/configuracoes/aparencia?sucesso=1', request.url), 303);
}
