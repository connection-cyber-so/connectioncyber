import { NextResponse, type NextRequest } from 'next/server';
import { isSameOriginRequest } from '@/domain/request-origin';
import { loadPortalAccess } from '@/lib/portal-context';
import { getPortalVisualClient } from '@/features/persistence/writable';

const TYPES = new Set(['main', 'billing', 'shipping', 'service', 'other']);

function backTo(request: NextRequest, partyId: string, code?: string) {
  const url = new URL('/cadastros', request.url);
  url.searchParams.set('party', partyId);
  if (code) url.searchParams.set('erro', code);
  else url.searchParams.set('sucesso', '1');
  return NextResponse.redirect(url, 303);
}

// M21-G3 — mesmo idioma de nova-pessoa/route.ts (party.address.add).
export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }
  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') return NextResponse.redirect(new URL('/login', request.url), 303);

  const formData = await request.formData();
  const partyId = String(formData.get('party_id') ?? '');
  const type = String(formData.get('type') ?? '');
  const postalCode = String(formData.get('postal_code') ?? '').trim();
  const street = String(formData.get('street') ?? '').trim();
  const number = String(formData.get('number') ?? '').trim();
  const complement = String(formData.get('complement') ?? '').trim();
  const district = String(formData.get('district') ?? '').trim();
  const city = String(formData.get('city') ?? '').trim();
  const stateCode = String(formData.get('state_code') ?? '').trim().toUpperCase();
  const isPrimary = formData.get('is_primary') === 'on';

  if (!partyId) return NextResponse.redirect(new URL('/cadastros', request.url), 303);
  if (!TYPES.has(type) || street.length < 2 || city.length < 2) return backTo(request, partyId, 'endereco');

  const client = await getPortalVisualClient();
  const result = await client.execute('party.address.add', {
    partyId, type, postalCode, street, number, complement, district, city, stateCode, isPrimary,
  });
  if (!result.ok) return backTo(request, partyId, 'permissao');
  return backTo(request, partyId);
}
