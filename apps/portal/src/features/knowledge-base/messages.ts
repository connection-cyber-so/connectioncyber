export function message(code: string) {
  const messages: Record<string, string> = {
    KB_DISABLED: 'Biblioteca em preparação. A ativação depende da validação em staging.',
    KB_SUBSCRIPTION_REQUIRED:
      'A Biblioteca exige uma assinatura vigente vinculada à sua empresa e conta, e MFA quando exigido pelo seu papel.',
    KB_UNAVAILABLE: 'Biblioteca indisponível. Tente novamente ou contate a administração.',
    KB_REVISION_CONFLICT: 'Este item mudou. Recarregue a página antes de continuar.',
    KB_AI_UNCONFIGURED: 'A classificação por IA ainda não foi configurada.',
    KB_INDEPENDENT_REVIEW_REQUIRED: 'A liberação exige revisão por outro curador.',
    KB_ASSETS_PENDING: 'Há arquivos aguardando revisão.',
    KB_CURATOR_REQUIRED: 'Esta ação exige permissão de curadoria e MFA.',
    KB_NOT_FOUND: 'Item não encontrado ou sem permissão.',
    KB_GATE_ORDER: 'A ação não é permitida neste gate.',
  };
  return (
    messages[code] ??
    'Não foi possível concluir. Verifique os campos, os requisitos do gate e sua permissão.'
  );
}
