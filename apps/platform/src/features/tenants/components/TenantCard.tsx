import type { ModuleCatalogEntry, TenantWithModules } from '../types';

function formatCnpj(cnpj: string | null): string | null {
  if (!cnpj) return null;
  const digits = cnpj.replace(/\D/g, '');
  if (digits.length !== 14) return cnpj;
  return digits.replace(/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/, '$1.$2.$3/$4-$5');
}

const STATUS_LABEL: Record<string, string> = {
  diagnosticado: 'diagnosticado',
  proposto: 'proposto',
  ativo: 'ativo',
  suspenso: 'suspenso',
  encerrado: 'encerrado',
};

export function TenantCard({ tenant, moduleCatalog }: { tenant: TenantWithModules; moduleCatalog: ModuleCatalogEntry[] }) {
  const moduleNameByKey = Object.fromEntries(moduleCatalog.map((m) => [m.key, m.name]));
  const cnpj = formatCnpj(tenant.cnpj);
  const localizacao = [tenant.municipio, tenant.uf].filter(Boolean).join(' / ');

  return (
    <div className="pf-content-card" style={{ marginBottom: 0 }}>
      <div className="pf-card-head">
        <div style={{ minWidth: 0 }}>
          <h3 style={{ margin: '0 0 4px', fontSize: '0.98rem' }}>{tenant.nome}</h3>
          <span className="pf-muted" style={{ fontSize: '0.8rem' }}>{tenant.razao_social ?? tenant.slug}</span>
        </div>
        {!tenant.ativo && <span className="pf-pill">inativo</span>}
      </div>

      <dl className="pf-muted" style={{ marginTop: 10, fontSize: '0.85rem', display: 'grid', gap: 4 }}>
        {cnpj && (
          <div>
            <strong>CNPJ: </strong>
            {cnpj}
            {tenant.situacao_cadastral && ` · ${tenant.situacao_cadastral}`}
          </div>
        )}
        {localizacao && (
          <div>
            <strong>Local: </strong>
            {localizacao}
          </div>
        )}
        {tenant.cnae_descricao && (
          <div>
            <strong>CNAE: </strong>
            {tenant.cnae_descricao}
          </div>
        )}
        {tenant.vertical && (
          <div>
            <strong>Vertical: </strong>
            {tenant.vertical}
          </div>
        )}
      </dl>

      <div style={{ marginTop: 12, display: 'flex', flexWrap: 'wrap', gap: 6 }}>
        {tenant.tenant_modules.length === 0 ? (
          <span className="pf-muted" style={{ fontSize: '0.8rem' }}>Nenhum módulo habilitado ainda</span>
        ) : (
          tenant.tenant_modules.map((tm) => (
            <span
              key={tm.module_key}
              className={`pf-pill ${tm.status === 'ativo' ? 'pf-pill-generated' : ''}`}
              title={STATUS_LABEL[tm.status] ?? tm.status}
            >
              {moduleNameByKey[tm.module_key] ?? tm.module_key} · {STATUS_LABEL[tm.status] ?? tm.status}
            </span>
          ))
        )}
      </div>
    </div>
  );
}
