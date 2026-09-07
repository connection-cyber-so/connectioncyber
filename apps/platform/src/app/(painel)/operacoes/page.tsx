import{LocalInventoryForm}from'@/features/operations/components/LocalInventoryForm';import{listVisualCatalogItems,listVisualStock,listVisualEstablishments,listVisualBusinessVerticals,visualPersistenceMode}from'@/features/persistence/selected';import{EstablishmentSwitcher}from'@/components/EstablishmentSwitcher';import{getSelectedEstablishmentId}from'@/lib/establishment-scope';import{EstablishmentVerticalForm}from'@/features/establishments/components/EstablishmentVerticalForm';
export const dynamic='force-dynamic';
export default async function OperationsPage(){
  const[items,stock,establishments,verticals,selectedId]=await Promise.all([listVisualCatalogItems(),listVisualStock(),listVisualEstablishments(),listVisualBusinessVerticals(),getSelectedEstablishmentId()]);
  const tracked=items.filter(item=>item.track_inventory);
  return<>
    <div className="pf-page-header"><div><p className="pf-eyebrow">M18-G11 · M20-G4</p><h1>Estoque</h1><p>Recebimento pela fronteira server-side com saldo relido após a operação.</p></div></div>
    <p className="pf-notice"><strong>{visualPersistenceMode}.</strong> Os saldos desaparecem ao reiniciar o servidor.</p>
    <EstablishmentSwitcher options={establishments.map(e=>({id:e.id,label:`${e.trade_name} (${e.code})`}))} selectedId={selectedId}/>
    {selectedId&&<p className="pf-muted">Saldo mostrado é consolidado de todas as lojas — o transporte sintético (M18-G5) ainda não fragmenta estoque por estabelecimento; a filtragem real chega junto com a materialização de dado real por loja.</p>}
    <LocalInventoryForm items={tracked}/>
    <EstablishmentVerticalForm establishments={establishments} verticals={verticals}/>
    <section className="pf-content-card"><h2>Saldos atuais</h2>{!stock.length?<p>Nenhum produto com estoque.</p>:stock.map(row=><p key={row.itemId}><strong>{row.code} — {row.name}</strong>: {row.quantity} UN</p>)}</section>
  </>;
}
