// Adaptado de cc-commerce-studio/features/video-script-engine/types/video-script.types.ts
// workspace_id -> tenant_id; brand removido nesta rodada.

export type VideoScriptStatus = 'draft' | 'generated';

export interface VideoScript {
  id: string;
  tenant_id: string;
  offer_id: string;
  title: string;
  script: string | null;
  status: string;
  prompt_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateVideoScriptInput {
  tenant_id: string;
  offer_id: string;
  title: string;
  script?: string;
  status?: VideoScriptStatus;
  prompt_id?: string;
}

export interface UpdateVideoScriptInput {
  title?: string;
  script?: string;
  status?: VideoScriptStatus;
  prompt_id?: string;
}
