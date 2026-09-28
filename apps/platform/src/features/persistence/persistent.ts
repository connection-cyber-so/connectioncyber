import 'server-only';
import { createVisualPersistenceClient } from '../../../../../packages/visual-persistence-contract/src/server-client.mjs';
import { createSupabaseAggregateReader, createSupabasePersistenceTransport, type SupabaseLike } from '../../../../../packages/visual-persistence-supabase-adapter/src/index.mjs';

export function createPersistentVisualClient(options: { client: SupabaseLike; resolveTenant: () => Promise<string | null> }) {
  const transport = createSupabasePersistenceTransport({ client: options.client, aggregateReader: createSupabaseAggregateReader() });
  return createVisualPersistenceClient({ transport, resolveTenant: options.resolveTenant });
}

export const persistentTransportMode = 'M18-G7 · composição preparada · ativação remota bloqueada';
