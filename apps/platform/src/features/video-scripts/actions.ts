'use server';

// Adaptado de cc-commerce-studio/features/video-script-engine/actions/*. Mesma correção
// de segurança: tenant_id sempre de requireCurrentTenantId(), nunca de FormData.
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { getOfferById } from '@/features/offers/service';
import { getProductById } from '@/features/products/service';
import { videoScriptSchema } from './validations';
import { createVideoScript, deleteVideoScript, generateVideoScript, updateVideoScript } from './service';
import type { UpdateVideoScriptInput } from './types';

export type CreateVideoScriptActionState = {
  error: string | null;
  success: boolean;
};

export async function createVideoScriptAction(
  _prevState: CreateVideoScriptActionState,
  formData: FormData,
): Promise<CreateVideoScriptActionState> {
  const parsed = videoScriptSchema.safeParse({
    title: formData.get('title') ?? '',
    script: formData.get('script') || undefined,
    status: formData.get('status') || undefined,
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
    await createVideoScript(supabase, { id: crypto.randomUUID(), tenant_id: tenantId, ...parsed.data });
  } catch (error) {
    return { error: error instanceof Error ? error.message : 'Erro ao criar roteiro.', success: false };
  }

  revalidatePath('/video-scripts');
  return { error: null, success: true };
}

export async function updateVideoScriptAction(id: string, input: Pick<UpdateVideoScriptInput, 'title' | 'script'>) {
  const supabase = await createClient();
  const videoScript = await updateVideoScript(supabase, id, input);
  revalidatePath('/video-scripts');
  return videoScript;
}

export async function deleteVideoScriptAction(id: string) {
  const supabase = await createClient();
  await deleteVideoScript(supabase, id);
  revalidatePath('/video-scripts');
}

export async function generateVideoScriptAction(offerId: string): Promise<{ script: string | null; error: string | null }> {
  const supabase = await createClient();

  try {
    // getOfferById e getProductById rodam sob RLS do usuário logado — só
    // enxergam registros do próprio tenant.
    const offer = await getOfferById(supabase, offerId);
    if (!offer) {
      return { script: null, error: 'Oferta não encontrada.' };
    }

    const product = await getProductById(supabase, offer.product_id);
    if (!product) {
      return { script: null, error: 'Produto da oferta não encontrado.' };
    }

    const script = await generateVideoScript({ offer, product });
    return { script, error: null };
  } catch (error) {
    return { script: null, error: error instanceof Error ? error.message : 'Erro ao gerar roteiro.' };
  }
}
