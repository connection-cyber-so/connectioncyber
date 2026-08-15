import type { Diagnostic } from '../types';
import { DiagnosticCard } from './DiagnosticCard';

export function DiagnosticList({ diagnostics }: { diagnostics: Diagnostic[] }) {
  if (diagnostics.length === 0) {
    return (
      <div className="pf-empty">
        <strong>Nenhum diagnóstico ainda</strong>
        Preencha o formulário acima para gerar o primeiro diagnóstico deste cliente.
      </div>
    );
  }

  return (
    <div className="pf-grid-2">
      {diagnostics.map((diagnostic) => (
        <DiagnosticCard key={diagnostic.id} diagnostic={diagnostic} />
      ))}
    </div>
  );
}
