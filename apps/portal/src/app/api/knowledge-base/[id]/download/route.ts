import { NextRequest, NextResponse } from 'next/server';
import { command, detail } from '@/features/knowledge-base/service';
import { uuid } from '@/features/knowledge-base/validations';
export const dynamic = 'force-dynamic';
export async function GET(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const ctx = await detail(uuid(id));
    const assetId = request.nextUrl.searchParams.get('asset');
    const inspect = request.nextUrl.searchParams.get('inspect') === '1' && ctx.manage;
    if (!inspect && ctx.item.stage !== 4)
      return new NextResponse('Conteúdo não liberado', { status: 403 });
    if (assetId) {
      const asset = ctx.assets.find(
        (a) =>
          a.id === uuid(assetId) &&
          (a.status === 'approved' || (inspect && a.status === 'quarantined')),
      );
      if (!asset) return new NextResponse('Arquivo não encontrado', { status: 404 });
      await command(inspect ? 'inspect' : 'download', id, null, { asset_id: asset.id });
      const { data, error } = await ctx.client.storage
        .from('knowledge-base')
        .createSignedUrl(asset.object_path, 60, { download: asset.filename });
      if (error || !data) throw new Error('KB_DOWNLOAD_FAILED');
      return NextResponse.redirect(data.signedUrl, {
        status: 303,
        headers: { 'Cache-Control': 'private, no-store', 'Referrer-Policy': 'no-referrer' },
      });
    }
    await command('download', id, null, {});
    return new NextResponse(ctx.item.body, {
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Content-Disposition':
          'attachment; filename="biblioteca-' + id + '-v' + ctx.item.revision + '.txt"',
        'X-Content-Type-Options': 'nosniff',
        'Cache-Control': 'private, no-store',
      },
    });
  } catch {
    return new NextResponse('Download indisponível ou sem permissão', {
      status: 403,
      headers: { 'Cache-Control': 'private, no-store' },
    });
  }
}
