export type CatalogType = 'course' | 'product';

export interface CheckoutItemInput {
  id: string;
  type: CatalogType;
  quantity: number;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_ITEMS = 20;
const MAX_QUANTITY = 10;
const ALLOWED_ITEM_KEYS = new Set(['id', 'type', 'quantity']);

export function parseCheckoutItems(value: unknown): CheckoutItemInput[] | null {
  if (!Array.isArray(value) || value.length === 0 || value.length > MAX_ITEMS) return null;

  const items: CheckoutItemInput[] = [];
  const uniqueItems = new Set<string>();

  for (const candidate of value) {
    if (!candidate || typeof candidate !== 'object') return null;
    const item = candidate as Record<string, unknown>;
    if (Object.keys(item).some((key) => !ALLOWED_ITEM_KEYS.has(key))) return null;
    if (item.type !== 'course' && item.type !== 'product') return null;
    if (typeof item.id !== 'string' || !UUID_PATTERN.test(item.id)) return null;
    if (!Number.isInteger(item.quantity) || Number(item.quantity) < 1 || Number(item.quantity) > MAX_QUANTITY) {
      return null;
    }

    const uniqueKey = `${item.type}:${item.id}`;
    if (uniqueItems.has(uniqueKey)) return null;
    uniqueItems.add(uniqueKey);
    items.push({ id: item.id, type: item.type, quantity: Number(item.quantity) });
  }

  return items;
}
