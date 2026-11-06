import { getPortalVisualClient } from '@/features/persistence/writable';
import { CrmShell } from '@/components/crm/CrmShell';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type PartyRow = {
  id: string;
  kind: 'person' | 'organization';
  legal_name: string;
  trade_name: string | null;
  tax_id: string | null;
  active: boolean;
  erp_party_roles: { role: string; active: boolean }[];
};


export default async function CrmClientesPage() {
  const client = await getPortalVisualClient();
  const result = await client.read('parties');
  const rows = ((result.ok ? (result.data as PartyRow[]) : []) ?? []).filter((p) =>
    p.erp_party_roles?.some((r) => r.role === 'customer')
  );
  const ativos = rows.filter((p) => p.active).length;

  return (
    <CrmShell>
      <div style={{ padding: '24px 28px' }}>
        <h1 style={{ margin: 0, fontSize: 26 }}>Clientes</h1>
        <p style={{ margin: '4px 0 20px', opacity: 0.7 }}>
          {rows.length} cadastrados · {ativos} ativos
        </p>

        {rows.length === 0 ? (
          <p>Nenhum cliente cadastrado.</p>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ textAlign: 'left', borderBottom: '1px solid #ccc' }}>
                  <th style={{ padding: 8 }}>Nome</th>
                  <th style={{ padding: 8 }}>Tipo</th>
                  <th style={{ padding: 8 }}>Documento</th>
                  <th style={{ padding: 8 }}>Status</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((p) => (
                  <tr key={p.id} style={{ borderBottom: '1px solid #eee' }}>
                    <td style={{ padding: 8 }}>{p.legal_name}</td>
                    <td style={{ padding: 8 }}>{p.kind === 'person' ? 'Pessoa física' : 'Pessoa jurídica'}</td>
                    <td style={{ padding: 8 }}>{p.tax_id ?? '—'}</td>
                    <td style={{ padding: 8 }}>{p.active ? 'Ativo' : 'Inativo'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </CrmShell>
  );
}
