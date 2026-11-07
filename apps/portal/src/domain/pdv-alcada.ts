// Contrato puro da alçada do PDV (PIN do aprovador). Sem dependência de servidor.
// Espelha as RPCs das migrations 0065, 0066, 0067 e 0068/0069 (staging).

export const PIN_PATTERN = /^[0-9]{4,6}$/;

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type AlcadaBlockedStatus = 'pin_invalid' | 'pin_locked' | 'pin_missing';

export type AlcadaResult =
  | { status: 'authorized'; authorizationId: string }
  | { status: AlcadaBlockedStatus };

export function isValidPin(pin: string): boolean {
  return PIN_PATTERN.test(pin);
}

// Converte o jsonb devolvido pelas RPCs. Retorno fora do contrato lança erro (fail-closed).
export function parseAlcadaResult(data: unknown): AlcadaResult {
  if (typeof data !== 'object' || data === null) {
    throw new Error('ALCADA_RESULT_INVALIDO');
  }
  const record = data as Record<string, unknown>;
  if (record.status === 'authorized') {
    if (typeof record.authorization_id !== 'string' || !UUID_PATTERN.test(record.authorization_id)) {
      throw new Error('ALCADA_RESULT_SEM_ID');
    }
    return { status: 'authorized', authorizationId: record.authorization_id };
  }
  if (record.status === 'pin_invalid' || record.status === 'pin_locked' || record.status === 'pin_missing') {
    return { status: record.status };
  }
  throw new Error('ALCADA_RESULT_STATUS_DESCONHECIDO');
}

// Só grava a alçada no fluxo de venda ou caixa quando autorizada.
export function canRecordAuthorization(result: AlcadaResult): result is Extract<AlcadaResult, { status: 'authorized' }> {
  return result.status === 'authorized';
}

// Mensagem para o operador. Não revela se o PIN existe além do necessário.
export function alcadaMessage(result: AlcadaResult): string {
  switch (result.status) {
    case 'authorized':
      return 'Autorizado.';
    case 'pin_invalid':
      return 'PIN incorreto.';
    case 'pin_locked':
      return 'PIN bloqueado por 15 minutos após 5 erros. Aguarde ou peça a outro aprovador.';
    case 'pin_missing':
      return 'Aprovador sem PIN cadastrado. Peça ao gerente para cadastrar o PIN.';
  }
}

// Erros do cadastro de PIN pelo gerente (SQLSTATE das migrations 0068/0069).
export function managerPinErrorMessage(sqlstate: string | undefined): string {
  switch (sqlstate) {
    case '22023':
      return 'PIN deve ter de 4 a 6 dígitos.';
    case '42501':
      return 'Sem permissão para cadastrar este PIN.';
    case '23514':
      return 'O usuário escolhido não tem permissão de alçada.';
    default:
      return 'Não foi possível cadastrar o PIN.';
  }
}
