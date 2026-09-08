'use client';
import { useState } from 'react';
import { useActionState } from 'react';import { useFormStatus } from 'react-dom';
import { addPartyAddressAction, addPartyContactAction, addPartyDocumentAction, type PartyActionState } from '../actions';
import type { PartyAddress, PartyContact, PartyDocument } from '../types';
import { formatPhone, onlyDigits } from '@/domain/br-documents.mjs';

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
  const [state, action] = useActionState(addPartyDocumentAction, initial);
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

// M20-G3 — aba Contatos. M20-G6: telefone/celular/whatsapp ganham máscara ao vivo;
// e-mail e site continuam texto livre (a validação de formato já é do zod no server).
const PHONE_TYPES = new Set<PartyContact['type']>(['phone', 'mobile', 'whatsapp']);
function ContactsSection({ partyId, contacts }: { partyId: string; contacts: PartyContact[] }) {
  const [state, action] = useActionState(addPartyContactAction, initial);
  const [type, setType] = useState<PartyContact['type']>('whatsapp');
  const [value, setValue] = useState('');
  const isPhone = PHONE_TYPES.has(type);
  return (
    <div className="pf-detail-section">
      <h4>Contatos</h4>
      {!contacts.length ? <p className="pf-muted">Nenhum contato cadastrado.</p> : (
        <ul className="pf-mini-list">{contacts.map((contact) => <li key={contact.id}><strong>{contactLabels[contact.type]}</strong> {contact.value}{contact.is_primary ? ' · principal' : ''}</li>)}</ul>
      )}
      <form action={action}>
        <input type="hidden" name="party_id" value={partyId} />
        <input type="hidden" name="value" value={isPhone ? onlyDigits(value) : value} />
        <div className="pf-grid-2">
          <div className="pf-field"><label>Tipo</label><select name="type" value={type} onChange={(e) => { setType(e.target.value as PartyContact['type']); setValue(''); }}>{Object.entries(contactLabels).map(([v, label]) => <option key={v} value={v}>{label}</option>)}</select></div>
          <div className="pf-field">
            <label>Valor</label>
            <input
              required
              maxLength={254}
              inputMode={isPhone ? 'numeric' : undefined}
              placeholder={isPhone ? '(00) 00000-0000' : undefined}
              value={isPhone ? formatPhone(value) : value}
              onChange={(e) => setValue(e.target.value)}
            />
          </div>
        </div>
        <label><input type="checkbox" name="is_primary" /> Principal</label>
        {state.error && <p className="pf-error">{state.error}</p>}
        {state.success && <p className="pf-success">Contato adicionado.</p>}
        <Submit label="Adicionar contato" />
      </form>
    </div>
  );
}

// M20-G3 — aba Endereços. M20-G6: CEP busca automaticamente logradouro/bairro/cidade/UF
// via ViaCEP — o usuário só confere e completa número/complemento. Busca é conforto de
// digitação; o que vale pro cadastro é sempre o que está nos campos ao enviar o formulário.
function AddressesSection({ partyId, addresses }: { partyId: string; addresses: PartyAddress[] }) {
  const [state, action] = useActionState(addPartyAddressAction, initial);
  const [postalCode, setPostalCode] = useState('');
  const [street, setStreet] = useState('');
  const [district, setDistrict] = useState('');
  const [city, setCity] = useState('');
  const [stateCode, setStateCode] = useState('');
  const [cepStatus, setCepStatus] = useState<'idle' | 'loading' | 'not_found' | 'error'>('idle');

  async function lookupCep(raw: string) {
    const digits = onlyDigits(raw);
    if (digits.length !== 8) return;
    setCepStatus('loading');
    try {
      const response = await fetch(`https://viacep.com.br/ws/${digits}/json/`);
      const data = await response.json();
      if (data.erro) { setCepStatus('not_found'); return; }
      setStreet(data.logradouro ?? '');
      setDistrict(data.bairro ?? '');
      setCity(data.localidade ?? '');
      setStateCode(data.uf ?? '');
      setCepStatus('idle');
    } catch {
      setCepStatus('error');
    }
  }

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
          <div className="pf-field">
            <label>CEP (opcional)</label>
            <input
              name="postal_code"
              maxLength={9}
              inputMode="numeric"
              placeholder="00000-000"
              value={postalCode}
              onChange={(e) => setPostalCode(e.target.value)}
              onBlur={(e) => lookupCep(e.target.value)}
            />
            {cepStatus === 'loading' && <p className="pf-muted">Buscando endereço…</p>}
            {cepStatus === 'not_found' && <p className="pf-muted">CEP não encontrado — preencha manualmente.</p>}
          </div>
        </div>
        <div className="pf-field"><label>Logradouro</label><input name="street" required maxLength={180} value={street} onChange={(e) => setStreet(e.target.value)} /></div>
        <div className="pf-grid-2">
          <div className="pf-field"><label>Número (opcional)</label><input name="number" maxLength={20} /></div>
          <div className="pf-field"><label>Complemento (opcional)</label><input name="complement" maxLength={80} /></div>
        </div>
        <div className="pf-field"><label>Bairro (opcional)</label><input name="district" maxLength={80} value={district} onChange={(e) => setDistrict(e.target.value)} /></div>
        <div className="pf-grid-2">
          <div className="pf-field"><label>Cidade</label><input name="city" required maxLength={120} value={city} onChange={(e) => setCity(e.target.value)} /></div>
          <div className="pf-field"><label>UF (opcional)</label><input name="state_code" maxLength={2} style={{ textTransform: 'uppercase' }} value={stateCode} onChange={(e) => setStateCode(e.target.value.toUpperCase())} /></div>
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
