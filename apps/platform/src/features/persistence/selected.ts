import 'server-only';
import type { CommandName, Json, ReadModelName, VisualPersistenceClient } from '../../../../../packages/visual-persistence-contract/src/server-client.mjs';
import type { SupabaseLike } from '../../../../../packages/visual-persistence-supabase-adapter/src/index.mjs';
import type { Party } from '@/features/parties/types';
import type { CatalogItem, Unit } from '@/features/catalog/types';
import { createClient } from '@/lib/supabase/server';
import { getCurrentTenantId } from '@/lib/tenant';
import { createPersistentVisualClient } from './persistent';
import { resolveVisualPersistenceMode, selectVisualPersistence } from './selector.mjs';
import {
  listLocalCash, listLocalCatalogItems, listLocalParties, listLocalReceivables,
  listLocalSales, listLocalStock, listLocalUnits, localDashboard,
  localPersistenceClient, prepareLocalSale, prepareLocalSettlement,
  type LocalCashRow, type LocalReceivable, type LocalSaleRow, type LocalStockRow
} from './local';

type Dashboard = Awaited<ReturnType<typeof localDashboard>>;
type VisualFacade = {
  client: VisualPersistenceClient;
  listCash(): Promise<LocalCashRow | null>;
  listCatalogItems(): Promise<CatalogItem[]>;
  listParties(): Promise<Party[]>;
  listReceivables(): Promise<LocalReceivable[]>;
  listSales(): Promise<LocalSaleRow[]>;
  listStock(): Promise<LocalStockRow[]>;
  listUnits(): Promise<Unit[]>;
  dashboard(): Promise<Dashboard>;
  prepareSale: typeof prepareLocalSale;
  prepareSettlement: typeof prepareLocalSettlement;
};

const blockedError = Object.freeze({ code: 'CAPABILITY_REQUIRED', message: 'Este recurso está disponível somente para leitura.', retryWriteAutomatically: false as const, detailExposed: false as const, unsafeDetailRecorded: false as const, unsafeDetailLength: 0 });
const blockedClient: VisualPersistenceClient = Object.freeze({
  async execute(command: CommandName) { return Object.freeze({ ok: false as const, command, requestId: crypto.randomUUID(), error: blockedError, revalidated: false as const }); },
  async read(model: ReadModelName) { return persistentClient().then(client => client.read(model)); }
});

async function persistentClient() {
  const client = await createClient();
  return createPersistentVisualClient({ client: client as unknown as SupabaseLike, resolveTenant: getCurrentTenantId });
}

async function readPersistent<T>(model: ReadModelName): Promise<T> {
  const result = await blockedClient.read(model);
  if (!result.ok) throw Object.assign(new Error(result.error.message), { code: result.error.code });
  return result.data as T;
}

const denyPreparation = async () => { throw Object.assign(new Error('PERSISTENT_WRITES_DISABLED'), { code: 'PERSISTENT_WRITES_DISABLED' }); };
const syntheticFacade: VisualFacade = Object.freeze({ client: localPersistenceClient, listCash: listLocalCash, listCatalogItems: listLocalCatalogItems, listParties: listLocalParties, listReceivables: listLocalReceivables, listSales: listLocalSales, listStock: listLocalStock, listUnits: listLocalUnits, dashboard: localDashboard, prepareSale: prepareLocalSale, prepareSettlement: prepareLocalSettlement });
const persistentReadOnlyFacade: VisualFacade = Object.freeze({
  client: blockedClient,
  async listCash() { const rows = await readPersistent<LocalCashRow[]>('open-cash-sessions'); return rows[0] ?? null; },
  listCatalogItems: () => readPersistent<CatalogItem[]>('catalog-items'),
  listParties: () => readPersistent<Party[]>('parties'),
  listReceivables: () => readPersistent<LocalReceivable[]>('financial-entries'),
  listSales: () => readPersistent<LocalSaleRow[]>('sales'),
  listStock: () => readPersistent<LocalStockRow[]>('stock-balance'),
  listUnits: listLocalUnits,
  dashboard: () => readPersistent<Dashboard>('dashboard-summary'),
  prepareSale: denyPreparation as typeof prepareLocalSale,
  prepareSettlement: denyPreparation as typeof prepareLocalSettlement
});

function selectedFacade() {
  const mode = resolveVisualPersistenceMode(process.env.SERVER_VISUAL_PERSISTENCE_MODE);
  return selectVisualPersistence<VisualFacade>({ mode, synthetic: syntheticFacade, persistentReadOnly: persistentReadOnlyFacade });
}

export const visualPersistenceClient: VisualPersistenceClient = Object.freeze({
  execute: (command: CommandName, payload: Record<string, Json>, options?: { requestId?: string }) => selectedFacade().facade.client.execute(command, payload, options),
  read: (model: ReadModelName) => selectedFacade().facade.client.read(model)
});
export const listVisualCash = () => selectedFacade().facade.listCash();
export const listVisualCatalogItems = () => selectedFacade().facade.listCatalogItems();
export const listVisualParties = () => selectedFacade().facade.listParties();
export const listVisualReceivables = () => selectedFacade().facade.listReceivables();
export const listVisualSales = () => selectedFacade().facade.listSales();
export const listVisualStock = () => selectedFacade().facade.listStock();
export const listVisualUnits = () => selectedFacade().facade.listUnits();
export const visualDashboard = () => selectedFacade().facade.dashboard();
export const prepareVisualSale: typeof prepareLocalSale = (...args) => selectedFacade().facade.prepareSale(...args);
export const prepareVisualSettlement: typeof prepareLocalSettlement = (...args) => selectedFacade().facade.prepareSettlement(...args);
export const visualPersistenceMode = 'M18-G12 · feature flag server-side · persistência somente leitura · comandos remotos bloqueados';

export type { LocalCashRow as VisualCashRow, LocalReceivable as VisualReceivable } from './local';
