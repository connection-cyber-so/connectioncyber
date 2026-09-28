import { NextResponse, type NextRequest } from 'next/server';
import { isSameOriginRequest } from '@/domain/request-origin';
import { loadPortalAccess } from '@/lib/portal-context';
import { getPortalVisualClient } from '@/features/persistence/writable';

const TYPES = new Set(['cpf', 'cnpj', 'rg', 'passport', 'other']);

function backTo(request: NextRequest, partyId: string, code?: string) {
  const url = new URL('/cadastros', request.url);
  url.searchParams.set('party', partyId);
  if (code) url.searchParams.set('erro', code);
  else url.searchParams.set('sucesso', '1');
  return NextResponse.redirect(url, 303);
}

// M21-G3 — mesmo idioma de nova-pessoa/route.ts: same-origin, tenant nunca de
// formulário, escrita pelo comando idempotente real (party.document.add).
export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }
  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') return NextResponse.redirect(new URL('/login', request.url), 303);

  const formData = await request.formData();
  const partyId = String(formData.get('party_id') ?? '');
  const type = String(formData.get('type') ?? '');
  const number = String(formData.get('number') ?? '').trim();
  const issuer = String(formData.get('issuer') ?? '').trim();

  if (!partyId) return NextResponse.redirect(new URL('/cadastros', request.url), 303);
  if (!TYPES.has(type) || number.length < 3) return backTo(request, partyId, 'documento');

  const client = await getPortalVisualClient();
  const result = await client.execute('party.document.add', { partyId, type, number, issuer });
  if (!result.ok) return backTo(request, partyId, 'permissao');
  return backTo(request, partyId);
}
