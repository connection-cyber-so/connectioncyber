const deepFreeze = value => { if (value && typeof value === 'object' && !Object.isFrozen(value)) { Object.freeze(value); for (const nested of Object.values(value)) deepFreeze(nested); } return value; };

export const POSTGRES_CONTRACT_VERSION = 'M17-PG-1.0';
export const BASELINE_MIGRATIONS = deepFreeze([
  { version: '0021', domain: 'parties_catalog', disposition: 'reuse-and-wrap' },
  { version: '0022', domain: 'pricing_stock_purchasing', disposition: 'reuse-and-wrap' },
  { version: '0023', domain: 'sales_pos', disposition: 'reuse-and-harden' },
  { version: '0024', domain: 'finance_banking', disposition: 'reuse-and-harden' },
  { version: '0032', domain: 'tenant_capabilities', disposition: 'reuse' },
]);

export const PERSISTENCE_TABLE_CONTRACT = deepFreeze({
  commandReceipts: {
    disposition: 'planned-new', table: 'erp_command_receipts', tenantScoped: true, rls: true,
    columns: ['tenant_id', 'command_type', 'request_id', 'payload_hash', 'status', 'result_json', 'error_code', 'actor_id', 'created_at', 'completed_at'],
    constraints: ['primary-key:id', 'unique:tenant_id+command_type+request_id', 'check:payload_hash_sha256', 'check:terminal_result_consistency'],
  },
  parties: { disposition: 'existing', table: 'erp_parties', tenantScoped: true, rls: true },
  catalog: { disposition: 'existing', table: 'erp_items', tenantScoped: true, rls: true },
  inventory: { disposition: 'existing', table: 'erp_stock_movements', child: 'erp_stock_movement_items', tenantScoped: true, rls: true },
  cash: { disposition: 'existing', table: 'erp_cash_sessions', movement: 'erp_cash_movements', tenantScoped: true, rls: true },
  sales: { disposition: 'existing', table: 'erp_sales', children: ['erp_sale_items', 'erp_sale_payments'], tenantScoped: true, rls: true },
  finance: { disposition: 'existing', table: 'erp_financial_entries', children: ['erp_installments', 'erp_settlements', 'erp_settlement_allocations', 'erp_financial_movements'], tenantScoped: true, rls: true },
});

const common = { execution: 'single-database-transaction', security: 'security-definer-search-path-empty', caller: 'authenticated-server-broker', tenantSource: 'server-resolved-host', actorSource: 'auth.uid', idempotency: 'command-receipt-hash-checked', errorSurface: 'stable-public-code' };
export const RPC_CONTRACTS = deepFreeze({
  'party.create': { ...common, rpc: 'erp_command_create_party_v1', permission: 'parties.manage', capability: 'core.parties', locks: ['command-receipt'], writes: ['erp_command_receipts', 'erp_parties'] },
  'catalog.item.create': { ...common, rpc: 'erp_command_create_catalog_item_v1', permission: 'catalog.manage', capability: 'core.catalog', locks: ['command-receipt'], writes: ['erp_command_receipts', 'erp_items'] },
  'inventory.receive': { ...common, rpc: 'erp_command_receive_inventory_v1', permission: 'inventory.manage', capability: 'inventory.stock', locks: ['command-receipt', 'stock-key-ordered'], writes: ['erp_command_receipts', 'erp_stock_movements', 'erp_stock_movement_items'] },
  'cash.open': { ...common, rpc: 'erp_command_open_cash_v1', permission: 'cash.manage', capability: 'sales.pos', locks: ['command-receipt', 'cash-register'], writes: ['erp_command_receipts', 'erp_cash_sessions', 'erp_cash_movements'] },
  'sale.complete': { ...common, rpc: 'erp_command_complete_sale_v1', permission: 'sales.manage', capability: 'sales.pos', locks: ['command-receipt', 'cash-session', 'stock-keys-ordered'], writes: ['erp_command_receipts', 'erp_sales', 'erp_sale_items', 'erp_sale_payments', 'erp_stock_movements', 'erp_stock_movement_items', 'erp_cash_movements', 'erp_financial_entries', 'erp_installments'] },
  'finance.receivable.settle': { ...common, rpc: 'erp_command_settle_receivable_v1', permission: 'finance.manage', capability: 'finance', locks: ['command-receipt', 'installment-keys-ordered'], writes: ['erp_command_receipts', 'erp_settlements', 'erp_settlement_allocations', 'erp_financial_movements', 'erp_installments', 'erp_financial_entries'] },
  'cash.close': { ...common, rpc: 'erp_command_close_cash_v1', permission: 'cash.manage', capability: 'sales.pos', locks: ['command-receipt', 'cash-session'], writes: ['erp_command_receipts', 'erp_cash_sessions'] },
});

