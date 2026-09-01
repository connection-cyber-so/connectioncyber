export declare const persistentVisualWritesEnabled: false;
export declare function selectVisualPersistence<T>(options?: {
  mode?: string;
  synthetic?: T;
  persistentReadOnly?: T;
}): Readonly<{ mode: string; facade: T; remote: boolean; writes?: boolean }>;
export declare function resolveVisualPersistenceMode(value?: string): 'synthetic' | 'persistent-read-only';
