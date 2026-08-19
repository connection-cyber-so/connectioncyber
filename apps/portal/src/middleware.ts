import type { NextRequest } from 'next/server';
import { updatePortalSession } from '@/lib/supabase/middleware';

export function middleware(request: NextRequest) {
  return updatePortalSession(request);
}

export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
