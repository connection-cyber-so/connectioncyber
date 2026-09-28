import type { NextRequest } from 'next/server';
import { runAcademyFormAction } from '@/features/academy/form-action';

export async function POST(request: NextRequest) {
  return runAcademyFormAction(request, {
    action: 'complete_module',
    requireModule: true,
    redirectTo: (courseId) => (courseId ? `/academia/${courseId}` : '/academia'),
  });
}
