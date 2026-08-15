'use server';

// Adaptado de cc-commerce-studio/features/diagnostic-engine/actions/*.
//
// Correção de segurança deliberada em relação ao original: lá, tenant_id
// (workspace_id) vinha de `formData.get("workspace_id")` — um campo hidden
// no formulário, ou seja, dado enviado pelo cliente. Aqui, toda action
// deriva o tenant via `requireCurrentTenantId()` (lib/tenant.ts), que lê a
// sessão no servidor — o formulário nunca carrega tenant_id nenhum.
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { requireCurrentTenantId } from '@/lib/tenant';
import { diagnosticSchema } from './validations';
import {
  createDiagnostic,
  deleteDiagnostic,
  generateDiagnosticSummary,
  updateDiagnostic,
} from './service';
import type { DiagnosticAnswers, UpdateDiagnosticInput } from './types';

export type CreateDiagnosticActionState = {
  error: string | null;
  success: boolean;
};

export async function createDiagnosticAction(
  _prevState: CreateDiagnosticActionState,
  formData: FormData,
): Promise<CreateDiagnosticActionState> {
  const parsed = diagnosticSchema.safeParse({
    title: formData.get('title') ?? '',
    canais_digitais: formData.get('canais_digitais') ?? '',
    publico_alvo: formData.get('publico_alvo') ?? '',
    concorrentes: formData.get('concorrentes') || undefined,
    objetivo_principal: formData.get('objetivo_principal') ?? '',
    maturidade_digital: formData.get('maturidade_digital') ?? '',
  });

  if (!parsed.success) {
    return { error: parsed.error.issues[0]?.message ?? 'Dados inválidos.', success: false };
  }

  const projectId = formData.get('project_id');
  const summary = formData.get('summary');

  if (typeof projectId !== 'string' || !projectId) {
    return { error: 'Projeto MPI não identificado.', success: false };
  }

  let tenantId: string;
  try {
    tenantId = await requireCurrentTenantId();
  } catch (error) {
    return { error: error instanceof Error ? error.message : 'Sessão inválida.', success: false };
  }

  const supabase = await createClient();
  const hasSummary = typeof summary === 'string' && summary.length > 0;

  try {
    await createDiagnostic(supabase, {
      id: crypto.randomUUID(),
      tenant_id: tenantId,
      project_id: projectId,
      title: parsed.data.title,
      answers: {
        canais_digitais: parsed.data.canais_digitais,
        publico_alvo: parsed.data.publico_alvo,
        concorrentes: parsed.data.concorrentes ?? null,
        objetivo_principal: parsed.data.objetivo_principal,
        maturidade_digital: parsed.data.maturidade_digital,
      },
      summary: hasSummary ? (summary as string) : undefined,
      status: hasSummary ? 'generated' : 'draft',
      prompt_id: 'diagnostico-digital-ia',
    });
  } catch (error) {
    return { error: error instanceof Error ? error.message : 'Erro ao criar diagnóstico.', success: false };
  }

  revalidatePath('/diagnostics');
  return { error: null, success: true };
}

export async function updateDiagnosticAction(
  id: string,
  input: Pick<UpdateDiagnosticInput, 'title' | 'summary'>,
) {
  const supabase = await createClient();
  const diagnostic = await updateDiagnostic(supabase, id, input);
  revalidatePath('/diagnostics');
  return diagnostic;
}

export async function deleteDiagnosticAction(id: string) {
  const supabase = await createClient();
  await deleteDiagnostic(supabase, id);
  revalidatePath('/diagnostics');
}

export async function generateDiagnosticSummaryAction(
  answers: unknown,
): Promise<{ summary: string | null; error: string | null }> {
  const parsed = diagnosticSchema
    .pick({
      canais_digitais: true,
      publico_alvo: true,
      concorrentes: true,
      objetivo_principal: true,
      maturidade_digital: true,
    })
    .safeParse(answers);

  if (!parsed.success) {
    return { summary: null, error: parsed.error.issues[0]?.message ?? 'Dados inválidos.' };
  }

  try {
    const summary = await generateDiagnosticSummary({
      canais_digitais: parsed.data.canais_digitais,
      publico_alvo: parsed.data.publico_alvo,
      concorrentes: parsed.data.concorrentes ?? null,
      objetivo_principal: parsed.data.objetivo_principal as DiagnosticAnswers['objetivo_principal'],
      maturidade_digital: parsed.data.maturidade_digital as DiagnosticAnswers['maturidade_digital'],
    });
    return { summary, error: null };
  } catch (error) {
    return { summary: null, error: error instanceof Error ? error.message : 'Erro ao gerar diagnóstico.' };
  }
}
