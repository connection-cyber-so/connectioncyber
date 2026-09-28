import { setEstablishmentScopeAction } from '@/features/establishments/actions';

export interface EstablishmentSwitcherOption { id: string; label: string }

// M20-G4 — seletor de estabelecimento (individual/todas as lojas). Formulário 100%
// servidor, sem JS de cliente (mesmo padrão do M19-G4) — troca de loja é sempre uma
// navegação normal, nunca um estado só no browser.
export function EstablishmentSwitcher({ options, selectedId }: { options: EstablishmentSwitcherOption[]; selectedId: string | null }) {
  if (!options.length) return null;
  return (
    <form action={setEstablishmentScopeAction} className="pf-establishment-switcher">
      <label htmlFor="establishment_id">Estabelecimento</label>
      <select id="establishment_id" name="establishment_id" defaultValue={selectedId ?? 'all'}>
        <option value="all">Todas as lojas</option>
        {options.map((option) => (
          <option key={option.id} value={option.id}>{option.label}</option>
        ))}
      </select>
      <button className="pf-button" type="submit">Aplicar</button>
    </form>
  );
}
