import { NextResponse, type NextRequest } from 'next/server';
import { isValidTaxId, onlyDigits } from '@/domain/br-documents';
import { isSameOriginRequest } from '@/domain/request-origin';
import { loadPortalAccess } from '@/lib/portal-context';
import { getPortalVisualClient } from '@/features/persistence/writable';

const ROLES = new Set(['customer', 'supplier', 'employee', 'buyer', 'sales_rep', 'technician', 'carrier', 'other']);
const KINDS = new Set(['person', 'organization']);

function cadastroError(request: NextRequest, code: string) {
  const url = new URL('/cadastros', request.url);
  url.searchParams.set('erro', code);
  return NextResponse.redirect(url, 303);
}

// M21-G2 (Trilha B) — mesmo idioma de apps/portal/src/app/auth/set-branding/route.ts:
// formulário sem JS, same-origin obrigatório, tenant sempre vem da membership autorizada
// (nunca de input do form). A diferença é que aqui a escrita passa pelo comando idempotente
// real do M17/M20 (erp_command_create_party_v1), não uma RPC simples — getPortalVisualClient()
// cuida do request_id e do hash do payload.
export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }

  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') {
    return NextResponse.redirect(new URL('/login', request.url), 303);
  }

  const formData = await request.formData();
  const kind = String(formData.get('kind') ?? '');
  const role = String(formData.get('role') ?? '');
  const legalName = String(formData.get('legal_name') ?? '').trim();
  const tradeName = String(formData.get('trade_name') ?? '').trim();
  const taxId = onlyDigits(String(formData.get('tax_id') ?? ''));

  if (!KINDS.has(kind) || !ROLES.has(role)) return cadastroError(request, 'dados');
  if (legalName.length < 2 || legalName.length > 180) return cadastroError(request, 'nome');
  if (taxId && !isValidTaxId(taxId)) return cadastroError(request, 'documento');

  const client = await getPortalVisualClient();
  const result = await client.execute('party.create', {
    kind,
    legalName,
    tradeName,
    taxId,
    role,
  });

  if (!result.ok) return cadastroError(request, 'permissao');

  return NextResponse.redirect(new URL('/cadastros?sucesso=1', request.url), 303);
}
