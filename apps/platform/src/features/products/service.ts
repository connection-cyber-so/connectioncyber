// Adaptado de cc-commerce-studio/features/products/services/product.service.ts
// workspace_id -> tenant_id; tabela `products` -> `mpi_products` (evita colisão com o
// catálogo de cursos/produtos da própria ConnectionCyber, já existente).
import type { SupabaseClient } from '@supabase/supabase-js';
import type { CreateProductInput, MpiProduct, UpdateProductInput } from './types';

export async function listProducts(supabase: SupabaseClient, tenantId: string): Promise<MpiProduct[]> {
  const { data, error } = await supabase
    .from('mpi_products')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('created_at', { ascending: false });
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getProductById(supabase: SupabaseClient, id: string): Promise<MpiProduct | null> {
  const { data, error } = await supabase.from('mpi_products').select('*').eq('id', id).single();
  if (error) throw new Error(error.message);
  return data;
}

export async function createProduct(
  supabase: SupabaseClient,
  input: CreateProductInput & { id: string },
): Promise<MpiProduct> {
  const { data, error } = await supabase.from('mpi_products').insert(input).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

export async function updateProduct(
  supabase: SupabaseClient,
  id: string,
  input: UpdateProductInput,
): Promise<MpiProduct> {
  const { data, error } = await supabase.from('mpi_products').update(input).eq('id', id).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

export async function deleteProduct(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase.from('mpi_products').delete().eq('id', id);
  if (error) throw new Error(error.message);
}
