'use server';

import { revalidatePath } from 'next/cache';
import { visualPersistenceClient } from '@/features/persistence/selected';
import { itemCommercialSchema, itemFiscalSchema, itemSchema, unitSchema } from './validations';

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

// M20-G1/G3 — aba Fiscal do item, sempre sobre um item já criado.
export async function setItemFiscalAction(_: CatalogState, f: FormData): Promise<CatalogState> {
  const p = itemFiscalSchema.safeParse({ item_id: f.get('item_id'), ncm: f.get('ncm'), cest: f.get('cest') || undefined, origin: f.get('origin'), tax_code_kind: f.get('tax_code_kind'), tax_code: f.get('tax_code'), icms_rate: f.get('icms_rate') || 0, icms_base_percent: f.get('icms_base_percent') || 100, ipi_rate: f.get('ipi_rate') || 0, gross_weight: f.get('gross_weight') || undefined, net_weight: f.get('net_weight') || undefined });
  if (!p.success) return { error: p.error.issues[0]?.message ?? 'Dado fiscal inválido.', success: false };
  try {
    const result = await visualPersistenceClient.execute('catalog.item.fiscal.set', { itemId: p.data.item_id, ncm: p.data.ncm, cest: p.data.cest ?? '', origin: p.data.origin, taxCodeKind: p.data.tax_code_kind, taxCode: p.data.tax_code, icmsRate: p.data.icms_rate, icmsBasePercent: p.data.icms_base_percent, ipiRate: p.data.ipi_rate, grossWeight: p.data.gross_weight ?? null, netWeight: p.data.net_weight ?? null });
    if (!result.ok) return { error: result.error.message, success: false };
    revalidatePath('/catalogo');
    return { error: null, success: true };
  } catch {
    return { error: 'Não foi possível salvar o dado fiscal nesta sessão.', success: false };
  }
}

// M20-G1/G3 — aba Comercial do item.
export async function setItemCommercialAction(_: CatalogState, f: FormData): Promise<CatalogState> {
  const p = itemCommercialSchema.safeParse({ item_id: f.get('item_id'), cost_price: f.get('cost_price') || 0, margin_percent: f.get('margin_percent') || 0, suggested_sale_price: f.get('suggested_sale_price') || undefined, min_stock_quantity: f.get('min_stock_quantity') || 0, reorder_point: f.get('reorder_point') || undefined });
  if (!p.success) return { error: p.error.issues[0]?.message ?? 'Dado comercial inválido.', success: false };
  try {
    const result = await visualPersistenceClient.execute('catalog.item.commercial.set', { itemId: p.data.item_id, costPrice: p.data.cost_price, marginPercent: p.data.margin_percent, suggestedSalePrice: p.data.suggested_sale_price ?? null, minStockQuantity: p.data.min_stock_quantity, reorderPoint: p.data.reorder_point ?? null });
    if (!result.ok) return { error: result.error.message, success: false };
    revalidatePath('/catalogo');
    return { error: null, success: true };
  } catch {
    return { error: 'Não foi possível salvar o dado comercial nesta sessão.', success: false };
  }
}
