const fail = code => { const error = new Error(code); error.code = code; throw error; };

export const persistentVisualWritesEnabled = false;

export function selectVisualPersistence({ mode, synthetic, persistentReadOnly } = {}) {
  if (mode === 'synthetic') {
    if (!synthetic || typeof synthetic !== 'object') fail('SYNTHETIC_TRANSPORT_UNAVAILABLE');
    return Object.freeze({ mode, facade: synthetic, remote: false });
  }
  if (mode === 'persistent-read-only') {
    if (!persistentReadOnly || typeof persistentReadOnly !== 'object') fail('PERSISTENT_READ_ONLY_TRANSPORT_UNAVAILABLE');
    return Object.freeze({ mode, facade: persistentReadOnly, remote: true, writes: false });
  }
  if (mode === 'persistent') {
    fail('PERSISTENT_WRITES_DISABLED');
  }
  fail('PERSISTENCE_MODE_INVALID');
}

export function resolveVisualPersistenceMode(value) {
  if (value === undefined || value === '' || value === 'synthetic') return 'synthetic';
  if (value === 'persistent-read-only') return value;
  fail('PERSISTENCE_MODE_INVALID');
}
