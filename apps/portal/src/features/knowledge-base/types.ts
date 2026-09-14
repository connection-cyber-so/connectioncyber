export const kinds = [
  'prompt',
  'link',
  'video',
  'script',
  'code',
  'migration',
  'study',
  'file',
] as const;
export type Kind = (typeof kinds)[number];
export const gates = [
  'M0 Entrada',
  'M1 Classificação',
  'M2 Aplicação',
  'M3 GitHub',
  'M4 Liberação',
] as const;
export const dimensions = {
  ai: 'IA',
  sector: 'Setor',
  segment: 'Segmento',
  theme: 'Tema',
  project: 'Projeto',
  technical_application: 'Aplicação técnica',
  repository: 'Repositório',
} as const;
export type Taxonomy = Record<keyof typeof dimensions, string>;
export type Item = {
  id: string;
  tenant_id: string;
  author_id: string;
  title: string;
  kind: Kind;
  body: string;
  source_url: string;
  taxonomy: Partial<Taxonomy>;
  tags: string[];
  stage: number;
  revision: number;
  score: number;
  application: string;
  repository: string;
  review: Record<string, unknown>;
  created_at: string;
  updated_at: string;
};
export type Asset = {
  id: string;
  filename: string;
  mime: string;
  size_bytes: number;
  sha256: string;
  status: string;
  object_path: string;
  uploaded_by: string;
};
export type Filters = {
  q?: string;
  kind?: string;
  stage?: string;
  tag?: string;
  score?: string;
  favorite?: string;
  page?: string;
  sort?: string;
} & Partial<Record<keyof Taxonomy, string>>;
