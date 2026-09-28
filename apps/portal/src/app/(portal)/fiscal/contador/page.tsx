import { notFound, redirect } from 'next/navigation';
import { loadPortalAccess } from '@/lib/portal-context';
import { createClient } from '@/lib/supabase/server';
import {
  buildPackageViews,
  isAccountant,
  signOwnFiles,
} from '@/features/fiscal/service';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

const STATUS_LABEL: Record<string, string> = {
  ready: 'Aguardando recibo',
  acknowledged: 'Recebido pelo contador',
  void: 'Anulado',
};

const ERRO_LABEL: Record<string, string> = {
  competencia: 'Competencia invalida: use o formato e nao envie meses futuros.',
  arquivos: 'Selecione de 1 a 500 arquivos .xml ou .pdf.',
  nome: 'Nome de arquivo invalido (use apenas letras, numeros, ponto, hifen e sublinhado).',
  tipo: 'Sao aceitos apenas arquivos .xml e .pdf.',
  tamanho: 'Arquivo vazio ou maior que 10 MB.',
  conteudo: 'O conteudo do arquivo nao confere com a extensao declarada.',
  upload: 'Falha ao enviar o arquivo ao armazenamento.',
  publicacao: 'Nao foi possivel publicar: competencia ja publicada ou sem permissao.',
  recibo: 'Nao foi possivel registrar o recibo.',
  anulacao: 'Nao foi possivel anular o pacote (informe um motivo valido).',
  pacote: 'Pacote invalido.',
  acao: 'Acao nao reconhecida.',
};

const SUCESSO_LABEL: Record<string, string> = {
  publicado: 'Pacote publicado. O contador ja pode conferir e dar o recibo.',
  recibo: 'Recibo registrado. O pacote foi dado como conferido.',
  anulacao: 'Pacote anulado.',
};

function formatCompetencia(competencia: string): string {
  const [year, month] = competencia.split('-');
  return month && year ? `${month}/${year}` : competencia;
}

