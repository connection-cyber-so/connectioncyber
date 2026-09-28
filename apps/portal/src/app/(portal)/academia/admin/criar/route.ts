import type { NextRequest } from 'next/server';
import { runAcademyAdminAction } from '@/features/academy/admin-action';

export async function POST(request: NextRequest) {
  return runAcademyAdminAction(request, {
    action: 'create_course',
    courseRequired: false,
    fields: ['titulo', 'descricao', 'categoria', 'escopo', 'publico', 'alvo_sistema', 'alvo_vertical'],
    emptyOk: ['alvo_sistema', 'alvo_vertical'],
  });
}
