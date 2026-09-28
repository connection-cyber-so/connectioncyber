export type IdentityPersona = {
  key: string;
  label: string;
  email: string;
  tenant: string;
  role: string;
  status: 'Ativo' | 'Convidado' | 'Suspenso' | 'Sem vínculo';
  mfa: 'Obrigatório' | 'Opcional' | 'Não aplicável';
};

export const identityPersonas: IdentityPersona[] = [
  { key: 'P01', label: 'Owner A', email: 'p01-owner-a@example.invalid', tenant: 'Tenant A', role: 'owner', status: 'Ativo', mfa: 'Obrigatório' },
  { key: 'P02', label: 'Owner B', email: 'p02-owner-b@example.invalid', tenant: 'Tenant B', role: 'owner', status: 'Ativo', mfa: 'Obrigatório' },
  { key: 'P03', label: 'Multiempresa', email: 'p03-multiempresa@example.invalid', tenant: 'A + B', role: 'manager / viewer', status: 'Ativo', mfa: 'Opcional' },
  { key: 'P04', label: 'Staff sem membership', email: 'p04-staff@example.invalid', tenant: 'Nenhum', role: 'staff global', status: 'Sem vínculo', mfa: 'Obrigatório' },
  { key: 'P05', label: 'Usuário suspenso', email: 'p05-suspenso@example.invalid', tenant: 'Tenant A', role: 'operator', status: 'Suspenso', mfa: 'Opcional' },
  { key: 'P06', label: 'Convite pendente', email: 'p06-convidado@example.invalid', tenant: 'Tenant B', role: 'viewer', status: 'Convidado', mfa: 'Opcional' },
  { key: 'P07', label: 'Privilegiado AAL2', email: 'p07-aal2@example.invalid', tenant: 'Tenant A', role: 'admin', status: 'Ativo', mfa: 'Obrigatório' },
];

export const roleMatrix = [
  { key: 'owner', name: 'Proprietário', scope: 'Administração total do tenant', mfa: true, tone: 'red' },
  { key: 'admin', name: 'Administrador', scope: 'Usuários e operação', mfa: true, tone: 'orange' },
  { key: 'manager', name: 'Gerente', scope: 'Operação e relatórios', mfa: false, tone: 'teal' },
  { key: 'operator', name: 'Operador', scope: 'Rotina operacional', mfa: false, tone: 'green' },
  { key: 'viewer', name: 'Consulta', scope: 'Leitura controlada', mfa: false, tone: 'blue' },
] as const;
