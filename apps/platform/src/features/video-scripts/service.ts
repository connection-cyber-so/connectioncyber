// Adaptado de cc-commerce-studio/features/video-script-engine/services/video-script.service.ts
// tenant_id no lugar de workspace_id; tabela `mpi_video_scripts`; sem `brand`.
import type { SupabaseClient } from '@supabase/supabase-js';
import { GoogleGenAI } from '@google/genai';
import type { CreateVideoScriptInput, UpdateVideoScriptInput, VideoScript } from './types';

const genAI = process.env.GEMINI_API_KEY
  ? new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY })
  : null;

export async function listVideoScripts(supabase: SupabaseClient, tenantId: string): Promise<VideoScript[]> {
  const { data, error } = await supabase
    .from('mpi_video_scripts')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('created_at', { ascending: false });
  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getVideoScriptById(supabase: SupabaseClient, id: string): Promise<VideoScript | null> {
  const { data, error } = await supabase.from('mpi_video_scripts').select('*').eq('id', id).single();
  if (error) throw new Error(error.message);
  return data;
}

export async function createVideoScript(
  supabase: SupabaseClient,
  input: CreateVideoScriptInput & { id: string },
): Promise<VideoScript> {
  const { data, error } = await supabase.from('mpi_video_scripts').insert(input).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

export async function updateVideoScript(
  supabase: SupabaseClient,
  id: string,
  input: UpdateVideoScriptInput,
): Promise<VideoScript> {
  const { data, error } = await supabase.from('mpi_video_scripts').update(input).eq('id', id).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

export async function deleteVideoScript(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase.from('mpi_video_scripts').delete().eq('id', id);
  if (error) throw new Error(error.message);
}

function buildVideoScriptPrompt(input: {
  offer: { title: string; copy: string | null };
  product: { name: string };
}): string {
  return `Você é um roteirista especializado em vídeos de venda diretos (estilo VSL — Video Sales Letter).

Produto: ${input.product.name}
Título da oferta: ${input.offer.title}
Copy da oferta: ${input.offer.copy ?? 'Não informada.'}
Tom de voz da marca: neutro e profissional

Escreva um roteiro de vídeo curto, dividido em cenas nomeadas (Gancho, Problema, Solução,
Prova, Chamada para ação), respeitando o tom de voz indicado. Cada cena deve ter 1 a 3
frases de fala. Não use markdown nem listas numeradas — apenas texto corrido, com o nome
de cada cena seguido de dois pontos e a fala correspondente.`;
}

export async function generateVideoScript(input: {
  offer: { title: string; copy: string | null };
  product: { name: string };
}): Promise<string> {
  if (!genAI) {
    return (
      `[Rascunho manual — GEMINI_API_KEY não configurada]\n\n` +
      `Escreva aqui o roteiro de vídeo para a oferta "${input.offer.title}".`
    );
  }

  let response;
  try {
    response = await genAI.models.generateContent({ model: 'gemini-3.1-flash-lite', contents: buildVideoScriptPrompt(input) });
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
