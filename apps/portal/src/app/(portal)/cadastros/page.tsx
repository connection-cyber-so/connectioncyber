import { notFound, redirect } from 'next/navigation';
import { loadPortalAccess } from '@/lib/portal-context';
import { getPortalVisualClient } from '@/features/persistence/writable';
import './cadastros.css';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

type PartyRow = {
  id: string;
  kind: 'person' | 'organization';
  legal_name: string;
  trade_name: string | null;
  tax_id: string | null;
  active: boolean;
  erp_party_roles: { role: string; active: boolean }[];
};
type DocumentRow = { id: string; party_id: string; type: string; number: string; issuer: string | null };
type ContactRow = { id: string; party_id: string; type: string; value: string; is_primary: boolean };
type AddressRow = { id: string; party_id: string; type: string; postal_code: string | null; street: string; number: string | null; district: string | null; city: string; state_code: string | null };
type EstablishmentRow = { id: string; code: string; kind: string; legal_name: string | null; trade_name: string; cnpj: string | null; vertical_code: string | null; active: boolean };

const ROLE_LABELS: Record<string, string> = {
  customer: 'Cliente', supplier: 'Fornecedor', employee: 'Funcionário', buyer: 'Comprador',
  sales_rep: 'Vendedor', technician: 'Técnico', carrier: 'Transportadora', other: 'Outro',
};
const DOC_LABELS: Record<string, string> = { cpf: 'CPF', cnpj: 'CNPJ', rg: 'RG', passport: 'Passaporte', other: 'Outro' };
const CONTACT_LABELS: Record<string, string> = { email: 'E-mail', phone: 'Telefone', mobile: 'Celular', whatsapp: 'WhatsApp', website: 'Site', other: 'Outro' };
const ADDRESS_LABELS: Record<string, string> = { main: 'Principal', billing: 'Cobrança', shipping: 'Entrega', service: 'Atendimento', other: 'Outro' };

const ERROR_MESSAGES: Record<string, string> = {
  dados: 'Selecione o tipo e o papel corretamente.',
  nome: 'Informe um nome ou razão social com pelo menos 2 caracteres.',
  documento: 'Documento inválido — confira os dados.',
  contato: 'Informe um contato válido.',
  endereco: 'Informe pelo menos logradouro e cidade.',
  permissao: 'Sua conta não tem permissão para cadastrar. Peça a um administrador do tenant.',
};

