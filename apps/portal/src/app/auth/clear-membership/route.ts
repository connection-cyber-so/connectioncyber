import { NextResponse, type NextRequest } from 'next/server';
import { isSameOriginRequest } from '@/domain/request-origin';
import { ACTIVE_MEMBERSHIP_COOKIE } from '@/lib/portal-context';

export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }

  const response = NextResponse.redirect(new URL('/selecionar-empresa', request.url), 303);
  response.cookies.set(ACTIVE_MEMBERSHIP_COOKIE, '', {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: 0,
  });
  return response;
}
