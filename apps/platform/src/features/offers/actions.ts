'use server';

// Adaptado de cc-commerce-studio/features/offer-engine/actions/*. Mesma correção de
// segurança: tenant_id sempre de requireCurrentTenantId(), nunca de FormData.
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { getProductById } from '@/features/products/service';
import { offerSchema } from './validations';
import { createOffer, deleteOffer, generateOfferCopy, updateOffer } from './service';
import type { UpdateOfferInput } from './types';

export type CreateOfferActionState = {
  error: string | null;
  success: boolean;
};

export async function createOfferAction(
  _prevState: CreateOfferActionState,
  formData: FormData,
): Promise<CreateOfferActionState> {
  const parsed = offerSchema.safeParse({
    title: formData.get('title') ?? '',
    copy: formData.get('copy') || undefined,
    status: formData.get('status') || undefined,
    product_id: formData.get('product_id') ?? '',
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
  const hasCopy = typeof parsed.data.copy === 'string' && parsed.data.copy.length > 0;

  try {
    await createOffer(supabase, {
      id: crypto.randomUUID(),
      tenant_id: tenantId,
      product_id: parsed.data.product_id,
      title: parsed.data.title,
      copy: hasCopy ? parsed.data.copy : undefined,
      status: hasCopy ? 'generated' : 'draft',
      prompt_id: 'catalogo-produtos-ofertas-ia',
    });
  } catch (error) {
    return { error: error instanceof Error ? error.message : 'Erro ao criar oferta.', success: false };
  }

  revalidatePath('/offers');
  return { error: null, success: true };
}

export async function updateOfferAction(id: string, input: Pick<UpdateOfferInput, 'title' | 'copy'>) {
  const supabase = await createClient();
  const offer = await updateOffer(supabase, id, input);
  revalidatePath('/offers');
  return offer;
}

export async function deleteOfferAction(id: string) {
  const supabase = await createClient();
  await deleteOffer(supabase, id);
  revalidatePath('/offers');
}

export async function generateOfferCopyAction(productId: string): Promise<{ copy: string | null; error: string | null }> {
  const supabase = await createClient();

  try {
    // getProductById roda sob RLS do usuário logado — se o produto não for
    // do tenant da sessão, a query simplesmente não retorna nada.
    const product = await getProductById(supabase, productId);
    if (!product) {
      return { copy: null, error: 'Produto não encontrado.' };
    }

    const copy = await generateOfferCopy({ product });
    return { copy, error: null };
  } catch (error) {
    return { copy: null, error: error instanceof Error ? error.message : 'Erro ao gerar copy.' };
  }
}
