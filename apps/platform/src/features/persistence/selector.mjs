const fail = code => { const error = new Error(code); error.code = code; throw error; };

// M21-G1 ("Trilha A"): usuário autorizou explicitamente habilitar escrita real — antes
// disso, este flag ficava travado em `false` e um teste (m18-g11-fail-closed-selection)
// garantia que `mode:'persistent'` falhava fechado SEM sequer tocar o dublê passado. Esse
// teste foi atualizado junto (ver RELATORIO-M21-G1-*.md) para provar o caminho de sucesso
// em vez do de bloqueio — a escrita real só acontece se `SERVER_VISUAL_PERSISTENCE_MODE`
// for explicitamente setado para 'persistent' no ambiente (nunca é o valor padrão).
export const persistentVisualWritesEnabled = true;

export function selectVisualPersistence({ mode, synthetic, persistentReadOnly, persistentWritable } = {}) {
  if (mode === 'synthetic') {
    if (!synthetic || typeof synthetic !== 'object') fail('SYNTHETIC_TRANSPORT_UNAVAILABLE');
    return Object.freeze({ mode, facade: synthetic, remote: false });
  }
  if (mode === 'persistent-read-only') {
    if (!persistentReadOnly || typeof persistentReadOnly !== 'object') fail('PERSISTENT_READ_ONLY_TRANSPORT_UNAVAILABLE');
    return Object.freeze({ mode, facade: persistentReadOnly, remote: true, writes: false });
  }
  if (mode === 'persistent') {
    if (!persistentWritable || typeof persistentWritable !== 'object') fail('PERSISTENT_WRITABLE_TRANSPORT_UNAVAILABLE');
    return Object.freeze({ mode, facade: persistentWritable, remote: true, writes: true });
  }
  fail('PERSISTENCE_MODE_INVALID');
}

export function resolveVisualPersistenceMode(value) {
  if (value === undefined || value === '' || value === 'synthetic') return 'synthetic';
  if (value === 'persistent-read-only' || value === 'persistent') return value;
  fail('PERSISTENCE_MODE_INVALID');
}
