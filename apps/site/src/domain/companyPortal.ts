// M19-G5 — roteamento pra "empresa com portal próprio", puramente
// client-side: nenhuma chamada de rede aqui, nenhum lookup de tenant por
// e-mail (desenho rejeitado por risco de enumeração de conta — ver
// STATUS-MESTRE-DESENVOLVIMENTO.md, M19-G5). A existência real do tenant é
// resolvida só no destino, por apps/portal (classifyPortalHostname +
// portal_resolve_host, já existentes, sem mudança aqui).
//
// Padrão do label espelha o check da migration 0017
// (erp_tenant_domains_subdomain_scope): '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'.
const SUBDOMAIN_LABEL_PATTERN = /^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/;
const HOSTNAME_PATTERN = /^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$/;
const PORTAL_DOMAIN_SUFFIX = '.connectioncyber.com.br';

export function buildCompanyPortalLoginUrl(rawInput: string): string | null {
  const normalized = rawInput.trim().toLowerCase();
  if (!normalized) return null;

  // Hostname completo (domínio próprio do cliente) — precisa ter pelo menos
  // um ponto e parecer um hostname válido.
  if (normalized.includes('.')) {
    if (!HOSTNAME_PATTERN.test(normalized)) return null;
    return `https://${normalized}/login`;
  }

  // Só o slug — monta o subdomínio oficial.
  if (!SUBDOMAIN_LABEL_PATTERN.test(normalized)) return null;
  return `https://${normalized}${PORTAL_DOMAIN_SUFFIX}/login`;
}
