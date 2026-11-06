import { notFound, redirect } from 'next/navigation';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';
import {
  listCdLocals,
  listCdPedidos,
  listTransferenciasAbertas,
} from '@/features/cd/service';
import {
  CD_CANAIS,
  CD_CANAL_LABEL,
  CD_STATUS_LABEL,
  cdNextActions,
  type CdIntent,
} from '@/domain/cd';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

const INTENT_LABEL: Record<CdIntent, string> = {
  criar_pedido: 'Criar pedido',
  alocar_pedido: 'Alocar',
  aprovar_pedido: 'Aprovar e alocar',
  receber_transferencia: 'Receber',
  coletar_pedido: 'Coletar no CD',
  despachar_pedido: 'Despachar',
};

const money = (value: number) =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value);

// M54-G6 — tela do Centro Logístico. Leitura por RLS; toda escrita vai para /cd/acao (RPC cd_api_*).
export default async function CdPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind !== 'authorized') redirect('/login');

  const tenantId = access.membership.tenantId;
  const supabase = await createClient();
  const [locais, pedidos, transferencias] = await Promise.all([
    listCdLocals(supabase, tenantId),
    listCdPedidos(supabase, tenantId),
    listTransferenciasAbertas(supabase, tenantId),
  ]);

  const erro = typeof params.erro === 'string' ? params.erro : '';
  const sucesso = typeof params.sucesso === 'string' ? params.sucesso : '';
  const localById = new Map(locais.map((local) => [local.id, local]));

  return (
    <div>
      <div className="eyebrow">ConnectionCyber · Centro Logístico</div>
      <h1>Centro Logístico</h1>

      {erro ? <p role="alert" className="notice error">{erro}</p> : null}
      {sucesso ? <p role="status" className="notice success">{INTENT_LABEL[sucesso as CdIntent] ?? 'Ação concluída'} concluída.</p> : null}

      <section aria-labelledby="novo-pedido">
        <h2 id="novo-pedido">Novo pedido</h2>
        <form method="post" action="/cd/acao" className="cd-form">
          <input type="hidden" name="intent" value="criar_pedido" />
          <label>
            Centro
            <select name="local_id" required>
              {locais.map((local) => (
                <option key={local.id} value={local.id}>{local.codigo} · {local.nome}</option>
              ))}
            </select>
          </label>
          <label>
            Canal
            <select name="canal" required>
              {CD_CANAIS.map((canal) => (
                <option key={canal} value={canal}>{CD_CANAL_LABEL[canal]}</option>
              ))}
            </select>
          </label>
          <label>
            ID do produto
            <input name="produto_id" required placeholder="UUID do produto" />
          </label>
          <label>
            Quantidade
            <input name="qtd" type="number" min="1" step="1" required />
          </label>
          <label>
            Preço unitário (R$)
            <input name="preco_unit" inputMode="decimal" required placeholder="0,00" />
          </label>
          <button type="submit" className="button compact">Criar pedido</button>
        </form>
      </section>

      <section aria-labelledby="pedidos">
        <h2 id="pedidos">Pedidos ({pedidos.length})</h2>
        {pedidos.length === 0 ? <p>Nenhum pedido ainda.</p> : (
          <table>
            <thead>
              <tr><th>Canal</th><th>Status</th><th>Qtd</th><th>Total</th><th>Ações</th></tr>
            </thead>
            <tbody>
              {pedidos.map((pedido) => (
                <tr key={pedido.id}>
                  <td>{CD_CANAL_LABEL[pedido.canal as keyof typeof CD_CANAL_LABEL] ?? pedido.canal}</td>
                  <td>{CD_STATUS_LABEL[pedido.status] ?? pedido.status}</td>
                  <td>{pedido.total_qtd}</td>
                  <td>{money(Number(pedido.total_valor))}</td>
                  <td>
                    {cdNextActions(pedido.status, pedido.canal).map((intent) => (
                      <form key={intent} method="post" action="/cd/acao" style={{ display: 'inline' }}>
                        <input type="hidden" name="intent" value={intent} />
                        <input type="hidden" name="pedido_id" value={pedido.id} />
                        <button type="submit" className="button ghost compact">{INTENT_LABEL[intent]}</button>
                      </form>
                    ))}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      <section aria-labelledby="transferencias">
        <h2 id="transferencias">Transferências abertas ({transferencias.length})</h2>
        {transferencias.length === 0 ? <p>Nenhuma transferência aberta.</p> : (
          <table>
            <thead>
              <tr><th>Origem</th><th>Destino</th><th>Status</th><th>Ação</th></tr>
            </thead>
            <tbody>
              {transferencias.map((transferencia) => (
                <tr key={transferencia.id}>
                  <td>{localById.get(transferencia.origem_local_id)?.codigo ?? 'Loja'}</td>
                  <td>{localById.get(transferencia.destino_local_id)?.codigo ?? 'CD'}</td>
                  <td>{CD_STATUS_LABEL[transferencia.status] ?? transferencia.status}</td>
                  <td>
                    <form method="post" action="/cd/acao">
                      <input type="hidden" name="intent" value="receber_transferencia" />
                      <input type="hidden" name="transferencia_id" value={transferencia.id} />
                      <button type="submit" className="button ghost compact">{INTENT_LABEL.receber_transferencia}</button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  );
}
