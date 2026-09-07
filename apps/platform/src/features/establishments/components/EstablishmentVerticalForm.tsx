'use client';
import { useFormState, useFormStatus } from 'react-dom';
import { setEstablishmentVerticalAction, type EstablishmentActionState } from '../actions';
import type { LocalEstablishment } from '@/features/persistence/local';
import type { BusinessVertical } from '@/features/catalog/types';

const initial: EstablishmentActionState = { error: null, success: false };
function Submit() {
  const { pending } = useFormStatus();
  return <button className="pf-button" type="submit" disabled={pending}>{pending ? 'Salvando…' : 'Salvar vertical'}</button>;
}

// M20-G2/G4 — atribui a vertical de negócio (M20-G2) a cada estabelecimento (M20-G4).
export function EstablishmentVerticalForm({ establishments, verticals }: { establishments: LocalEstablishment[]; verticals: BusinessVertical[] }) {
  const [state, action] = useFormState(setEstablishmentVerticalAction, initial);
  if (!establishments.length) return null;
  return (
    <section className="pf-content-card">
      <h2>Vertical por estabelecimento</h2>
      <p className="pf-muted">Define quais atributos de segmento (M20-G2) aparecem no cadastro de item de cada loja.</p>
      <form action={action}>
        <div className="pf-grid-2">
          <div className="pf-field">
            <label>Estabelecimento</label>
            <select name="establishment_id" defaultValue={establishments[0]?.id}>
              {establishments.map((e) => <option key={e.id} value={e.id}>{e.trade_name} ({e.code})</option>)}
            </select>
          </div>
          <div className="pf-field">
            <label>Vertical</label>
            <select name="vertical_code" defaultValue={establishments[0]?.vertical_code ?? ''}>
              <option value="">Não definida</option>
              {verticals.map((v) => <option key={v.code} value={v.code}>{v.name}</option>)}
            </select>
          </div>
        </div>
        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Vertical atualizada.</p>}
        <Submit />
      </form>
      <ul className="pf-mini-list">
        {establishments.map((e) => <li key={e.id}><strong>{e.trade_name}</strong> ({e.code}): {verticals.find((v) => v.code === e.vertical_code)?.name ?? 'sem vertical'}</li>)}
      </ul>
    </section>
  );
}
