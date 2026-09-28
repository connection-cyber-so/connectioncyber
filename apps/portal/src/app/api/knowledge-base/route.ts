import { NextRequest, NextResponse } from 'next/server';
import { createHash } from 'node:crypto';
import { revalidatePath } from 'next/cache';
import { isSameOriginRequest } from '@/domain/request-origin';
import { command, context, detail } from '@/features/knowledge-base/service';
import {
  content,
  taxonomy,
  tags,
  uuid,
  validateFile,
  safeUrl,
} from '@/features/knowledge-base/validations';
import { dimensions } from '@/features/knowledge-base/types';
import { suggestClassification } from '@/features/knowledge-base/ai';
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';
async function boundedForm(request: NextRequest) {
  const limit = 4 * 1024 * 1024;
  const reader = request.body?.getReader();
  if (!reader) throw new Error('KB_INVALID_INPUT');
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) {
      await reader.cancel();
      throw new Error('KB_FILE_SIZE');
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return new Response(bytes, {
    headers: { 'Content-Type': request.headers.get('content-type') ?? '' },
  }).formData();
}
export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin))
    return new NextResponse('Origem inválida', { status: 403 });
  let target = '/biblioteca';
  try {
    await context();
    const form = await boundedForm(request);
    const action = String(form.get('action') ?? '');
    const rawId = String(form.get('id') ?? '');
    const id = rawId ? uuid(rawId) : null;
    if (id) target += '/' + id;
    const revision = Number(form.get('revision'));
    const data = Object.fromEntries([...form.entries()].filter(([, v]) => typeof v === 'string'));
    let result;
    if (action === 'create') result = await command('create', null, null, content(data));
    else if (action === 'classify')
      result = await command(action, id, revision, {
        taxonomy: taxonomy(
          Object.fromEntries(Object.keys(dimensions).map((k) => [k, form.get(k)])),
        ),
        tags: tags(String(form.get('tags') ?? '')),
      });
    else if (action === 'ai') {
      if (!id || form.get('consent') !== 'on') throw new Error('KB_INVALID_INPUT');
      const current = await detail(id);
      if (
        current.item.stage !== 0 ||
        (!current.manage && current.item.author_id !== current.userId)
      )
        throw new Error('KB_ACCESS_DENIED');
      if (current.item.revision !== revision) throw new Error('KB_REVISION_CONFLICT');
      await command('ai_request', id, revision, {});
      const suggested = await suggestClassification(current.item);
      result = await command('classify', id, revision, suggested);
    } else if (action === 'upload') {
      if (!id) throw new Error('KB_INVALID_ID');
      const file = form.get('file');
      if (!(file instanceof File)) throw new Error('KB_INVALID_INPUT');
      const metadata = validateFile(file);
      const bytes = await file.arrayBuffer();
      const sha256 = createHash('sha256').update(Buffer.from(bytes)).digest('hex');
      const reserved = await command('reserve_asset', id, revision, { ...metadata, sha256 });
      const ctx = await context();
      const { error } = await ctx.client.storage
        .from('knowledge-base')
        .upload(reserved.reserved_path!, bytes, { contentType: metadata.mime, upsert: false });
      if (error) throw new Error('KB_UPLOAD_FAILED');
      result = await command('finalize_asset', id, reserved.revision, {
        asset_id: reserved.reserved_asset_id,
      });
    } else if (action === 'revise')
      result = await command(action, id, revision, {
        title: String(form.get('title') ?? ''),
        body: String(form.get('body') ?? ''),
        source_url: safeUrl(form.get('source_url') ?? ''),
      });
    else if (['advance', 'favorite', 'rate', 'review_asset'].includes(action))
      result = await command(action, id, revision, data);
    else throw new Error('KB_UNKNOWN_COMMAND');
    revalidatePath('/biblioteca');
    if (result?.id) target = '/biblioteca/' + result.id;
    return NextResponse.redirect(new URL(target + '?ok=1', request.url), 303);
  } catch (error) {
    const code =
      error instanceof Error && /^KB_[A-Z_]+$/.test(error.message)
        ? error.message
        : 'KB_COMMAND_FAILED';
    return NextResponse.redirect(new URL(target + '?error=' + code, request.url), 303);
  }
}
