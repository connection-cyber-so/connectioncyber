import 'server-only';
import { selectVisualPersistence } from './selector.mjs';
import {
  listLocalCash,
  listLocalCatalogItems,
  listLocalParties,
  listLocalReceivables,
  listLocalSales,
  listLocalStock,
  listLocalUnits,
  localDashboard,
  localPersistenceClient,
  prepareLocalSale,
  prepareLocalSettlement
} from './local';

const syntheticFacade = Object.freeze({
  client: localPersistenceClient,
  listCash: listLocalCash,
  listCatalogItems: listLocalCatalogItems,
  listParties: listLocalParties,
  listReceivables: listLocalReceivables,
  listSales: listLocalSales,
  listStock: listLocalStock,
  listUnits: listLocalUnits,
  dashboard: localDashboard,
  prepareSale: prepareLocalSale,
  prepareSettlement: prepareLocalSettlement
});

const selection = selectVisualPersistence({ mode: 'synthetic', synthetic: syntheticFacade });

export const visualPersistenceClient = selection.facade.client;
export const listVisualCash = selection.facade.listCash;
export const listVisualCatalogItems = selection.facade.listCatalogItems;
export const listVisualParties = selection.facade.listParties;
export const listVisualReceivables = selection.facade.listReceivables;
export const listVisualSales = selection.facade.listSales;
export const listVisualStock = selection.facade.listStock;
export const listVisualUnits = selection.facade.listUnits;
export const visualDashboard = selection.facade.dashboard;
export const prepareVisualSale = selection.facade.prepareSale;
export const prepareVisualSettlement = selection.facade.prepareSettlement;
export const visualPersistenceMode = 'M18-G11 · seleção fail-closed · dublê sintético local · transporte remoto desativado';

export type { LocalCashRow as VisualCashRow, LocalReceivable as VisualReceivable } from './local';
