'use client';
import { useFormState, useFormStatus } from 'react-dom';
import { addPartyAddressAction, addPartyContactAction, addPartyDocumentAction, type PartyActionState } from '../actions';
import type { PartyAddress, PartyContact, PartyDocument } from '../types';

const initial: PartyActionState = { error: null, success: false };
function Submit({ label }: { label: string }) {
  const { pending } = useFormStatus();
  return <button className="pf-button" type="submit" disabled={pending}>{pending ? 'Salvando…' : label}</button>;
}

const documentLabels: Record<PartyDocument['type'], string> = { cpf: 'CPF', cnpj: 'CNPJ', rg: 'RG', passport: 'Passaporte', other: 'Outro' };
const contactLabels: Record<PartyContact['type'], string> = { email: 'E-mail', phone: 'Telefone', mobile: 'Celular', whatsapp: 'WhatsApp', website: 'Site', other: 'Outro' };
const addressLabels: Record<PartyAddress['type'], string> = { main: 'Principal', billing: 'Cobrança', shipping: 'Entrega', service: 'Atendimento', other: 'Outro' };

// M20-G3 — aba Documentos: lista + mini-formulário anexado à pessoa já criada.
function DocumentsSection({ partyId, documents }: { partyId: string; documents: PartyDocument[] }) {
  const [state, action] = useFormState(addPartyDocumentAction, initial);
  return (
    <div className="pf-detail-section">
      <h4>Documentos</h4>
      {!documents.length ? <p className="pf-muted">Nenhum documento além do informado no cadastro.</p> : (
        <ul className="pf-mini-list">{documents.map((doc) => <li key={doc.id}><strong>{documentLabels[doc.type]}</strong> {doc.number}{doc.issuer ? ` — ${doc.issuer}` : ''}</li>)}</ul>
      )}
      <form action={action}>
        <input type="hidden" name="party_id" value={partyId} />
        <div className="pf-grid-2">
          <div className="pf-field"><label>Tipo</label><select name="type" defaultValue="rg">{Object.entries(documentLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>
          <div className="pf-field"><label>Número</label><input name="number" required maxLength={40} /></div>
        </div>
        <div className="pf-field"><label>Emissor (opcional)</label><input name="issuer" maxLength={80} /></div>
        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Documento adicionado.</p>}
        <Submit label="Adicionar documento" />
      </form>
    </div>
  );
}

// M20-G3 — aba Contatos.
function ContactsSection({ partyId, contacts }: { partyId: string; contacts: PartyContact[] }) {
  const [state, action] = useFormState(addPartyContactAction, initial);
  return (
    <div className="pf-detail-section">
      <h4>Contatos</h4>
      {!contacts.length ? <p className="pf-muted">Nenhum contato cadastrado.</p> : (
        <ul className="pf-mini-list">{contacts.map((contact) => <li key={contact.id}><strong>{contactLabels[contact.type]}</strong> {contact.value}{contact.is_primary ? ' · principal' : ''}</li>)}</ul>
      )}
      <form action={action}>
        <input type="hidden" name="party_id" value={partyId} />
        <div className="pf-grid-2">
          <div className="pf-field"><label>Tipo</label><select name="type" defaultValue="whatsapp">{Object.entries(contactLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>
          <div className="pf-field"><label>Valor</label><input name="value" required maxLength={254} /></div>
        </div>
        <label><input type="checkbox" name="is_primary" /> Principal</label>
        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Contato adicionado.</p>}
        <Submit label="Adicionar contato" />
      </form>
    </div>
  );
}

// M20-G3 — aba Endereços.
function AddressesSection({ partyId, addresses }: { partyId: string; addresses: PartyAddress[] }) {
  const [state, action] = useFormState(addPartyAddressAction, initial);
  return (
    <div className="pf-detail-section">
      <h4>Endereços</h4>
      {!addresses.length ? <p className="pf-muted">Nenhum endereço cadastrado.</p> : (
        <ul className="pf-mini-list">{addresses.map((address) => <li key={address.id}><strong>{addressLabels[address.type]}</strong> {address.street}{address.number ? `, ${address.number}` : ''} — {address.city}{address.state_code ? `/${address.state_code}` : ''}</li>)}</ul>
      )}
      <form action={action}>
        <input type="hidden" name="party_id" value={partyId} />
        <div className="pf-grid-2">
          <div className="pf-field"><label>Tipo</label><select name="type" defaultValue="main">{Object.entries(addressLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></div>
          <div className="pf-field"><label>CEP (opcional)</label><input name="postal_code" maxLength={16} /></div>
        </div>
        <div className="pf-field"><label>Logradouro</label><input name="street" required maxLength={180} /></div>
        <div className="pf-grid-2">
          <div className="pf-field"><label>Número (opcional)</label><input name="number" maxLength={20} /></div>
          <div className="pf-field"><label>Complemento (opcional)</label><input name="complement" maxLength={80} /></div>
        </div>
        <div className="pf-grid-2">
          <div className="pf-field"><label>Cidade</label><input name="city" required maxLength={120} /></div>
          <div className="pf-field"><label>UF (opcional)</label><input name="state_code" maxLength={2} style={{ textTransform: 'uppercase' }} /></div>
        </div>
        <label><input type="checkbox" name="is_primary" /> Principal</label>
        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Endereço adicionado.</p>}
        <Submit label="Adicionar endereço" />
      </form>
    </div>
  );
}

export function PartyDetailPanel({ partyId, documents, contacts, addresses }: { partyId: string; documents: PartyDocument[]; contacts: PartyContact[]; addresses: PartyAddress[] }) {
  return (
    <details className="pf-detail-item">
      <summary>Documentos, contatos e endereços</summary>
      <DocumentsSection partyId={partyId} documents={documents} />
      <ContactsSection partyId={partyId} contacts={contacts} />
      <AddressesSection partyId={partyId} addresses={addresses} />
    </details>
  );
}
