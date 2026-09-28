import { NextResponse, type NextRequest } from 'next/server';
import { isSameOriginRequest } from '@/domain/request-origin';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';

const COMPETENCIA_RE = /^\d{4}-(0[1-9]|1[0-2])$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const FILE_NAME_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,150}$/;
const MAX_FILES = 500;
const MAX_BYTES = 10 * 1024 * 1024;

function backTo(request: NextRequest, code?: string, success?: string) {
  const url = new URL('/fiscal/contador', request.url);
  if (code) url.searchParams.set('erro', code);
  if (success) url.searchParams.set('sucesso', success);
  return NextResponse.redirect(url, 303);
}

async function sha256Hex(buffer: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', buffer);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

// M24 - acoes do envio ao contador: publicar (upload + RPC), recibo (ack) e
// anulacao (void). Idempotencia por chave estavel por tenant/competencia/pacote.
export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }
  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') {
    return NextResponse.redirect(new URL('/login', request.url), 303);
  }
  const tenantId = access.membership.tenantId;
  const formData = await request.formData();
  const acao = String(formData.get('acao') ?? '');
  const supabase = await createClient();

  if (acao === 'publicar') {
    const competencia = String(formData.get('competencia') ?? '');
    if (!COMPETENCIA_RE.test(competencia)) return backTo(request, 'competencia');
    const arquivos = formData.getAll('arquivos').filter((entry): entry is File => entry instanceof File);
    if (arquivos.length < 1 || arquivos.length > MAX_FILES) return backTo(request, 'arquivos');

    const prefix = `${tenantId}/${competencia}/`;
    const files: Array<{
      file_name: string;
      storage_path: string;
      content_hash: string;
      byte_size: number;
      kind: 'xml' | 'danfe';
    }> = [];

    for (const file of arquivos) {
      const fileName = file.name.replace(/[^A-Za-z0-9._-]/g, '_');
      if (!FILE_NAME_RE.test(fileName) || fileName.includes('..')) return backTo(request, 'nome');
      const lower = fileName.toLowerCase();
      const kind = lower.endsWith('.xml') ? 'xml' : lower.endsWith('.pdf') ? 'danfe' : null;
      if (!kind) return backTo(request, 'tipo');

      const buffer = await file.arrayBuffer();
      if (buffer.byteLength < 1 || buffer.byteLength > MAX_BYTES) return backTo(request, 'tamanho');

      const head = new TextDecoder()
        .decode(buffer.slice(0, 64))
        .replace(/^\uFEFF/, '')
        .trimStart();
      if (kind === 'xml' && !head.startsWith('<')) return backTo(request, 'conteudo');
      if (kind === 'danfe' && !head.startsWith('%PDF')) return backTo(request, 'conteudo');

      const storagePath = `${prefix}${fileName}`;
      const { error: uploadError } = await supabase.storage
        .from('fiscal-deliveries')
        .upload(storagePath, buffer, {
          contentType:
            file.type || (kind === 'xml' ? 'application/xml' : 'application/pdf'),
          upsert: false,
        });
      if (uploadError && !/already exists|duplicate/i.test(uploadError.message)) {
        return backTo(request, 'upload');
      }

      files.push({
        file_name: fileName,
        storage_path: storagePath,
        content_hash: await sha256Hex(buffer),
        byte_size: buffer.byteLength,
        kind,
      });
    }

    const { error } = await supabase.rpc('erp_publish_accountant_package', {
      p_tenant_id: tenantId,
      p_competencia: `${competencia}-01`,
      p_files: files,
      p_idempotency_key: `pub:${tenantId}:${competencia}`,
    });
    if (error) return backTo(request, 'publicacao');
    return backTo(request, undefined, 'publicado');
  }

  if (acao === 'ack') {
    const pkgTenant = String(formData.get('tenant_id') ?? '');
    const packageId = String(formData.get('package_id') ?? '');
    if (!UUID_RE.test(pkgTenant) || !UUID_RE.test(packageId)) return backTo(request, 'pacote');
    const nota = String(formData.get('nota') ?? '').trim();
    const { error } = await supabase.rpc('erp_ack_accountant_package', {
      p_tenant_id: pkgTenant,
      p_package_id: packageId,
      p_note: nota ? nota.slice(0, 2000) : null,
      p_idempotency_key: `ack:${packageId}`,
    });
    if (error) return backTo(request, 'recibo');
    return backTo(request, undefined, 'recibo');
  }

  if (acao === 'void') {
    const pkgTenant = String(formData.get('tenant_id') ?? '');
    const packageId = String(formData.get('package_id') ?? '');
    if (!UUID_RE.test(pkgTenant) || !UUID_RE.test(packageId)) return backTo(request, 'pacote');
    const motivo = String(formData.get('motivo') ?? '').trim();
    if (!motivo) return backTo(request, 'anulacao');
    const { error } = await supabase.rpc('erp_void_accountant_package', {
      p_tenant_id: pkgTenant,
      p_package_id: packageId,
      p_reason: motivo.slice(0, 1000),
      p_idempotency_key: `void:${packageId}`,
    });
    if (error) return backTo(request, 'anulacao');
    return backTo(request, undefined, 'anulacao');
  }

  return backTo(request, 'acao');
}
