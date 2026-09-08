export declare const persistentVisualWritesEnabled: true;
export declare function selectVisualPersistence<T>(options?: {
  mode?: string;
  synthetic?: T;
  persistentReadOnly?: T;
  persistentWritable?: T;
}): Readonly<{ mode: string; facade: T; remote: boolean; writes?: boolean }>;
export declare function resolveVisualPersistenceMode(value?: string): 'synthetic' | 'persistent-read-only' | 'persistent';
