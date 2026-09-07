import { listVisualCatalogItems,listVisualUnits,listVisualItemFiscalData,listVisualItemCommercialData,listVisualBusinessVerticals,listVisualVerticalAttributeRequirements,listVisualEstablishments,visualPersistenceMode } from '@/features/persistence/selected';import { ItemForm } from '@/features/catalog/components/CatalogForms';import { CatalogList } from '@/features/catalog/components/CatalogList';import { EstablishmentSwitcher } from '@/components/EstablishmentSwitcher';import { getSelectedEstablishmentId } from '@/lib/establishment-scope';
export const dynamic='force-dynamic';
export default async function CatalogoPage(){
  const[units,items,fiscalData,commercialData,verticals,attributeRequirements,establishments,selectedId]=await Promise.all([listVisualUnits(),listVisualCatalogItems(),listVisualItemFiscalData(),listVisualItemCommercialData(),listVisualBusinessVerticals(),listVisualVerticalAttributeRequirements(),listVisualEstablishments(),getSelectedEstablishmentId()]);
  // M20-G4 — sem seleção explícita, usa o primeiro estabelecimento como referência de
  // vertical pra aba Atributos (não filtra o catálogo, que é por tenant, não por loja).
  const activeEstablishment=establishments.find(e=>e.id===selectedId)??establishments[0]??null;
  const activeVertical=activeEstablishment?.vertical_code?verticals.find(v=>v.code===activeEstablishment.vertical_code)??null:null;
  const attributeRequirementsForVertical=activeVertical?attributeRequirements.filter(r=>r.vertical_code===activeVertical.code):[];
  return <>
    <div className="pf-page-header"><div><p className="pf-eyebrow">M18-G11 · M20-G1/G2/G3</p><h1>Catálogo universal</h1><p>Produtos, serviços, peças, ingredientes, preparados, kits, insumos, taxas e vales — com dado fiscal, comercial e atributos do segmento.</p></div></div>
    <p className="pf-notice"><strong>{visualPersistenceMode}.</strong> Unidade sintética UN disponível; os itens desaparecem ao reiniciar o servidor.</p>
    <EstablishmentSwitcher options={establishments.map(e=>({id:e.id,label:`${e.trade_name} (${e.code})`}))} selectedId={activeEstablishment?.id??null}/>
    <ItemForm units={units}/>
    <CatalogList items={items} units={units} fiscalData={fiscalData} commercialData={commercialData} verticalName={activeVertical?.name??null} attributeRequirements={attributeRequirementsForVertical}/>
  </>;
}
