'use client';
import { useActionState } from 'react';import { useFormStatus } from 'react-dom';
import { setItemCommercialAction, setItemFiscalAction, type CatalogState } from '../actions';
import type { ItemCommercialData, ItemFiscalData, VerticalAttributeRequirement } from '../types';

const initial: CatalogState = { error: null, success: false };
function Submit({ label }: { label: string }) {
  const { pending } = useFormStatus();
  return <button className="pf-button" type="submit" disabled={pending}>{pending ? 'Salvando…' : label}</button>;
}

// M20-G1/G3 — aba Fiscal: NCM/CEST/origem/CST-CSOSN/alíquotas/peso, ver
// PARECER-TECNICO-M20-G0 seção 6 (tabela satélite erp_item_fiscal_data).
function FiscalSection({ itemId, current }: { itemId: string; current: ItemFiscalData | undefined }) {
  const [state, action] = useActionState(setItemFiscalAction, initial);
  return (
    <div className="pf-detail-section">
      <h4>Fiscal</h4>
      <form action={action}>
        <input type="hidden" name="item_id" value={itemId} />
        <div className="pf-grid-2">
          <div className="pf-field"><label>NCM</label><input name="ncm" required maxLength={8} defaultValue={current?.ncm} placeholder="00000000" /></div>
          <div className="pf-field"><label>CEST (opcional)</label><input name="cest" maxLength={7} defaultValue={current?.cest ?? ''} /></div>
        </div>
        <div className="pf-grid-2">
          <div className="pf-field"><label>Regime</label><select name="tax_code_kind" defaultValue={current?.tax_code_kind ?? 'CSOSN'}><option value="CSOSN">Simples Nacional (CSOSN)</option><option value="CST">Normal/RPA (CST)</option></select></div>
          <div className="pf-field"><label>Código</label><input name="tax_code" required maxLength={3} defaultValue={current?.tax_code} placeholder="ex.: 102 ou 00" /></div>
        </div>
        <div className="pf-grid-2">
          <div className="pf-field"><label>Origem (0-8)</label><input name="origin" type="number" min={0} max={8} defaultValue={current?.origin ?? 0} /></div>
          <div className="pf-field"><label>Alíquota ICMS (%)</label><input name="icms_rate" type="number" step="0.01" min={0} max={100} defaultValue={current?.icms_rate ?? 0} /></div>
        </div>
        <div className="pf-grid-2">
          <div className="pf-field"><label>Base de cálculo ICMS (%)</label><input name="icms_base_percent" type="number" step="0.01" min={0} max={100} defaultValue={current?.icms_base_percent ?? 100} /></div>
          <div className="pf-field"><label>Alíquota IPI (%)</label><input name="ipi_rate" type="number" step="0.01" min={0} max={100} defaultValue={current?.ipi_rate ?? 0} /></div>
        </div>
        <div className="pf-grid-2">
          <div className="pf-field"><label>Peso bruto (kg, opcional)</label><input name="gross_weight" type="number" step="0.001" min={0} defaultValue={current?.gross_weight ?? ''} /></div>
          <div className="pf-field"><label>Peso líquido (kg, opcional)</label><input name="net_weight" type="number" step="0.001" min={0} defaultValue={current?.net_weight ?? ''} /></div>
        </div>
        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Dado fiscal salvo.</p>}
        <Submit label={current ? 'Atualizar fiscal' : 'Salvar fiscal'} />
      </form>
    </div>
  );
}

// M20-G1/G3 — aba Comercial: custo/margem/preço sugerido/estoque mínimo/reposição.
function CommercialSection({ itemId, current }: { itemId: string; current: ItemCommercialData | undefined }) {
  const [state, action] = useActionState(setItemCommercialAction, initial);
  return (
    <div className="pf-detail-section">
      <h4>Comercial</h4>
      <form action={action}>
        <input type="hidden" name="item_id" value={itemId} />
        <div className="pf-grid-2">
          <div className="pf-field"><label>Preço de custo</label><input name="cost_price" type="number" step="0.01" min={0} defaultValue={current?.cost_price ?? 0} /></div>
          <div className="pf-field"><label>Margem de lucro (%)</label><input name="margin_percent" type="number" step="0.01" min={0} defaultValue={current?.margin_percent ?? 0} /></div>
        </div>
        <div className="pf-grid-2">
          <div className="pf-field"><label>Preço de venda sugerido (opcional)</label><input name="suggested_sale_price" type="number" step="0.01" min={0} defaultValue={current?.suggested_sale_price ?? ''} /></div>
          <div className="pf-field"><label>Estoque mínimo</label><input name="min_stock_quantity" type="number" step="0.001" min={0} defaultValue={current?.min_stock_quantity ?? 0} /></div>
        </div>
        <div className="pf-field"><label>Ponto de reposição (opcional)</label><input name="reorder_point" type="number" step="0.001" min={0} defaultValue={current?.reorder_point ?? ''} /></div>
        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Dado comercial salvo.</p>}
        <Submit label={current ? 'Atualizar comercial' : 'Salvar comercial'} />
      </form>
    </div>
  );
}

// M20-G2/G3 — aba Atributos do segmento: informativa por enquanto. A materialização
// real em erp_attributes/erp_item_attribute_values por tenant fica para um portão de
// provisionamento futuro (já declarado assim no RELATORIO-M20-G2).
function AttributesSection({ verticalName, requirements }: { verticalName: string | null; requirements: VerticalAttributeRequirement[] }) {
  return (
    <div className="pf-detail-section">
      <h4>Atributos do segmento{verticalName ? ` — ${verticalName}` : ''}</h4>
      {!verticalName ? (
        <p className="pf-muted">Nenhuma vertical definida para o estabelecimento selecionado (seletor no topo da página).</p>
      ) : !requirements.length ? (
        <p className="pf-muted">Esta vertical não exige campo extra além do fiscal/comercial universal.</p>
      ) : (
        <ul className="pf-mini-list">
          {requirements.map((req) => (
            <li key={req.attribute_code}>
              <strong>{req.attribute_name}</strong> ({req.data_type}){req.required && <span className="pf-required"> obrigatório</span>}
            </li>
          ))}
        </ul>
      )}
      <p className="pf-muted">Preenchimento por item chega no portão de materialização do atributo (M20, próxima etapa) — aqui é a exigência da vertical.</p>
    </div>
  );
}

export function ItemDetailPanel({ itemId, fiscal, commercial, verticalName, attributeRequirements }: { itemId: string; fiscal: ItemFiscalData | undefined; commercial: ItemCommercialData | undefined; verticalName: string | null; attributeRequirements: VerticalAttributeRequirement[] }) {
  return (
    <details className="pf-detail-item">
      <summary>Fiscal, comercial e atributos do segmento</summary>
      <FiscalSection itemId={itemId} current={fiscal} />
      <CommercialSection itemId={itemId} current={commercial} />
      <AttributesSection verticalName={verticalName} requirements={attributeRequirements} />
    </details>
  );
}
