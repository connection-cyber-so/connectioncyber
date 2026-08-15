// Adaptado de cc-commerce-studio/features/offer-engine/services/offer.service.ts
// tenant_id no lugar de workspace_id; tabela `mpi_offers`; sem `brand` (brands adiado —
// generateOfferCopy() sempre recebe brand: null, cai no tom "neutro e profissional").
import type { SupabaseClient } from '@supabase/supabase-js';
import { GoogleGenAI } from '@google/genai';
import type { CreateOfferInput, Offer, UpdateOfferInput } from './types';

const genAI = process.env.GEMINI_API_KEY
  ? new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY })
  : null;

export async function listOffers(supabase: SupabaseClient, tenantId: string): Promise<Offer[]> {
  const { data, error } = await supabase
    .from('mpi_offers')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('created_at', { ascending: false });
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getOfferById(supabase: SupabaseClient, id: string): Promise<Offer | null> {
  const { data, error } = await supabase.from('mpi_offers').select('*').eq('id', id).single();
  if (error) throw new Error(error.message);
  return data;
}

export async function createOffer(supabase: SupabaseClient, input: CreateOfferInput & { id: string }): Promise<Offer> {
  const { data, error } = await supabase.from('mpi_offers').insert(input).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

export async function updateOffer(supabase: SupabaseClient, id: string, input: UpdateOfferInput): Promise<Offer> {
  const { data, error } = await supabase.from('mpi_offers').update(input).eq('id', id).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

export async function deleteOffer(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase.from('mpi_offers').delete().eq('id', id);
  if (error) throw new Error(error.message);
}

function buildOfferPrompt(input: { product: { name: string; description: string | null } }): string {
  return `Você é um redator publicitário especializado em ofertas de venda diretas.

Produto: ${input.product.name}
Descrição do produto: ${input.product.description ?? 'Não informada.'}
Tom de voz da marca: neutro e profissional

Escreva uma oferta de venda persuasiva para este produto, respeitando o tom de voz
indicado. Use entre 2 e 4 parágrafos curtos. Termine com uma chamada para ação clara.
Não use listas nem formatação markdown — apenas texto corrido.`;
}

export async function generateOfferCopy(input: { product: { name: string; description: string | null } }): Promise<string> {
  if (!genAI) {
    return (
      `[Rascunho manual — GEMINI_API_KEY não configurada]\n\n` +
      `Escreva aqui a oferta para "${input.product.name}", usando tom de voz neutro e profissional.`
    );
  }

  let response;
  try {
    response = await genAI.models.generateContent({ model: 'gemini-3.1-flash-lite', contents: buildOfferPrompt(input) });
  } catch (error) {
    throw new Error(error instanceof Error ? `Falha ao chamar o provedor de IA: ${error.message}` : 'Falha ao chamar o provedor de IA.');
  }

  const text = response.text;
  if (!text) {
    const blockReason = response.candidates?.[0]?.finishReason;
    throw new Error(blockReason ? `O provedor de IA não retornou texto (motivo: ${blockReason}).` : 'O provedor de IA não retornou nenhum texto.');
  }

  return text;
}
