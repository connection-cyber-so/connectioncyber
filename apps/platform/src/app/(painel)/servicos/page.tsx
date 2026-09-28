import{ServicesOverview}from'@/features/services/components/ServicesOverview';import{listAppointments,listAssets,listServiceOrders}from'@/features/services/service';import{listEstablishments}from'@/features/establishments/service';import{createClient}from'@/lib/supabase/server';import{requireCurrentTenantId}from'@/lib/tenant';import{EstablishmentSwitcher}from'@/components/EstablishmentSwitcher';import{getSelectedEstablishmentId}from'@/lib/establishment-scope';
export const dynamic='force-dynamic';
export default async function ServicesPage(){
  const c=await createClient(),t=await requireCurrentTenantId(),selectedId=await getSelectedEstablishmentId();
  try{
    const establishments=await listEstablishments(c,t);
    const[orders,appointments,assets]=await Promise.all([listServiceOrders(c,t,selectedId),listAppointments(c,t,selectedId),listAssets(c,t)]);
    return <>
      <div className="pf-page-header"><div><p className="pf-eyebrow">M09 · M20-G4</p><h1>Serviços e oficinas</h1><p>Agenda, ativos, inspeções, ordens de serviço e garantias por empresa, filtráveis por loja.</p></div></div>
      <EstablishmentSwitcher options={establishments.map(e=>({id:e.id,label:`${e.trade_name} (${e.code})`}))} selectedId={selectedId}/>
      <ServicesOverview orders={orders} appointments={appointments} assets={assets}/>
    </>;
  }catch{
    return <div className="pf-content-card"><h1>Serviços e oficinas</h1><p className="pf-notice">Módulo preparado. A estrutura será habilitada após o portão da migration 0025.</p></div>;
  }
}
