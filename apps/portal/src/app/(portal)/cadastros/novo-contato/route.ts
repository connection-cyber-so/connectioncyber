import { NextResponse, type NextRequest } from 'next/server';
import { onlyDigits } from '@/domain/br-documents';
import { isSameOriginRequest } from '@/domain/request-origin';
import { loadPortalAccess } from '@/lib/portal-context';
import { getPortalVisualClient } from '@/features/persistence/writable';

const TYPES = new Set(['email', 'phone', 'mobile', 'whatsapp', 'website', 'other']);
const PHONE_TYPES = new Set(['phone', 'mobile', 'whatsapp']);

function backTo(request: NextRequest, partyId: string, code?: string) {
  const url = new URL('/cadastros', request.url);
  url.searchParams.set('party', partyId);
  if (code) url.searchParams.set('erro', code);
  else url.searchParams.set('sucesso', '1');
  return NextResponse.redirect(url, 303);
}

// M21-G3 — mesmo idioma de nova-pessoa/route.ts (party.contact.add).
export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }
  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') return NextResponse.redirect(new URL('/login', request.url), 303);

  const formData = await request.formData();
  const partyId = String(formData.get('party_id') ?? '');
  const type = String(formData.get('type') ?? '');
  const rawValue = String(formData.get('value') ?? '').trim();
  const value = PHONE_TYPES.has(type) ? onlyDigits(rawValue) : rawValue;
  const isPrimary = formData.get('is_primary') === 'on';

  if (!partyId) return NextResponse.redirect(new URL('/cadastros', request.url), 303);
  if (!TYPES.has(type) || value.length < 3) return backTo(request, partyId, 'contato');

  const client = await getPortalVisualClient();
  const result = await client.execute('party.contact.add', { partyId, type, value, isPrimary });
  if (!result.ok) return backTo(request, partyId, 'permissao');
  return backTo(request, partyId);
}
