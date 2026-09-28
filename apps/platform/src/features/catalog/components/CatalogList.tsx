import type { CatalogItem, ItemCommercialData, ItemFiscalData, VerticalAttributeRequirement, Unit } from '../types';
import { ItemDetailPanel } from './ItemDetailPanel';

const kinds: Record<string, string> = { product: 'Produto', service: 'Serviço', part: 'Peça', ingredient: 'Ingrediente', prepared: 'Preparado', kit: 'Kit', supply: 'Insumo', fee: 'Taxa', voucher: 'Vale' };

// M20-G1/G2/G3 — cada item ganha um painel expansível com Fiscal/Comercial/Atributos.
export function CatalogList({ items, units, fiscalData, commercialData, verticalName, attributeRequirements }: { items: CatalogItem[]; units: Unit[]; fiscalData: ItemFiscalData[]; commercialData: ItemCommercialData[]; verticalName: string | null; attributeRequirements: VerticalAttributeRequirement[] }) {
  return (
    <>
      <div className="pf-page-header" style={{ marginTop: 24 }}><div><h2>Itens</h2><p>{items.length} item(ns) · {units.length} unidade(s)</p></div></div>
      {!items.length ? (
        <div className="pf-empty"><strong>Nenhum item cadastrado</strong>O catálogo universal atende todos os segmentos sem criar versões separadas.</div>
      ) : (
        <div className="pf-grid-2">
          {items.map((i) => (
            <article className="pf-content-card" style={{ marginBottom: 0 }} key={i.id}>
              <div className="pf-card-head">
                <div><h3 style={{ margin: '0 0 4px' }}>{i.name}</h3><span className="pf-pill">{kinds[i.kind]}</span></div>
                <strong>{i.code}</strong>
              </div>
              <p className="pf-muted">Unidade: {i.erp_units?.code ?? '—'} · {i.track_inventory ? 'com estoque' : 'sem estoque'}{i.allows_fraction ? ' · fracionado' : ''}</p>
              {i.description && <p className="pf-muted">{i.description}</p>}
              <ItemDetailPanel
                itemId={i.id}
                fiscal={fiscalData.find((f) => f.item_id === i.id)}
                commercial={commercialData.find((c) => c.item_id === i.id)}
                verticalName={verticalName}
                attributeRequirements={attributeRequirements}
              />
            </article>
          ))}
        </div>
      )}
    </>
  );
}
