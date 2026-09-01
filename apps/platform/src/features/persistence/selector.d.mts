export declare const persistentVisualTransportEnabled: false;
export declare function selectVisualPersistence<T>(options?: {
  mode?: string;
  synthetic?: T;
  persistent?: T;
}): Readonly<{ mode: string; facade: T; remote: boolean }>;
