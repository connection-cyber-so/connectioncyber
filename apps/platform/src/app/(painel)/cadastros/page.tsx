import '@/styles/cc-classic.css';import { listVisualParties,listVisualPartyDocuments,listVisualPartyContacts,listVisualPartyAddresses,listVisualEstablishments,visualPersistenceMode,isWritePersistenceEnabled } from '@/features/persistence/selected';import { PartyForm } from '@/features/parties/components/PartyForm';import { PartyList } from '@/features/parties/components/PartyList';import { CadastroSwitchBar } from '@/components/CadastroSwitchBar';
export const dynamic='force-dynamic';export default async function CadastrosPage(){const[parties,documents,contacts,addresses,establishments]=await Promise.all([listVisualParties(),listVisualPartyDocuments(),listVisualPartyContacts(),listVisualPartyAddresses(),listVisualEstablishments()]);
  // M21-G5 — mesma regra do apps/portal (M21-G4): dado da empresa é a fonte usada por
  // qualquer processo; aviso (não bloqueio) quando incompleto, aponta pra /empresa.
  const establishment=establishments[0]??null;const empresaIncompleta=!establishment||!establishment.cnpj||!establishment.trade_name;
  return <div className="cc-classic"><div className="window"><div className="header-bar"><div className="header-title"><div className="eyebrow">ConnectionCyber · Cadastros ERP</div><h1>Cadastro de pessoa</h1></div><CadastroSwitchBar active="cliente"/><span className="spacer"></span><span className="pill">{parties.length} cadastro(s)</span></div>
  {empresaIncompleta?<div className="gate-banner">Os dados da empresa ainda não estão completos — são a fonte usada por qualquer processo (fiscal, vendas, cadastro). <a href="/empresa">Completar agora →</a></div>:null}
  <div className="body">
    <p className="pf-notice"><strong>{visualPersistenceMode}.</strong> {isWritePersistenceEnabled ? 'Os registros gravam de verdade no Supabase.' : 'Os registros desaparecem ao reiniciar o servidor.'}</p>
    <PartyForm/><PartyList parties={parties} documents={documents} contacts={contacts} addresses={addresses}/>
  </div>
  </div></div>}
