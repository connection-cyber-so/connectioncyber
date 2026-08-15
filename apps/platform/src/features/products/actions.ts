'use server';

// Adaptado de cc-commerce-studio/features/products/actions/*. Mesma correção de
// segurança do módulo diagnostics: tenant_id nunca vem de FormData, sempre de
// requireCurrentTenantId() (lib/tenant.ts).
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { productSchema } from './validations';
import { createProduct, deleteProduct, updateProduct } from './service';
import type { UpdateProductInput } from './types';

export type CreateProductActionState = {
  error: string | null;
  success: boolean;
};

export async function createProductAction(
  _prevState: CreateProductActionState,
  formData: FormData,
): Promise<CreateProductActionState> {
  const parsed = productSchema.safeParse({
    name: formData.get('name') ?? '',
    description: formData.get('description') || undefined,
    status: formData.get('status') || undefined,
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
    await createProduct(supabase, { id: crypto.randomUUID(), tenant_id: tenantId, ...parsed.data });
  } catch (error) {
    return { error: error instanceof Error ? error.message : 'Erro ao criar produto.', success: false };
  }

  revalidatePath('/products');
  return { error: null, success: true };
}

export async function updateProductAction(id: string, input: UpdateProductInput) {
  const parsedInput = productSchema.partial().parse(input);
  const supabase = await createClient();
  const product = await updateProduct(supabase, id, parsedInput);
  revalidatePath('/products');
  return product;
}

export async function deleteProductAction(id: string) {
  const supabase = await createClient();
  await deleteProduct(supabase, id);
  revalidatePath('/products');
}
