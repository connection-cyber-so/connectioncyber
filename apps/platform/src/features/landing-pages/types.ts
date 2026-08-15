// Adaptado de cc-commerce-studio/features/landing-pages/types/landing-page.types.ts
// workspace_id -> tenant_id. slug continua único global (ver migration 0012).

export type LandingPageStatus = 'draft' | 'published';

export interface LandingPage {
  id: string;
  tenant_id: string;
  offer_id: string;
  title: string;
  slug: string;
  content: string | null;
  status: string;
  created_at: string;
  updated_at: string;
}

export interface CreateLandingPageInput {
  tenant_id: string;
  offer_id: string;
  title: string;
  slug: string;
  content?: string;
  status?: LandingPageStatus;
}

export interface UpdateLandingPageInput {
  title?: string;
  slug?: string;
  content?: string;
  status?: LandingPageStatus;
}
