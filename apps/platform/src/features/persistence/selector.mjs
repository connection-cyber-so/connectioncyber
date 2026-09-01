const fail = code => { const error = new Error(code); error.code = code; throw error; };

export const persistentVisualTransportEnabled = false;

export function selectVisualPersistence({ mode, synthetic, persistent } = {}) {
  if (mode === 'synthetic') {
    if (!synthetic || typeof synthetic !== 'object') fail('SYNTHETIC_TRANSPORT_UNAVAILABLE');
    return Object.freeze({ mode, facade: synthetic, remote: false });
  }
  if (mode === 'persistent') {
    if (!persistentVisualTransportEnabled) fail('PERSISTENT_TRANSPORT_DISABLED');
    if (!persistent || typeof persistent !== 'object') fail('PERSISTENT_TRANSPORT_UNAVAILABLE');
    return Object.freeze({ mode, facade: persistent, remote: true });
  }
  fail('PERSISTENCE_MODE_INVALID');
}
