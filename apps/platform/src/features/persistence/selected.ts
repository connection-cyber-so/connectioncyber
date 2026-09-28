import 'server-only';
import type { CommandName, Json, ReadModelName, VisualPersistenceClient } from '../../../../../packages/visual-persistence-contract/src/server-client.mjs';
import type { SupabaseLike } from '../../../../../packages/visual-persistence-supabase-adapter/src/index.mjs';
import type { Party, PartyAddress, PartyContact, PartyDocument } from '@/features/parties/types';
import type { BusinessVertical, CatalogItem, ItemCommercialData, ItemFiscalData, Unit, VerticalAttributeRequirement } from '@/features/catalog/types';
import { createClient } from '@/lib/supabase/server';
import { getCurrentTenantId } from '@/lib/tenant';
import { createPersistentVisualClient } from './persistent';
import { resolveVisualPersistenceMode, selectVisualPersistence } from './selector.mjs';
import {
  listLocalCash, listLocalCatalogItems, listLocalItemCommercialData, listLocalItemFiscalData,
  listLocalBusinessVerticals, listLocalEstablishments, listLocalParties, listLocalPartyAddresses,
  listLocalPartyContacts, listLocalPartyDocuments, listLocalReceivables,
  listLocalSales, listLocalStock, listLocalUnits, listLocalVerticalAttributeRequirements, localDashboard,
  localPersistenceClient, prepareLocalSale, prepareLocalSettlement,
  type LocalCashRow, type LocalEstablishment, type LocalReceivable, type LocalSaleRow, type LocalStockRow
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
  // M20-G3
  listPartyDocuments(): Promise<PartyDocument[]>;
  listPartyContacts(): Promise<PartyContact[]>;
  listPartyAddresses(): Promise<PartyAddress[]>;
  listItemFiscalData(): Promise<ItemFiscalData[]>;
  listItemCommercialData(): Promise<ItemCommercialData[]>;
  listBusinessVerticals(): Promise<BusinessVertical[]>;
  listVerticalAttributeRequirements(): Promise<VerticalAttributeRequirement[]>;
  // M20-G4
  listEstablishments(): Promise<LocalEstablishment[]>;
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
const syntheticFacade: VisualFacade = Object.freeze({ client: localPersistenceClient, listCash: listLocalCash, listCatalogItems: listLocalCatalogItems, listParties: listLocalParties, listReceivables: listLocalReceivables, listSales: listLocalSales, listStock: listLocalStock, listUnits: listLocalUnits, dashboard: localDashboard, prepareSale: prepareLocalSale, prepareSettlement: prepareLocalSettlement,
  listPartyDocuments: listLocalPartyDocuments, listPartyContacts: listLocalPartyContacts, listPartyAddresses: listLocalPartyAddresses,
  listItemFiscalData: listLocalItemFiscalData, listItemCommercialData: listLocalItemCommercialData,
  listBusinessVerticals: listLocalBusinessVerticals, listVerticalAttributeRequirements: listLocalVerticalAttributeRequirements,
  listEstablishments: listLocalEstablishments,
});
// M21-G1 ("Trilha A") — cliente que de fato executa comandos contra o Supabase, em vez
// de recusar tudo como `blockedClient`. Continua derivando tenant da sessão via
// getCurrentTenantId() (nunca de formulário/query string) e usa o mesmo `createClient()`
// de sempre, com a sessão do próprio usuário autenticado (chave anônima + cookies).
const persistentWritableClient: VisualPersistenceClient = Object.freeze({
  execute: (command: CommandName, payload: Record<string, Json>, options?: { requestId?: string }) => persistentClient().then(client => client.execute(command, payload, options)),
  read: (model: ReadModelName) => persistentClient().then(client => client.read(model))
});

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
  prepareSettlement: denyPreparation as typeof prepareLocalSettlement,
  listPartyDocuments: () => readPersistent<PartyDocument[]>('party-documents'),
  listPartyContacts: () => readPersistent<PartyContact[]>('party-contacts'),
  listPartyAddresses: () => readPersistent<PartyAddress[]>('party-addresses'),
  listItemFiscalData: () => readPersistent<ItemFiscalData[]>('item-fiscal-data'),
  listItemCommercialData: () => readPersistent<ItemCommercialData[]>('item-commercial-data'),
  listBusinessVerticals: () => readPersistent<BusinessVertical[]>('business-verticals'),
  listVerticalAttributeRequirements: () => readPersistent<VerticalAttributeRequirement[]>('vertical-attribute-requirements'),
  listEstablishments: () => readPersistent<LocalEstablishment[]>('establishments'),
});

// Mesmas leituras do modo somente leitura (ler não muda com a capacidade de escrever) —
// só o `client` troca, de `blockedClient` (recusa tudo) para o transporte real acima.
const persistentWritableFacade: VisualFacade = Object.freeze({ ...persistentReadOnlyFacade, client: persistentWritableClient });

function selectedFacade() {
  const mode = resolveVisualPersistenceMode(process.env.SERVER_VISUAL_PERSISTENCE_MODE);
  return selectVisualPersistence<VisualFacade>({ mode, synthetic: syntheticFacade, persistentReadOnly: persistentReadOnlyFacade, persistentWritable: persistentWritableFacade });
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
// M21-G1 — o rótulo agora reflete o modo de verdade resolvido do ambiente, em vez de um
// texto fixo que sempre dizia "comandos remotos bloqueados" mesmo com escrita real ligada.
const resolvedVisualPersistenceMode = resolveVisualPersistenceMode(process.env.SERVER_VISUAL_PERSISTENCE_MODE);
export const visualPersistenceMode = resolvedVisualPersistenceMode === 'persistent'
  ? 'M21-G1 · escrita real habilitada · comandos gravam no Supabase'
  : resolvedVisualPersistenceMode === 'persistent-read-only'
    ? 'M18-G12 · feature flag server-side · persistência somente leitura · comandos remotos bloqueados'
    : 'M18-G12 · feature flag server-side · síntetico em memória · comandos remotos bloqueados';
export const isWritePersistenceEnabled = resolvedVisualPersistenceMode === 'persistent';

// M20-G3
export const listVisualPartyDocuments = () => selectedFacade().facade.listPartyDocuments();
export const listVisualPartyContacts = () => selectedFacade().facade.listPartyContacts();
export const listVisualPartyAddresses = () => selectedFacade().facade.listPartyAddresses();
export const listVisualItemFiscalData = () => selectedFacade().facade.listItemFiscalData();
export const listVisualItemCommercialData = () => selectedFacade().facade.listItemCommercialData();
export const listVisualBusinessVerticals = () => selectedFacade().facade.listBusinessVerticals();
export const listVisualVerticalAttributeRequirements = () => selectedFacade().facade.listVerticalAttributeRequirements();
// M20-G4
export const listVisualEstablishments = () => selectedFacade().facade.listEstablishments();

export type { LocalCashRow as VisualCashRow, LocalEstablishment as VisualEstablishment, LocalReceivable as VisualReceivable } from './local';
