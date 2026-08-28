'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { itemSchema, unitSchema } from './validations';
import { createCatalogItem, createUnit } from './service';

export type CatalogState = { error: string | null; success: boolean };

export async function createUnitAction(_: CatalogState, f: FormData): Promise<CatalogState> {
  const p = unitSchema.safeParse({
    code: f.get('code'),
    name: f.get('name'),
    dimension: f.get('dimension'),
    decimal_scale: f.get('decimal_scale')
  });

  if (!p.success) return { error: p.error.issues[0]?.message ?? 'Unidade inválida.', success: false };

  try {
    await createUnit(await createClient(), {
      tenant_id: await requireCurrentTenantId(),
      ...p.data
    });
    revalidatePath('/catalogo');
    return { error: null, success: true };
  } catch (e) {
    return { error: e instanceof Error ? e.message : 'Erro ao criar unidade.', success: false };
  }
}

export async function createItemAction(_: CatalogState, f: FormData): Promise<CatalogState> {
  const p = itemSchema.safeParse({
    code: f.get('code'),
    name: f.get('name'),
    description: f.get('description') || undefined,
    kind: f.get('kind'),
    base_unit_id: f.get('base_unit_id'),
    track_inventory: f.get('track_inventory') === 'on',
    allows_fraction: f.get('allows_fraction') === 'on'
  });

  if (!p.success) return { error: p.error.issues[0]?.message ?? 'Item inválido.', success: false };

  try {
    await createCatalogItem(await createClient(), {
      tenant_id: await requireCurrentTenantId(),
      ...p.data
    });

    revalidatePath('/catalogo');
    return { error: null, success: true };
  } catch (e) {
    return { error: e instanceof Error ? e.message : 'Erro ao criar item.', success: false };
  }
}
