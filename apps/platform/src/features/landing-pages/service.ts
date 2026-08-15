// Adaptado de cc-commerce-studio/features/landing-pages/services/landing-page.service.ts
// tenant_id no lugar de workspace_id; tabela `mpi_landing_pages`.
import type { SupabaseClient } from '@supabase/supabase-js';
import type { CreateLandingPageInput, LandingPage, UpdateLandingPageInput } from './types';

export async function listLandingPages(supabase: SupabaseClient, tenantId: string): Promise<LandingPage[]> {
  const { data, error } = await supabase
    .from('mpi_landing_pages')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('created_at', { ascending: false });
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getLandingPageById(supabase: SupabaseClient, id: string): Promise<LandingPage | null> {
  const { data, error } = await supabase.from('mpi_landing_pages').select('*').eq('id', id).single();
  if (error) throw new Error(error.message);
  return data;
}

export async function createLandingPage(
  supabase: SupabaseClient,
  input: CreateLandingPageInput & { id: string },
): Promise<LandingPage> {
  const { data, error } = await supabase.from('mpi_landing_pages').insert(input).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

export async function updateLandingPage(
  supabase: SupabaseClient,
  id: string,
  input: UpdateLandingPageInput,
): Promise<LandingPage> {
  const { data, error } = await supabase.from('mpi_landing_pages').update(input).eq('id', id).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

export async function deleteLandingPage(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase.from('mpi_landing_pages').delete().eq('id', id);
  if (error) throw new Error(error.message);
}
