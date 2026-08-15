// Adaptado de cc-commerce-studio/features/diagnostic-engine/services/diagnostic.service.ts
// Mudanças em relação ao original:
//   - workspace_id -> tenant_id; tabelas `projects`/`diagnostics` -> `mpi_projects`/`mpi_diagnostics`
//   - nenhuma função aqui aceita tenant_id vindo de fora sem checar sessão — quem chama
//     (actions.ts) sempre deriva o tenant via lib/tenant.ts antes de chegar aqui.
import type { SupabaseClient } from '@supabase/supabase-js';
import { GoogleGenAI } from '@google/genai';
import type {
  CreateDiagnosticInput,
  Diagnostic,
  DiagnosticAnswers,
  MpiProject,
  UpdateDiagnosticInput,
} from './types';

// Cliente do Gemini só existe se GEMINI_API_KEY estiver configurada — sem
// isso, generateDiagnosticSummary() cai num rascunho manual (ver abaixo),
// nunca quebra a tela por falta de chave de IA.
const genAI = process.env.GEMINI_API_KEY
  ? new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY })
  : null;

const AVAILABLE_MODULES = [
  'Assessoria Técnica (consultoria e planejamento tecnológico)',
  'Desenvolvimento de Sistemas (sistemas, apps, portais sob medida)',
  'Treinamento Tecnológico (cursos e capacitação)',
  'Suporte Tecnológico Global (atendimento e monitoramento contínuo)',
];

export async function listDiagnostics(
  supabase: SupabaseClient,
  tenantId: string,
): Promise<Diagnostic[]> {
  const { data, error } = await supabase
    .from('mpi_diagnostics')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('created_at', { ascending: false });

  if (error) throw new Error(error.message);
  return data ?? [];
}

export async function getDiagnosticById(
  supabase: SupabaseClient,
  id: string,
): Promise<Diagnostic | null> {
  const { data, error } = await supabase.from('mpi_diagnostics').select('*').eq('id', id).single();
  if (error) throw new Error(error.message);
  return data;
}

export async function createDiagnostic(
  supabase: SupabaseClient,
  input: CreateDiagnosticInput & { id: string },
): Promise<Diagnostic> {
  const { data, error } = await supabase.from('mpi_diagnostics').insert(input).select('*').single();
  if (error) throw new Error(error.message);
  return data;
}

export async function updateDiagnostic(
  supabase: SupabaseClient,
  id: string,
  input: UpdateDiagnosticInput,
): Promise<Diagnostic> {
  const { data, error } = await supabase
    .from('mpi_diagnostics')
    .update(input)
    .eq('id', id)
    .select('*')
    .single();
  if (error) throw new Error(error.message);
  return data;
}

export async function deleteDiagnostic(supabase: SupabaseClient, id: string): Promise<void> {
  const { error } = await supabase.from('mpi_diagnostics').delete().eq('id', id);
  if (error) throw new Error(error.message);
}

/** Um tenant tem no máximo 1 projeto MPI — reaproveita o mais antigo se já existir, nunca duplica. */
export async function getOrCreateMpiProject(
  supabase: SupabaseClient,
  tenantId: string,
): Promise<MpiProject> {
  const { data: existing, error: selectError } = await supabase
    .from('mpi_projects')
    .select('*')
    .eq('tenant_id', tenantId)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle();

  if (selectError) throw new Error(selectError.message);
  if (existing) return existing;

  const { data: created, error: insertError } = await supabase
    .from('mpi_projects')
    .insert({
      id: crypto.randomUUID(),
      tenant_id: tenantId,
      name: 'Diagnóstico MPI',
      description: 'Projeto criado automaticamente pelo módulo Diagnóstico Digital.',
      status: 'draft',
    })
    .select('*')
    .single();

  if (insertError) throw new Error(insertError.message);
  return created;
}

function buildDiagnosticPrompt(answers: DiagnosticAnswers): string {
  return `Você é um consultor de marketing digital especializado em diagnosticar a presença online de pequenas e médias empresas.

Canais digitais atuais: ${answers.canais_digitais}
Público-alvo declarado: ${answers.publico_alvo}
Concorrentes diretos: ${answers.concorrentes ?? 'Não informado.'}
Objetivo principal: ${answers.objetivo_principal}
Maturidade digital autodeclarada: ${answers.maturidade_digital}

Serviços disponíveis na ConnectionCyber hoje:
${AVAILABLE_MODULES.map((m) => `- ${m}`).join('\n')}

Escreva uma síntese curta (2 a 3 parágrafos) do diagnóstico digital desta empresa,
e termine recomendando explicitamente qual dos serviços acima ela deveria contratar
primeiro, e por quê. Não use listas nem formatação markdown — apenas texto corrido.`;
}

export async function generateDiagnosticSummary(answers: DiagnosticAnswers): Promise<string> {
  if (!genAI) {
    return (
      `[Rascunho manual — GEMINI_API_KEY não configurada]\n\n` +
      `Escreva aqui a síntese do diagnóstico para um cliente com maturidade digital ` +
      `"${answers.maturidade_digital}" e objetivo principal "${answers.objetivo_principal}".`
    );
  }

  let response;
  try {
    response = await genAI.models.generateContent({
      model: 'gemini-3.1-flash-lite',
      contents: buildDiagnosticPrompt(answers),
    });
  } catch (error) {
    throw new Error(
      error instanceof Error ? `Falha ao chamar o provedor de IA: ${error.message}` : 'Falha ao chamar o provedor de IA.',
    );
  }

  const text = response.text;
  if (!text) {
    const blockReason = response.candidates?.[0]?.finishReason;
    throw new Error(
      blockReason
        ? `O provedor de IA não retornou texto (motivo: ${blockReason}).`
        : 'O provedor de IA não retornou nenhum texto.',
    );
  }

  return text;
}