function formatBytes(bytes: number): string {
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  if (bytes >= 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${bytes} B`;
}

// M24 - Envio do lote fiscal mensal (XML + DANFE) ao contador, com recibo.
// Dono publica (upload + erp_publish_accountant_package); contador enxerga todos
// os tenants apenas pela RPC auditada e registra recibo (ack) / anulacao (void).
export default async function EnvioContadorPage({
  searchParams,
}: {
  searchParams: Promise<{ sucesso?: string; erro?: string }>;
}) {
  const params = await searchParams;
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind !== 'authorized') redirect('/login');

  const tenantId = access.membership.tenantId;
  const supabase = await createClient();
  const accountant = await isAccountant(supabase);
  const loaded = await buildPackageViews(supabase, tenantId, accountant);
  const views = accountant ? loaded : await signOwnFiles(supabase, loaded);

  const erroMensagem = params.erro ? ERRO_LABEL[params.erro] ?? ERRO_LABEL.acao : null;
  const sucessoMensagem = params.sucesso ? SUCESSO_LABEL[params.sucesso] ?? null : null;

  return (
    <div>
      <div className="content-heading">
        <div>
          <div className="eyebrow">ConnectionCyber - Fiscal</div>
          <h1>Envio ao contador</h1>
        </div>
        <span className="status-chip">
          {accountant ? 'Acesso do contador (todos os tenants)' : 'Sua empresa'}
        </span>
      </div>

      <p className="lead">
        {accountant
          ? 'Pacotes fiscais mensais de todos os clientes: baixe os XML/DANFE, confira e registre o recibo. Cada listagem e cada acesso ficam gravados em auditoria.'
          : 'Publique a competencia do mes (XML + DANFE) e o nosso escritorio contabil confere pelo proprio portal, sem compartilhar arquivos por AnyDesk.'}
      </p>

      {sucessoMensagem ? <div className="alert">{sucessoMensagem}</div> : null}
      {erroMensagem ? <div className="alert danger">{erroMensagem}</div> : null}

      {!accountant ? (
        <form className="form-stack" action="/fiscal/contador" method="post" encType="multipart/form-data">
          <input type="hidden" name="acao" value="publicar" />
          <label>
            Competencia (mes de referencia)
            <input type="month" name="competencia" required />
          </label>
          <label>
            Arquivos do lote (.xml e .pdf, ate 500)
            <input type="file" name="arquivos" multiple accept=".xml,.pdf" required />
          </label>
          <div>
            <button className="button primary" type="submit">
              Publicar pacote para o contador
            </button>
          </div>
        </form>
      ) : null}

      {views.length === 0 ? (
        <p className="fine-print">Nenhum pacote fiscal publicado ate agora.</p>
      ) : (
        <div className="module-grid">
          {views.map((view) => {
            const pkg = view.pkg;
            return (
              <div className="module-card" key={pkg.id}>
                <div className="module-icon">{formatCompetencia(pkg.competencia).split('/')[0]}</div>
                <div>
                  <div className="module-gate">
                    {accountant ? pkg.tenant_nome ?? pkg.tenant_id.slice(0, 8) : 'Pacote fiscal mensal'}
                  </div>
                  <h2>{formatCompetencia(pkg.competencia)}</h2>
                  <span className="status-chip">{STATUS_LABEL[pkg.status] ?? pkg.status}</span>
                  <p>
                    {pkg.file_count} arquivo(s), {formatBytes(pkg.total_bytes)}. Manifesto SHA-256{' '}
                    {pkg.content_hash.slice(0, 16)}...
                  </p>
                  {pkg.acknowledged_at ? (
                    <p className="fine-print">
                      Recibo em {new Date(pkg.acknowledged_at).toLocaleString('pt-BR')}
                      {pkg.acknowledged_note ? ` - ${pkg.acknowledged_note}` : ''}
                    </p>
                  ) : null}
                  <ul className="security-list">
                    {view.files.map((file) => (
                      <li key={file.id}>
                        {file.url ? (
                          <a href={file.url} target="_blank" rel="noreferrer">
                            {file.file_name}
                          </a>
                        ) : (
                          file.file_name
                        )}{' '}
                        <span className="fine-print">
                          {file.kind.toUpperCase()} - {formatBytes(file.byte_size)}
                        </span>
                      </li>
                    ))}
                  </ul>

                  {accountant && pkg.status === 'ready' ? (
                    <form action="/fiscal/contador" method="post" encType="application/x-www-form-urlencoded">
                      <input type="hidden" name="acao" value="ack" />
                      <input type="hidden" name="tenant_id" value={pkg.tenant_id} />
                      <input type="hidden" name="package_id" value={pkg.id} />
                      <label className="fine-print">
                        Observacao do recibo (opcional)
                        <input type="text" name="nota" maxLength={2000} />
                      </label>
                      <div>
                        <button className="button primary compact" type="submit">
                          Conferido: dar recibo
                        </button>
                      </div>
                    </form>
                  ) : null}

                  {!accountant && pkg.status !== 'void' ? (
                    <form action="/fiscal/contador" method="post" encType="application/x-www-form-urlencoded">
                      <input type="hidden" name="acao" value="void" />
                      <input type="hidden" name="tenant_id" value={pkg.tenant_id} />
                      <input type="hidden" name="package_id" value={pkg.id} />
                      <label className="fine-print">
                        Motivo da anulacao (obrigatorio)
                        <input type="text" name="motivo" required maxLength={1000} />
                      </label>
                      <div>
                        <button className="button ghost compact" type="submit">
                          Anular pacote
                        </button>
                      </div>
                    </form>
                  ) : null}
                </div>
              </div>
            );
          })}
        </div>
      )}

      <p className="fine-print">
        Cada listagem, baixa e recibo do contador e auditada em logs_access. Pacotes anulados nao
        podem receber recibo; recibo repetido nao altera nada (idempotencia por chave estavel).
      </p>
    </div>
  );
}
