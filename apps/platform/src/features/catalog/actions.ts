'use server';

import { revalidatePath } from 'next/cache';
import { visualPersistenceClient } from '@/features/persistence/selected';
import { itemSchema, unitSchema } from './validations';

export type CatalogState = { error: string | null; success: boolean };

export async function createUnitAction(_: CatalogState, f: FormData): Promise<CatalogState> {
  const p = unitSchema.safeParse({
    code: f.get('code'),
    name: f.get('name'),
    dimension: f.get('dimension'),
    decimal_scale: f.get('decimal_scale')
  });

  if (!p.success) return { error: p.error.issues[0]?.message ?? 'Unidade inválida.', success: false };

  return { error: `Unidades permanecem fixas no transporte local (${p.data.code}).`, success: false };
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
    const result = await visualPersistenceClient.execute('catalog.item.create', { code: p.data.code, name: p.data.name, description: p.data.description ?? '', kind: p.data.kind, baseUnitId: p.data.base_unit_id, trackInventory: p.data.track_inventory, allowsFraction: p.data.allows_fraction });
    if (!result.ok) return { error: result.error.message, success: false };
    revalidatePath('/catalogo');
    return { error: null, success: true };
  } catch {
    return { error: 'Não foi possível criar o item nesta sessão.', success: false };
  }
}
