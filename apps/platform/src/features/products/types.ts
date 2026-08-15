// Adaptado de cc-commerce-studio/features/products/types/product.types.ts
// workspace_id -> tenant_id; brand_id removido nesta rodada (brands ainda não migrado).

export type ProductStatus = 'draft' | 'active' | 'archived';

export interface MpiProduct {
  id: string;
  tenant_id: string;
  name: string;
  description: string | null;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface CreateProductInput {
  tenant_id: string;
  name: string;
  description?: string;
  status?: ProductStatus;
}

export interface UpdateProductInput {
  name?: string;
  description?: string;
  status?: ProductStatus;
}
