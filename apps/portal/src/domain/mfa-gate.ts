// M18-G22 — decide só uma coisa: se a sessão atual pode seguir pra rota
// pedida ou precisa ser desviada pra tela de segurança (cadastro/step-up de
// MFA). Não decide autorização de dado nenhum — isso continua sendo RLS/RPC
// no banco (erp_security.has_permission_at_aal, migration 0018). Esta função
// só existe pra UX: evitar que quem precisa de AAL2 e ainda não tem chegue
// numa tela que a RLS vai recusar de qualquer forma sem explicação nenhuma.
export const MFA_SECURITY_PATH = '/configuracoes/seguranca';

export type AalLevel = 'aal1' | 'aal2';

export type MfaGateDecision = 'allow' | 'redirect-to-security';

export function decideMfaGate(input: {
  requiresAal2: boolean;
  currentLevel: AalLevel;
  pathname: string;
}): MfaGateDecision {
  if (!input.requiresAal2) return 'allow';
  // Sem isto, quem está exatamente na tela de segurança seria redirecionado
  // pra ela mesma — loop infinito.
  if (input.pathname === MFA_SECURITY_PATH) return 'allow';
  if (input.currentLevel === 'aal2') return 'allow';
  return 'redirect-to-security';
}
