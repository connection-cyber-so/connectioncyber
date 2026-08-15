// Adaptado de cc-commerce-studio/features/offer-engine/types/offer.types.ts
// workspace_id -> tenant_id; brand_id removido nesta rodada.

export type OfferStatus = 'draft' | 'generated' | 'published';

export interface Offer {
  id: string;
  tenant_id: string;
  product_id: string;
  title: string;
  copy: string | null;
  status: string;
  prompt_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateOfferInput {
  tenant_id: string;
  product_id: string;
  title: string;
  copy?: string;
  status?: OfferStatus;
  prompt_id?: string;
}

export interface UpdateOfferInput {
  title?: string;
  copy?: string;
  status?: OfferStatus;
  prompt_id?: string;
}
