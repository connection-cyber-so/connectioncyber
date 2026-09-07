import 'server-only';
import { cookies } from 'next/headers';

/**
 * M20-G4 — seletor de estabelecimento (individual/todas as lojas).
 *
 * O cookie guarda só uma PREFERÊNCIA de exibição, nunca autoriza nada sozinho: toda
 * leitura que usa este valor ainda filtra por `tenant_id` primeiro (RLS/facade), e o
 * próprio valor do cookie nunca é usado sem confirmar que aquele estabelecimento
 * pertence ao tenant da sessão atual (a query final sempre tem os dois filtros).
 */
const COOKIE_NAME = 'cc-establishment-scope';

/** `null` = nenhum estabelecimento específico escolhido, ou seja, "todas as lojas". */
export async function getSelectedEstablishmentId(): Promise<string | null> {
  const store = await cookies();
  const value = store.get(COOKIE_NAME)?.value;
  return value && value !== 'all' ? value : null;
}

export async function setSelectedEstablishmentId(establishmentId: string | null): Promise<void> {
  const store = await cookies();
  if (!establishmentId) {
    store.set(COOKIE_NAME, 'all', { path: '/', sameSite: 'lax' });
    return;
  }
  store.set(COOKIE_NAME, establishmentId, { path: '/', sameSite: 'lax' });
}