// M21-G3 — mesmo layout validado em cadastros-tela-unica.html: header-bar com
// contador, campos agrupados, painel lateral com abas de Documentos/Contatos/
// Endereços por pessoa. Só os campos que têm comando real por trás entraram aqui
// (o mockup tinha campos ilustrativos — cartão de crédito, certificado, TEF — que
// nunca tiveram função e ficam de fora da tela real).
export default async function CadastrosPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const access = await loadPortalAccess();

  if (access.kind === 'not-found') notFound();
  if (access.kind !== 'authorized') redirect('/login');

  const client = await getPortalVisualClient();
  const [partiesResult, establishmentsResult] = await Promise.all([
    client.read('parties'),
    client.read('establishments'),
  ]);
  const parties = (partiesResult.ok ? (partiesResult.data as PartyRow[]) : []) ?? [];
  const activeCount = parties.filter((p) => p.active).length;
  const establishments = (establishmentsResult.ok ? (establishmentsResult.data as EstablishmentRow[]) : []) ?? [];
  const establishment = establishments[0] ?? null;
  // M21-G4 — regra pedida pelo usuário: dado da empresa é a fonte de qualquer processo
  // (fiscal, cadastro, venda). Hoje é um AVISO (nudge), não um bloqueio rígido — o
  // provisionamento (M18-G21) já grava CNPJ/razão social pra clientes existentes como a
  // Mania de Modas; bloquear de verdade quem já está completo seria regressão, não gate.
  const empresaIncompleta = !establishment || !establishment.cnpj || !establishment.legal_name;

  const tipo = typeof params.tipo === 'string' && ['cliente', 'produto', 'empresa'].includes(params.tipo) ? params.tipo : 'cliente';

  const selectedId = typeof params.party === 'string' ? params.party : null;
  const selectedParty = selectedId ? parties.find((p) => p.id === selectedId) ?? null : null;

  let documents: DocumentRow[] = [];
  let contacts: ContactRow[] = [];
  let addresses: AddressRow[] = [];
  if (selectedParty && tipo === 'cliente') {
    const [docsResult, contactsResult, addressesResult] = await Promise.all([
      client.read('party-documents'),
      client.read('party-contacts'),
      client.read('party-addresses'),
    ]);
    documents = ((docsResult.ok ? (docsResult.data as DocumentRow[]) : []) ?? []).filter((d) => d.party_id === selectedParty.id);
    contacts = ((contactsResult.ok ? (contactsResult.data as ContactRow[]) : []) ?? []).filter((c) => c.party_id === selectedParty.id);
    addresses = ((addressesResult.ok ? (addressesResult.data as AddressRow[]) : []) ?? []).filter((a) => a.party_id === selectedParty.id);
  }

  const errorCode = typeof params.erro === 'string' ? params.erro : '';
  const success = params.sucesso === '1';
  const tab = typeof params.aba === 'string' ? params.aba : 'documentos';

  return (
    <div className="cc-classic">
      <div className="window">
        <div className="header-bar">
          <div className="header-title">
            <div className="eyebrow">ConnectionCyber · Cadastros ERP</div>
            <h1>{tipo === 'empresa' ? 'Cadastro da empresa' : tipo === 'produto' ? 'Cadastro de produto' : selectedParty ? 'Cadastro de pessoa' : 'Novo cadastro'}</h1>
          </div>
          <div className="switch-bar">
            <a className={`switch-btn${tipo === 'cliente' ? ' on' : ''}`} href="/cadastros?tipo=cliente">Cadastro de cliente</a>
            <a className={`switch-btn${tipo === 'produto' ? ' on' : ''}`} href="/cadastros?tipo=produto">Cadastro de produto</a>
            <a className={`switch-btn${tipo === 'empresa' ? ' on' : ''}`} href="/cadastros?tipo=empresa">Empresa</a>
          </div>
          <span className="spacer"></span>
          {tipo === 'cliente' ? <span className="pill strong">{parties.length} cadastro(s)</span> : null}
        </div>

        {empresaIncompleta && tipo !== 'empresa' ? (
          <div className="gate-banner">
            Os dados da empresa ({access.membership.tenantName}) ainda não estão completos — são a fonte usada por
            qualquer processo (fiscal, vendas, cadastro). <a href="/cadastros?tipo=empresa">Completar agora →</a>
          </div>
        ) : null}

        {tipo === 'cliente' ? (
        <div className="counter-row">
          <div className="tot"><span className="k">Cadastros</span><b>{parties.length}</b></div>
          <div className="ativ"><span className="k">Ativos</span><b>{activeCount}</b></div>
        </div>
        ) : null}

        {success ? <div className="alert" role="status">Salvo com sucesso.</div> : null}
        {ERROR_MESSAGES[errorCode] ? <div className="alert danger" role="alert">{ERROR_MESSAGES[errorCode]}</div> : null}

        {tipo === 'produto' ? (
          <div className="main-fields">
            <div className="grp">
              <p className="grp-label">Cadastro de produto</p>
              <p className="hint">
                Esta tela ainda não está pronta pra gravar de verdade: falta a unidade de medida
                (UN, KG...) — hoje não existe leitura nem criação de unidade no transporte real,
                só no ambiente sintético interno. É o próximo gate técnico antes de liberar Produto
                aqui. Cliente e Empresa já gravam de verdade.
              </p>
            </div>
          </div>
        ) : null}

        {tipo === 'empresa' ? (
          <div className="main-fields">
            <div className="grp">
              <p className="grp-label">Dados da empresa emitente</p>
              {establishment ? (
                <>
                  <div className="row r2">
                    <div className="field"><label>Razão social</label><input value={establishment.legal_name ?? ''} disabled placeholder="Não informado" /></div>
                    <div className="field"><label>Nome fantasia</label><input value={establishment.trade_name} disabled /></div>
                  </div>
                  <div className="row r2">
                    <div className="field"><label>CNPJ</label><input value={establishment.cnpj ?? ''} disabled placeholder="Não informado" /></div>
                    <div className="field"><label>Segmento</label><input value={establishment.vertical_code ?? ''} disabled placeholder="Não definido" /></div>
                  </div>
                  <p className="hint">
                    Edição de CNPJ/razão social ainda não tem tela própria (dado sensível, muda só
                    por suporte por enquanto). O que aparece aqui é o que já está gravado desde o
                    provisionamento.
                  </p>
                </>
              ) : (
                <p className="hint">Nenhum estabelecimento encontrado pra este tenant.</p>
              )}
            </div>
          </div>
        ) : null}

        {tipo === 'cliente' ? (
        <>
        <div className="body-grid">
          <div className="main-fields">
            {selectedParty ? (
              <div className="grp">
                <p className="grp-label">Identificação</p>
                <div className="row r2">
                  <div className="field"><label>Tipo</label><input value={selectedParty.kind === 'person' ? 'Pessoa física' : 'Pessoa jurídica'} disabled /></div>
                  <div className="field"><label>Papel</label><input value={selectedParty.erp_party_roles?.map((r) => ROLE_LABELS[r.role] ?? r.role).join(', ') || '—'} disabled /></div>
                </div>
                <div className="row r1"><div className="field"><label>Nome / Razão social</label><input value={selectedParty.legal_name} disabled /></div></div>
                <div className="row r2">
                  <div className="field"><label>Nome fantasia</label><input value={selectedParty.trade_name ?? ''} disabled placeholder="—" /></div>
                  <div className="field"><label>CPF/CNPJ</label><input value={selectedParty.tax_id ?? ''} disabled placeholder="—" /></div>
                </div>
                <a className="act-btn" href="/cadastros">← Voltar pro cadastro novo</a>
              </div>
            ) : (
              <form method="post" action="/cadastros/nova-pessoa">
                <div className="grp">
                  <p className="grp-label">Identificação</p>
                  <div className="row r2">
                    <div className="field"><label>Tipo</label>
                      <select name="kind" defaultValue="organization">
                        <option value="organization">Pessoa jurídica</option>
                        <option value="person">Pessoa física</option>
                      </select>
                    </div>
                    <div className="field"><label>Papel</label>
                      <select name="role" defaultValue="customer">
                        {Object.entries(ROLE_LABELS).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                      </select>
                    </div>
                  </div>
                  <div className="row r1"><div className="field"><label>Nome / Razão social<span className="req">*</span></label><input type="text" name="legal_name" required minLength={2} maxLength={180} /></div></div>
                  <div className="row r2">
                    <div className="field"><label>Nome fantasia <span className="hint">opcional</span></label><input type="text" name="trade_name" maxLength={180} /></div>
                    <div className="field" id="cad-doc-field"><label>CPF/CNPJ <span className="hint">opcional</span></label><input type="text" id="cad-doc" name="tax_id" inputMode="numeric" placeholder="Só números ou com pontuação" /><div className="doc-msg"></div></div>
                  </div>
                </div>
                <button className="act-btn primary" type="submit">Cadastrar</button>
              </form>
            )}
          </div>

          <div className="side-fields">
            {selectedParty ? (
              <div className="side-tabs">
                <div className="extra-tabs">
                  <a className={`extra-tab${tab === 'documentos' ? ' on' : ''}`} href={`/cadastros?party=${selectedParty.id}&aba=documentos`}>Documentos</a>
                  <a className={`extra-tab${tab === 'contatos' ? ' on' : ''}`} href={`/cadastros?party=${selectedParty.id}&aba=contatos`}>Contatos</a>
                  <a className={`extra-tab${tab === 'enderecos' ? ' on' : ''}`} href={`/cadastros?party=${selectedParty.id}&aba=enderecos`}>Endereços</a>
                </div>

                {tab === 'documentos' ? (
                  <div className="extra-panel on">
                    {documents.length === 0 ? <p className="hint">Nenhum documento além do informado no cadastro.</p> : (
                      <ul className="mini-list">{documents.map((d) => <li key={d.id}><strong>{DOC_LABELS[d.type] ?? d.type}</strong> {d.number}{d.issuer ? ` — ${d.issuer}` : ''}</li>)}</ul>
                    )}
                    <form method="post" action="/cadastros/novo-documento">
                      <input type="hidden" name="party_id" value={selectedParty.id} />
                      <div className="row r2">
                        <div className="field"><label>Tipo</label><select name="type" defaultValue="rg">{Object.entries(DOC_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select></div>
                        <div className="field"><label>Número</label><input type="text" name="number" required maxLength={40} /></div>
                      </div>
                      <div className="row r1"><div className="field"><label>Emissor <span className="hint">opcional</span></label><input type="text" name="issuer" maxLength={80} /></div></div>
                      <button className="act-btn primary" type="submit">Adicionar documento</button>
                    </form>
                  </div>
                ) : null}

                {tab === 'contatos' ? (
                  <div className="extra-panel on">
                    {contacts.length === 0 ? <p className="hint">Nenhum contato cadastrado.</p> : (
                      <ul className="mini-list">{contacts.map((c) => <li key={c.id}><strong>{CONTACT_LABELS[c.type] ?? c.type}</strong> {c.value}{c.is_primary ? ' · principal' : ''}</li>)}</ul>
                    )}
                    <form method="post" action="/cadastros/novo-contato">
                      <input type="hidden" name="party_id" value={selectedParty.id} />
                      <div className="row r2">
                        <div className="field"><label>Tipo</label><select name="type" defaultValue="whatsapp">{Object.entries(CONTACT_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select></div>
                        <div className="field"><label>Valor</label><input type="text" id="cad-contact-value" name="value" required maxLength={254} placeholder="(00) 00000-0000 ou e-mail" /></div>
                      </div>
                      <label className="checkline" style={{ marginBottom: 10 }}><input type="checkbox" name="is_primary" /> Principal</label>
                      <button className="act-btn primary" type="submit">Adicionar contato</button>
                    </form>
                  </div>
                ) : null}

                {tab === 'enderecos' ? (
                  <div className="extra-panel on">
                    {addresses.length === 0 ? <p className="hint">Nenhum endereço cadastrado.</p> : (
                      <ul className="mini-list">{addresses.map((a) => <li key={a.id}><strong>{ADDRESS_LABELS[a.type] ?? a.type}</strong> {a.street}{a.number ? `, ${a.number}` : ''} — {a.city}{a.state_code ? `/${a.state_code}` : ''}</li>)}</ul>
                    )}
                    <form method="post" action="/cadastros/novo-endereco">
                      <input type="hidden" name="party_id" value={selectedParty.id} />
                      <div className="row r2">
                        <div className="field"><label>Tipo</label><select name="type" defaultValue="main">{Object.entries(ADDRESS_LABELS).map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select></div>
                        <div className="field"><label>CEP <span className="hint">busca automática</span></label><input type="text" id="cad-cep" name="postal_code" maxLength={9} placeholder="00000-000" /></div>
                      </div>
                      <div className="row r1"><div className="field"><label>Logradouro</label><input type="text" id="cad-street" name="street" required maxLength={180} /></div></div>
                      <div className="row r3">
                        <div className="field"><label>Número</label><input type="text" name="number" maxLength={20} /></div>
                        <div className="field"><label>Bairro</label><input type="text" id="cad-district" name="district" maxLength={80} /></div>
                        <div className="field"><label>Cidade</label><input type="text" id="cad-city" name="city" required maxLength={120} /></div>
                      </div>
                      <div className="row r1"><div className="field"><label>UF</label><input type="text" id="cad-state" name="state_code" maxLength={2} style={{ textTransform: 'uppercase', width: 80 }} /></div></div>
                      <label className="checkline" style={{ marginBottom: 10 }}><input type="checkbox" name="is_primary" /> Principal</label>
                      <button className="act-btn primary" type="submit">Adicionar endereço</button>
                    </form>
                  </div>
                ) : null}
              </div>
            ) : (
              <p className="hint">Selecione um cadastro na lista abaixo para ver documentos, contatos e endereços.</p>
            )}
          </div>
        </div>

        <div className="main-fields" style={{ borderRight: 'none', borderTop: '1px solid var(--cc-border)' }}>
          <p className="grp-label">Cadastros de {access.membership.tenantName}</p>
          {parties.length === 0 ? (
            <p className="hint">Nenhum cadastro ainda — use o formulário acima para criar o primeiro.</p>
          ) : (
            parties.map((party) => (
              <a key={party.id} className="party-row" href={`/cadastros?party=${party.id}`}>
                <strong>{party.legal_name}</strong>
                <span>
                  {party.erp_party_roles?.map((r) => ROLE_LABELS[r.role] ?? r.role).join(', ') || 'Sem papel'}
                  {party.tax_id ? ` · ${party.tax_id}` : ''}
                </span>
              </a>
            ))
          )}
        </div>
        </>
        ) : null}

        <div className="status-bar"><span>Grava direto no banco — não é uma demonstração</span></div>
      </div>

      <script
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{
          __html: `
function ccOnlyDigits(v){return (v||'').replace(/\\D/g,'')}
function ccIsValidCPF(d){if(d.length!==11||/^(\\d)\\1{10}$/.test(d))return false;let s=0;for(let i=0;i<9;i++)s+=parseInt(d[i])*(10-i);let r=(s*10)%11;if(r===10)r=0;if(r!==parseInt(d[9]))return false;s=0;for(let i=0;i<10;i++)s+=parseInt(d[i])*(11-i);r=(s*10)%11;if(r===10)r=0;return r===parseInt(d[10])}
function ccIsValidCNPJ(d){if(d.length!==14||/^(\\d)\\1{13}$/.test(d))return false;const calc=(len)=>{let w=len-7,s=0;for(let i=0;i<len;i++){s+=parseInt(d[i])*w;w--;if(w<2)w=9}const r=s%11;return r<2?0:11-r};return calc(12)===parseInt(d[12])&&calc(13)===parseInt(d[13])}
function ccMaskDoc(el){let v=ccOnlyDigits(el.value).slice(0,14);if(v.length>11)el.value=v.replace(/(\\d{2})(\\d{3})(\\d{3})(\\d{0,4})(\\d{0,2})/,'$1.$2.$3/$4-$5').replace(/[./-]+$/,'');else el.value=v.replace(/(\\d{3})(\\d{3})(\\d{0,3})(\\d{0,2})/,'$1.$2.$3-$4').replace(/[.-]+$/,'')}
function ccCheckDoc(el){const field=document.getElementById('cad-doc-field');const msg=field.querySelector('.doc-msg');const digits=ccOnlyDigits(el.value);field.classList.remove('doc-ok','doc-bad');if(msg)msg.textContent='';if(!digits)return;const ok=digits.length===11?ccIsValidCPF(digits):digits.length===14?ccIsValidCNPJ(digits):false;field.classList.add(ok?'doc-ok':'doc-bad');if(msg)msg.textContent=ok?'Documento válido':'Dígito verificador não confere'}
function ccMaskContact(el){const d=ccOnlyDigits(el.value);if(el.value.includes('@')||!d)return;let v=d.slice(0,11);if(v.length>10)el.value=v.replace(/(\\d{2})(\\d{5})(\\d{0,4})/,'($1) $2-$3');else if(v.length>5)el.value=v.replace(/(\\d{2})(\\d{4})(\\d{0,4})/,'($1) $2-$3');else if(v.length>2)el.value=v.replace(/(\\d{2})(\\d{0,5})/,'($1) $2')}
function ccMaskCEP(el){let v=ccOnlyDigits(el.value).slice(0,8);el.value=v.length>5?v.replace(/(\\d{5})(\\d{0,3})/,'$1-$2'):v}
async function ccLookupCEP(el){const cep=ccOnlyDigits(el.value);if(cep.length!==8)return;try{const res=await fetch('https://viacep.com.br/ws/'+cep+'/json/');const data=await res.json();if(data.erro)return;const street=document.getElementById('cad-street');const district=document.getElementById('cad-district');const city=document.getElementById('cad-city');const state=document.getElementById('cad-state');if(street&&data.logradouro)street.value=data.logradouro;if(district&&data.bairro)district.value=data.bairro;if(city&&data.localidade)city.value=data.localidade;if(state&&data.uf)state.value=data.uf}catch(e){}}
(function(){
  var doc=document.getElementById('cad-doc');
  if(doc){doc.addEventListener('input',function(){ccMaskDoc(doc)});doc.addEventListener('blur',function(){ccCheckDoc(doc)});}
  var cep=document.getElementById('cad-cep');
  if(cep){cep.addEventListener('input',function(){ccMaskCEP(cep)});cep.addEventListener('blur',function(){ccLookupCEP(cep)});}
  var contact=document.getElementById('cad-contact-value');
  if(contact){contact.addEventListener('input',function(){ccMaskContact(contact)});}
})();
`,
        }}
      />
    </div>
  );
}
