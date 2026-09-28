import type { NextRequest } from 'next/server';
import { runAcademyAdminAction } from '@/features/academy/admin-action';

export async function POST(request: NextRequest) {
  return runAcademyAdminAction(request, {
    action: 'publish_course',
    fields: ['status'],
  });
}
