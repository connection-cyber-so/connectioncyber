import '@/styles/cc-classic.css';
import { listVisualEstablishments } from '@/features/persistence/selected';
import { EstablishmentSwitcher } from '@/components/EstablishmentSwitcher';
import { getSelectedEstablishmentId } from '@/lib/establishment-scope';
import { CadastroSwitchBar } from '@/components/CadastroSwitchBar';

export const dynamic = 'force-dynamic';

// M21-G5 — mesma tela real de Empresa do apps/portal (M21-G4), reaproveitada aqui pro
// apps/platform: dado da empresa (razão social/CNPJ) é a fonte usada por qualquer
// processo (fiscal, cadastro, venda). Leitura real (listVisualEstablishments), sem
// edição de CNPJ/razão social ainda — mesmo gap documentado no portal (dado sensível,
// muda só por suporte/migration por enquanto).
export default async function EmpresaPage() {
  const [establishments, selectedId] = await Promise.all([listVisualEstablishments(), getSelectedEstablishmentId()]);
  const active = establishments.find((e) => e.id === selectedId) ?? establishments[0] ?? null;

  return (
    <div className="cc-classic">
      <div className="window">
        <div className="header-bar">
          <div className="header-title"><div className="eyebrow">ConnectionCyber · Cadastros ERP</div><h1>Cadastro da empresa</h1></div>
          <CadastroSwitchBar active="empresa" />
        </div>
        <div className="body">
          <EstablishmentSwitcher options={establishments.map((e) => ({ id: e.id, label: `${e.trade_name} (${e.code})` }))} selectedId={active?.id ?? null} />
          {active ? (
            <div style={{ marginTop: 16 }}>
              <p className="grp-label">Dados da empresa emitente</p>
              <div className="row2">
                <div className="field"><label>Razão social</label><input value={active.legal_name ?? ''} disabled placeholder="Não informado" /></div>
                <div className="field"><label>Nome fantasia</label><input value={active.trade_name} disabled /></div>
              </div>
              <div className="row2">
                <div className="field"><label>CNPJ</label><input value={active.cnpj ?? ''} disabled placeholder="Não informado" /></div>
                <div className="field"><label>Segmento</label><input value={active.vertical_code ?? ''} disabled placeholder="Não definido" /></div>
              </div>
              <p className="hint">
                Edição de CNPJ/razão social ainda não tem tela própria (dado sensível, muda só
                por suporte/migration por enquanto). O que aparece aqui é o que já está gravado.
              </p>
            </div>
          ) : (
            <p className="hint">Nenhum estabelecimento encontrado.</p>
          )}
        </div>
      </div>
    </div>
  );
}
