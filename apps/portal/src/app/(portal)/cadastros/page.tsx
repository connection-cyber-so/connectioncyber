import { notFound, redirect } from 'next/navigation';
import { loadPortalAccess } from '@/lib/portal-context';
import { getPortalVisualClient } from '@/features/persistence/writable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

type PartyRow = {
  id: string;
  kind: 'person' | 'organization';
  legal_name: string;
  trade_name: string | null;
  tax_id: string | null;
  erp_party_roles: { role: string; active: boolean }[];
};

const ROLE_LABELS: Record<string, string> = {
  customer: 'Cliente',
  supplier: 'Fornecedor',
  employee: 'Funcionário',
  buyer: 'Comprador',
  sales_rep: 'Vendedor',
  technician: 'Técnico',
  carrier: 'Transportadora',
  other: 'Outro',
};

const ERROR_MESSAGES: Record<string, string> = {
  dados: 'Selecione o tipo e o papel corretamente.',
  nome: 'Informe um nome ou razão social com pelo menos 2 caracteres.',
  documento: 'CPF/CNPJ inválido — confira os dígitos.',
  permissao: 'Sua conta não tem permissão para cadastrar. Peça a um administrador do tenant.',
};

// M21-G2 (Trilha B) — primeira tela real de cadastro do cliente em apps/portal (o app que
// ele mesmo loga, diferente de apps/platform que é só da equipe ConnectionCyber). Reaproveita
// o mesmo comando idempotente do M17/M20 (erp_command_create_party_v1) por trás da mesma
// camada de contrato — só o transporte muda: aqui já é escrita real desde o primeiro dia,
// não existe modo síntetico neste app.
export default async function CadastrosPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind !== 'authorized') redirect('/login');

  const client = await getPortalVisualClient();
  const partiesResult = await client.read('parties');
  const parties = (partiesResult.ok ? (partiesResult.data as PartyRow[]) : []) ?? [];

  const errorCode = typeof params.erro === 'string' ? params.erro : '';
  const success = params.sucesso === '1';

  return (
    <>
      <div className="content-heading">
        <div>
          <span className="eyebrow">Cadastros</span>
          <h1>Clientes e fornecedores</h1>
          <p className="lead">
            Cadastro de pessoas de <strong>{access.membership.tenantName}</strong> — grava
            direto no banco, não é uma demonstração.
          </p>
        </div>
      </div>

      {success ? <div className="alert" role="status">Cadastro criado com sucesso.</div> : null}
      {ERROR_MESSAGES[errorCode] ? (
        <div className="alert danger" role="alert">{ERROR_MESSAGES[errorCode]}</div>
      ) : null}

      <form method="post" action="/cadastros/nova-pessoa" className="form-stack">
        <div className="form-grid-2">
          <label>
            Tipo
            <select name="kind" defaultValue="organization">
              <option value="organization">Pessoa jurídica</option>
              <option value="person">Pessoa física</option>
            </select>
          </label>
          <label>
            Papel
            <select name="role" defaultValue="customer">
              {Object.entries(ROLE_LABELS).map(([value, label]) => (
                <option key={value} value={value}>{label}</option>
              ))}
            </select>
          </label>
        </div>
        <label>
          Nome ou razão social
          <input type="text" name="legal_name" required minLength={2} maxLength={180} />
        </label>
        <div className="form-grid-2">
          <label>
            Nome fantasia (opcional)
            <input type="text" name="trade_name" maxLength={180} />
          </label>
          <label>
            CPF/CNPJ (opcional)
            <input type="text" name="tax_id" inputMode="numeric" placeholder="Só números ou com pontuação" />
          </label>
        </div>
        <button className="button primary" type="submit">Cadastrar</button>
      </form>

      <ul className="party-list" aria-label="Pessoas cadastradas">
        {parties.length === 0 ? (
          <li><span>Nenhum cadastro ainda — use o formulário acima para criar o primeiro.</span></li>
        ) : (
          parties.map((party) => (
            <li key={party.id}>
              <strong>{party.legal_name}</strong>
              <span>
                {party.erp_party_roles?.map((r) => ROLE_LABELS[r.role] ?? r.role).join(', ') || 'Sem papel'}
                {party.tax_id ? ` · ${party.tax_id}` : ''}
              </span>
            </li>
          ))
        )}
      </ul>
    </>
  );
}
