export interface Tenant {
  id: string;
  nome: string;
  slug: string;
  vertical: string | null;
  dominio: string | null;
  ativo: boolean;
  cnpj: string | null;
  razao_social: string | null;
  cnae_principal: string | null;
  cnae_descricao: string | null;
  porte_receita: string | null;
  situacao_cadastral: string | null;
  municipio: string | null;
  uf: string | null;
  data_abertura: string | null;
  natureza_juridica: string | null;
  created_at: string;
}

export interface TenantModuleRow {
  module_key: string;
  status: string;
}

export interface TenantWithModules extends Tenant {
  tenant_modules: TenantModuleRow[];
}

export interface ModuleCatalogEntry {
  key: string;
  name: string;
}
