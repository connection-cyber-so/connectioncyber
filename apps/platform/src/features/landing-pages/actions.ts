'use server';

// Adaptado de cc-commerce-studio/features/landing-pages/actions/*. Mesma correção de
// segurança: tenant_id sempre de requireCurrentTenantId(), nunca de FormData.
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { landingPageSchema } from './validations';
import { createLandingPage, deleteLandingPage, updateLandingPage } from './service';

export type CreateLandingPageActionState = {
  error: string | null;
  success: boolean;
};

export async function createLandingPageAction(
  _prevState: CreateLandingPageActionState,
  formData: FormData,
): Promise<CreateLandingPageActionState> {
  const parsed = landingPageSchema.safeParse({
    title: formData.get('title') ?? '',
    slug: formData.get('slug') ?? '',
    content: formData.get('content') || undefined,
    offer_id: formData.get('offer_id') ?? '',
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? 'Dados inválidos.', success: false };
  }

  let tenantId: string;
  try {
    tenantId = await requireCurrentTenantId();
  } catch (error) {
    return { error: error instanceof Error ? error.message : 'Sessão inválida.', success: false };
  }

  const supabase = await createClient();

  try {
    await createLandingPage(supabase, { id: crypto.randomUUID(), tenant_id: tenantId, ...parsed.data });
  } catch (error) {
    // slug é único global — o erro mais comum aqui é conflito de slug (23505).
    const message =
      error instanceof Error && error.message.includes('duplicate key')
        ? 'Esse slug já está em uso por outra página. Escolha outro.'
        : error instanceof Error
          ? error.message
          : 'Erro ao criar landing page.';
    return { error: message, success: false };
  }

  revalidatePath('/landing-pages');
  return { error: null, success: true };
}

export async function updateLandingPageAction(id: string, input: { title?: string; content?: string }) {
  const supabase = await createClient();
  const landingPage = await updateLandingPage(supabase, id, input);
  revalidatePath('/landing-pages');
  return landingPage;
}

export async function togglePublishAction(id: string, publish: boolean) {
  const supabase = await createClient();
  const landingPage = await updateLandingPage(supabase, id, { status: publish ? 'published' : 'draft' });
  revalidatePath('/landing-pages');
  return landingPage;
}

export async function deleteLandingPageAction(id: string) {
  const supabase = await createClient();
  await deleteLandingPage(supabase, id);
  revalidatePath('/landing-pages');
}
