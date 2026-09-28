import { dimensions, kinds, type Kind, type Taxonomy } from './types';
export function requiredText(value: unknown, max = 180, min = 1): string {
  if (typeof value !== 'string' || value.trim().length < min || value.length > max)
    throw new Error('KB_INVALID_INPUT');
  return value.trim();
}
export function uuid(value: unknown): string {
  const text = requiredText(value, 36, 36);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(text))
    throw new Error('KB_INVALID_ID');
  return text;
}
export function safeUrl(value: unknown): string {
  if (value === '') return '';
  const text = requiredText(value, 2048);
  let url: URL;
  try {
    url = new URL(text);
  } catch {
    throw new Error('KB_INVALID_URL');
  }
  if (
    url.protocol !== 'https:' ||
    url.username ||
    url.password ||
    !url.hostname.includes('.') ||
    url.hostname === 'localhost' ||
    /[\s]/.test(text)
  )
    throw new Error('KB_INVALID_URL');
  return url.href;
}
export function content(data: Record<string, unknown>) {
  const kind = data.kind as Kind;
  if (!kinds.includes(kind)) throw new Error('KB_INVALID_KIND');
  const source_url = safeUrl(data.source_url ?? '');
  if ((kind === 'link' || kind === 'video') && !source_url) throw new Error('KB_URL_REQUIRED');
  const body = typeof data.body === 'string' ? data.body : '';
  if (body.length > 100000) throw new Error('KB_TOO_LARGE');
  return { title: requiredText(data.title, 180, 3), kind, body, source_url };
}
export function taxonomy(value: unknown): Taxonomy {
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw new Error('KB_TAXONOMY_REQUIRED');
  return Object.fromEntries(
    Object.keys(dimensions).map((k) => [
      k,
      requiredText((value as Record<string, unknown>)[k], 180),
    ]),
  ) as Taxonomy;
}
export function tags(value: string): string[] {
  const result = [
    ...new Set(
      value
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .filter(Boolean),
    ),
  ];
  if (result.length > 30 || result.some((t) => t.length > 60)) throw new Error('KB_INVALID_TAGS');
  return result;
}
export function repositorySuggestion(kind: Kind, project: string) {
  const slug =
    project
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9-]+/g, '-')
      .replace(/^-|-$/g, '')
      .slice(0, 60) || 'documentacao';
  const folders: Record<Kind, string> = {
    prompt: 'prompts',
    link: 'references',
    video: 'videos',
    script: 'scripts',
    code: 'src',
    migration: 'supabase/migrations',
    study: 'studies',
    file: 'assets',
  };
  return {
    repository: 'https://github.com/connection-cyber-so/connectioncyber',
    path: 'knowledge/' + slug + '/' + folders[kind],
    reason:
      'Sugestão organizacional; confirmar propriedade, licença e destino antes da publicação.',
  };
}
export function validateFile(file: { name: string; size: number; type: string }) {
  if (file.size < 1 || file.size > 3 * 1024 * 1024) throw new Error('KB_FILE_SIZE');
  if (
    !/\.(pdf|txt|md|json|csv|zip|sql|js|ts|py|sh|ps1|mp4|webm)$/i.test(file.name) ||
    file.name.length > 180 ||
    /[\x00-\x1f/\\]/.test(file.name)
  )
    throw new Error('KB_FILE_TYPE');
  return {
    filename: file.name,
    mime: file.type || 'application/octet-stream',
    size_bytes: file.size,
  };
}
export function pageNumber(value?: string) {
  const n = Number(value ?? 1);
  return Number.isSafeInteger(n) && n > 0 ? Math.min(n, 1000) : 1;
}
