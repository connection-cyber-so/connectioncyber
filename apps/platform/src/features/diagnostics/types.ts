// Adaptado de cc-commerce-studio/features/diagnostic-engine/types/diagnostic.types.ts
// workspace_id -> tenant_id (ver docs/migracao-diagnostico-digital-cc-commerce-studio).

export type DiagnosticStatus = 'draft' | 'generated';

export type DiagnosticObjective =
  | 'aumentar_vendas'
  | 'gerar_leads'
  | 'construir_marca'
  | 'outro';

export type DiagnosticMaturity = 'iniciante' | 'intermediario' | 'avancado';

export interface DiagnosticAnswers {
  canais_digitais: string;
  publico_alvo: string;
  concorrentes: string | null;
  objetivo_principal: DiagnosticObjective;
  maturidade_digital: DiagnosticMaturity;
}

export interface Diagnostic {
  id: string;
  tenant_id: string;
  project_id: string;
  title: string;
  answers: DiagnosticAnswers;
  summary: string | null;
  status: string;
  prompt_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateDiagnosticInput {
  tenant_id: string;
  project_id: string;
  title: string;
  answers: DiagnosticAnswers;
  summary?: string;
  status?: DiagnosticStatus;
  prompt_id?: string;
}

export interface UpdateDiagnosticInput {
  title?: string;
  answers?: DiagnosticAnswers;
  summary?: string;
  status?: DiagnosticStatus;
  prompt_id?: string;
}

/** Ciclo/projeto MPI do tenant — reaproveitado de forma análoga ao `projects` órfão do código original (lá "workspace"; aqui, 1 por tenant). */
export interface MpiProject {
  id: string;
  tenant_id: string;
  name: string;
  description: string | null;
  status: string;
  created_at: string;
  updated_at: string;
}