export const TRANSACTION_PROTOCOL = deepFreeze([
  'begin-rpc-transaction',
  'resolve-auth-uid-membership-permission-capability',
  'lock-or-create-command-receipt',
  'compare-payload-hash-or-replay-terminal-result',
  'acquire-aggregate-locks-in-canonical-order',
  'read-and-validate-current-state',
  'derive-prices-totals-balances-and-tenant-on-server',
  'write-aggregate-event-and-derived-records',
  'reconcile-invariants',
  'complete-command-receipt',
  'commit-or-rollback-entire-rpc',
]);

export const DATABASE_INVARIANTS = deepFreeze([
  'every-domain-row-has-tenant-id', 'every-cross-table-fk-includes-tenant-id', 'rls-enabled-on-every-tenant-table',
  'authenticated-has-no-direct-domain-write', 'rpc-validates-membership-permission-and-capability', 'service-role-never-reaches-browser',
  'one-request-one-payload-hash', 'terminal-replay-returns-stored-result', 'failed-transaction-leaves-no-receipt-or-domain-write',
  'stock-never-negative', 'one-open-cash-session-per-register', 'sale-total-derived-from-catalog-snapshots',
  'cash-movement-only-for-cash-equivalent-payment', 'sale-financial-projection-is-exactly-once', 'settlement-never-exceeds-open-balance',
  'money-uses-numeric-19-4-in-database-and-integer-cents-at-boundary', 'locks-are-tenant-prefixed-and-canonically-ordered',
  'rpc-search-path-is-empty-and-object-names-are-qualified', 'error-response-excludes-sql-detail', 'audit-excludes-payload-and-secrets',
]);

export const CONCURRENCY_POLICY = deepFreeze({ isolation: 'read-committed-with-explicit-locks', deadlockPrevention: 'sort-lock-keys-lexicographically', optimisticVersionRequiredFor: ['mutable-draft-sale', 'cash-session', 'financial-entry'], retryableSqlStates: ['40001', '40P01'], maxServerRetries: 2, browserRetriesWrites: false });
export const ROLLBACK_POLICY = deepFreeze({ boundary: 'entire-rpc', compensatingWritesInsideFailurePath: false, receiptCommittedWithFailure: false, externalSideEffectsAllowed: false, outboxRequiredBeforeFutureExternalEffects: true });
export const RELEASE_GATES = deepFreeze(['local-contract-tests', 'independent-sql-audit', 'migration-preflight', 'transactional-rollback-validation', 'pgtap-tenant-isolation', 'pgtap-concurrency', 'persistent-staging-application', 'post-apply-reconciliation']);

export function validatePostgresPersistenceContract() {
  const findings = [];
  const commands = Object.entries(RPC_CONTRACTS);
  if (commands.length !== 7) findings.push('seven-command-coverage');
  for (const [command, rpc] of commands) {
    if (!rpc.rpc.endsWith('_v1')) findings.push(`${command}:versioned-rpc`);
    if (rpc.security !== 'security-definer-search-path-empty') findings.push(`${command}:secure-search-path`);
    if (rpc.locks[0] !== 'command-receipt') findings.push(`${command}:receipt-first-lock`);
    if (!rpc.writes.includes('erp_command_receipts')) findings.push(`${command}:receipt-write`);
    if (!rpc.permission || !rpc.capability) findings.push(`${command}:authorization-policy`);
  }
  for (const [name, table] of Object.entries(PERSISTENCE_TABLE_CONTRACT)) if (!table.tenantScoped || !table.rls) findings.push(`${name}:tenant-rls`);
  if (ROLLBACK_POLICY.externalSideEffectsAllowed || ROLLBACK_POLICY.receiptCommittedWithFailure) findings.push('atomic-rollback');
  return deepFreeze({ valid: findings.length === 0, findings, commands: commands.length, tables: Object.keys(PERSISTENCE_TABLE_CONTRACT).length, migrationCreated: false, remoteAccessed: false, productionAccessed: false });
}
