import{SalesOverview}from'@/features/sales/components/SalesOverview';import{listQuotes,listSales}from'@/features/sales/service';import{listEstablishments}from'@/features/establishments/service';import{createClient}from'@/lib/supabase/server';import{requireCurrentTenantId}from'@/lib/tenant';import{EstablishmentSwitcher}from'@/components/EstablishmentSwitcher';import{getSelectedEstablishmentId}from'@/lib/establishment-scope';
export const dynamic='force-dynamic';
export default async function SalesPage(){
  const c=await createClient(),t=await requireCurrentTenantId(),selectedId=await getSelectedEstablishmentId();
  try{
    const establishments=await listEstablishments(c,t);
    const[quotes,sales]=await Promise.all([listQuotes(c,t,selectedId),listSales(c,t,selectedId)]);
    return <>
      <div className="pf-page-header"><div><p className="pf-eyebrow">M07 · M20-G4</p><h1>Orçamentos e vendas</h1><p>Documentos comerciais isolados por empresa, filtráveis por loja.</p></div></div>
      <EstablishmentSwitcher options={establishments.map(e=>({id:e.id,label:`${e.trade_name} (${e.code})`}))} selectedId={selectedId}/>
      <SalesOverview quotes={quotes} sales={sales}/>
    </>;
  }catch{
    return <div className="pf-content-card"><h1>Orçamentos e vendas</h1><p className="pf-notice">Módulo preparado. A estrutura será habilitada após o portão da migration 0023.</p></div>;
  }
}
