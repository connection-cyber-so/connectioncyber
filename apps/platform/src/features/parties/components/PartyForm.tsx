'use client';
import { useState } from 'react';
import { useActionState } from 'react';import { useFormStatus } from 'react-dom';
import { createPartyAction,type PartyActionState } from '../actions';
import { formatTaxId, isValidTaxId, onlyDigits } from '@/domain/br-documents.mjs';

const initial:PartyActionState={error:null,success:false};
function Submit(){const{pending}=useFormStatus();return <button className="pf-button" type="submit" disabled={pending}>{pending?'Salvando…':'Cadastrar'}</button>}

// M20-G6 — eleva o esqueleto de aceite de gate a tela real de uso: máscara e dígito
// verificador de CPF/CNPJ ao vivo (mesma lib usada no server em validations.ts), rótulo do
// documento acompanha o tipo (PF/PJ) selecionado. Continua enviando só dígitos pro servidor
// (que revalida do zero — isto aqui é conforto de digitação, não a fonte da verdade).
export function PartyForm(){
  const [state,action]=useActionState(createPartyAction,initial);
  const [kind,setKind]=useState<'organization'|'person'>('organization');
  const [taxId,setTaxId]=useState('');
  const taxDigits=onlyDigits(taxId);
  const taxIdError=taxDigits.length>0 && !isValidTaxId(taxDigits)
    ? (kind==='person' ? 'CPF inválido.' : 'CNPJ inválido.')
    : null;

  return (
    <div className="pf-content-card">
      <h2>Novo cadastro</h2>
      <form action={action}>
        <input type="hidden" name="tax_id" value={taxDigits} />
        <div className="pf-grid-2">
          <div className="pf-field">
            <label htmlFor="kind">Tipo</label>
            <select id="kind" name="kind" value={kind} onChange={(e)=>{setKind(e.target.value as 'organization'|'person');setTaxId('');}}>
              <option value="organization">Pessoa jurídica</option>
              <option value="person">Pessoa física</option>
            </select>
          </div>
          <div className="pf-field">
            <label htmlFor="role">Papel</label>
            <select id="role" name="role" defaultValue="customer">
              <option value="customer">Cliente</option>
              <option value="supplier">Fornecedor</option>
              <option value="buyer">Comprador</option>
              <option value="employee">Funcionário</option>
              <option value="sales_rep">Vendedor</option>
              <option value="technician">Técnico</option>
              <option value="carrier">Transportadora</option>
              <option value="other">Outro</option>
            </select>
          </div>
        </div>
        <div className="pf-field">
          <label htmlFor="legal_name">{kind==='person' ? 'Nome completo' : 'Razão social'}</label>
          <input id="legal_name" name="legal_name" required maxLength={180}/>
        </div>
        <div className="pf-grid-2">
          <div className="pf-field">
            <label htmlFor="trade_name">{kind==='person' ? 'Apelido (opcional)' : 'Nome fantasia'}</label>
            <input id="trade_name" name="trade_name" maxLength={180}/>
          </div>
          <div className="pf-field">
            <label htmlFor="tax_id_display">{kind==='person' ? 'CPF' : 'CNPJ'}</label>
            <input
              id="tax_id_display"
              inputMode="numeric"
              placeholder={kind==='person' ? '000.000.000-00' : '00.000.000/0000-00'}
              maxLength={kind==='person' ? 14 : 18}
              value={formatTaxId(taxId)}
              onChange={(e)=>setTaxId(e.target.value)}
            />
            {taxIdError && <p className="pf-error">{taxIdError}</p>}
          </div>
        </div>
        {state.error&&<p className="pf-error">{state.error}</p>}
        {state.success&&<p className="pf-success">Cadastro criado.</p>}
        <Submit/>
      </form>
    </div>
  );
}
