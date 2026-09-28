import type { Party, PartyAddress, PartyContact, PartyDocument } from '../types';
import { PartyDetailPanel } from './PartyDetailPanel';

const labels: Record<string, string> = { customer: 'Cliente', supplier: 'Fornecedor', employee: 'Funcionário', buyer: 'Comprador', sales_rep: 'Vendedor', technician: 'Técnico', carrier: 'Transportadora', other: 'Outro' };

// M20-G3 — cada cadastro ganha um painel expansível (<details>, sem JS de navegação)
// com as abas Documentos/Contatos/Endereços.
export function PartyList({ parties, documents, contacts, addresses }: { parties: Party[]; documents: PartyDocument[]; contacts: PartyContact[]; addresses: PartyAddress[] }) {
  if (!parties.length) return <div className="pf-empty"><strong>Nenhum cadastro</strong>Cadastre clientes, fornecedores, compradores ou funcionários.</div>;
  return (
    <div className="pf-grid-2">
      {parties.map((p) => (
        <article className="pf-content-card" style={{ marginBottom: 0 }} key={p.id}>
          <div className="pf-card-head">
            <div><h3 style={{ margin: '0 0 4px' }}>{p.trade_name || p.legal_name}</h3><span className="pf-pill">{p.kind === 'person' ? 'Pessoa física' : 'Pessoa jurídica'}</span></div>
          </div>
          {p.trade_name && <p className="pf-muted">{p.legal_name}</p>}
          <p className="pf-muted">{p.tax_id || 'Documento não informado'}</p>
          <div>{p.erp_party_roles.filter((r) => r.active).map((r) => <span className="pf-pill" key={r.role} style={{ marginRight: 6 }}>{labels[r.role] || r.role}</span>)}</div>
          <PartyDetailPanel
            partyId={p.id}
            documents={documents.filter((d) => d.party_id === p.id)}
            contacts={contacts.filter((c) => c.party_id === p.id)}
            addresses={addresses.filter((a) => a.party_id === p.id)}
          />
        </article>
      ))}
    </div>
  );
}
