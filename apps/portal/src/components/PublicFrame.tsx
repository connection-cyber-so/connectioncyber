import type { ReactNode } from 'react';
import { Brand } from '@/components/Brand';

export function PublicFrame({ children }: { children: ReactNode }) {
  return (
    <main className="public-shell">
      <section className="public-panel">
        <Brand />
        {children}
      </section>
      <aside className="public-aside" aria-label="Garantias do portal">
        <span className="eyebrow light">Portal empresarial</span>
        <h2>Uma estrutura segura para cada empresa.</h2>
        <p>
          O endereço identifica o contexto. A sessão e a membership confirmam o acesso.
        </p>
        <ul className="security-list">
          <li>Separação rigorosa entre empresas</li>
          <li>Sessão validada no servidor</li>
          <li>Dados protegidos por RLS</li>
        </ul>
      </aside>
    </main>
  );
}
