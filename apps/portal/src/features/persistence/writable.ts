import 'server-only';
import { createVisualPersistenceClient } from '../../../../../packages/visual-persistence-contract/src/server-client.mjs';
import {
  createSupabaseAggregateReader,
  createSupabasePersistenceTransport,
  type SupabaseLike,
} from '../../../../../packages/visual-persistence-supabase-adapter/src/index.mjs';
import { createClient } from '@/lib/supabase/server';
import { loadPortalAccess } from '@/lib/portal-context';

// M21-G2 (Trilha B) — apps/portal é o app que o CLIENTE loga, então aqui não existe (e
// nunca existiu) o modo síntetico/somente-leitura do apps/platform (M18-G11/G12): é a
// primeira tela real de cadastro do portal, então vai direto pro transporte que grava de
// verdade. Tenant nunca vem de formulário/query string — só de uma membership 'authorized'
// (mesma checagem de (portal)/layout.tsx e de toda action de apps/portal já existente).
async function resolveAuthorizedTenantId(): Promise<string | null> {
  const access = await loadPortalAccess();
  return access.kind === 'authorized' ? access.membership.tenantId : null;
}

export async function getPortalVisualClient() {
  const client = await createClient();
  const transport = createSupabasePersistenceTransport({
    client: client as unknown as SupabaseLike,
    aggregateReader: createSupabaseAggregateReader(),
  });
  return createVisualPersistenceClient({ transport, resolveTenant: resolveAuthorizedTenantId });
}
