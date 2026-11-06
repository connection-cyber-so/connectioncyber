import { NextResponse, type NextRequest } from 'next/server';
import { revalidatePath } from 'next/cache';
import { isSameOriginRequest } from '@/domain/request-origin';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';
import {
  buildCdRpcCall,
  cdErrorMessage,
  isCdIntent,
  parseCdItem,
} from '@/domain/cd';

export const dynamic = 'force-dynamic';

// M54-G6 — única porta de escrita da tela do CD. Tenant sempre da membership autorizada;
// o formulário só fornece IDs, validados antes da chamada. A RPC aplica permissão e capacidade.
export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request.headers.get('origin'), request.nextUrl.origin)) {
    return new NextResponse(null, { status: 403 });
  }

  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') {
    return NextResponse.redirect(new URL('/login', request.url), 303);
  }

  const form = await request.formData();
  const back = new URL('/cd', request.url);
  const intent = String(form.get('intent') ?? '');

  if (!isCdIntent(intent)) {
    back.searchParams.set('erro', 'Ação inválida.');
    return NextResponse.redirect(back, 303);
  }

  const item =
    intent === 'criar_pedido'
      ? parseCdItem({
          produto_id: form.get('produto_id'),
          qtd: form.get('qtd'),
          preco_unit: form.get('preco_unit'),
        })
      : null;

  const call = buildCdRpcCall(intent, {
    tenantId: access.membership.tenantId,
    localId: String(form.get('local_id') ?? ''),
    canal: String(form.get('canal') ?? ''),
    item: item ?? undefined,
    pedidoId: String(form.get('pedido_id') ?? ''),
    transferenciaId: String(form.get('transferencia_id') ?? ''),
  });

  if (!call) {
    back.searchParams.set('erro', 'Dados inválidos para esta ação.');
    return NextResponse.redirect(back, 303);
  }

  const supabase = await createClient();
  const { error } = await supabase.rpc(call.fn, call.args);

  if (error) {
    back.searchParams.set('erro', cdErrorMessage(error.message));
    return NextResponse.redirect(back, 303);
  }

  revalidatePath('/cd');
  back.searchParams.set('sucesso', intent);
  return NextResponse.redirect(back, 303);
}
