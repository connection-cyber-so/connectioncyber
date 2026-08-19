import { identityPersonas, roleMatrix } from '@/features/identity/presentation';

export const dynamic = 'force-dynamic';

function StatusPill({ status }: { status: string }) {
  const token = status.toLowerCase().replace(' ', '-').replace('í', 'i');
  return <span className={`pf-identity-status status-${token}`}>{status}</span>;
}

export default function IdentitiesPage() {
  return (
    <>
      <div className="pf-page-header">
        <div>
          <div className="pf-eyebrow">M04-G1 · apresentação controlada</div>
          <h1>Identidades, papéis e MFA</h1>
          <p>Fluxos propostos para convite, lifecycle, autorização por empresa e step-up AAL2.</p>
        </div>
        <span className="pf-identity-mode">Dry-run obrigatório</span>
      </div>

      <div className="pf-identity-warning" role="status">
        <strong>Modo demonstração:</strong> esta tela não chama o Supabase Auth, não grava banco e não envia convite.{' '}
        Os endereços <code>.invalid</code> são personas sintéticas do laboratório.
      </div>

      <section className="pf-identity-metrics" aria-label="Resumo do portão">
        <div><strong>7</strong><span>personas de prova</span></div>
        <div><strong>0</strong><span>contas criadas</span></div>
        <div><strong>5</strong><span>papéis canônicos</span></div>
        <div><strong>AAL2</strong><span>para privilégio</span></div>
      </section>

      <section className="pf-content-card">
        <div className="pf-card-head pf-identity-heading">
          <div><div className="pf-eyebrow">Tela 1 · convite</div><h2>Preparar acesso empresarial</h2></div>
          <span className="pf-pill">pré-visualização</span>
        </div>
        <div className="pf-identity-form-grid" aria-label="Formulário de convite desabilitado">
          <label>E-mail controlado<input value="qa+cliente@connectioncyber.com.br" disabled /></label>
          <label>Empresa<select value="tenant-a" disabled><option value="tenant-a">Tenant A · empresa piloto</option></select></label>
          <label>Papel<select value="viewer" disabled><option value="viewer">viewer · consulta</option></select></label>
          <label>Expiração<input value="7 dias" disabled /></label>
        </div>
        <div className="pf-identity-form-footer">
          <label><input type="checkbox" checked disabled /> Exigir MFA quando o papel for privilegiado</label>
          <button className="pf-button pf-identity-disabled" type="button" disabled>Somente dry-run</button>
        </div>
      </section>

      <section className="pf-content-card">
        <div className="pf-eyebrow">Tela 2 · usuários e memberships</div><h2>Fila determinística de personas</h2>
        <div className="pf-identity-table-wrap">
          <table className="pf-identity-table">
            <thead><tr><th>Persona</th><th>Identidade</th><th>Empresa</th><th>Papel</th><th>Estado</th><th>MFA</th></tr></thead>
            <tbody>{identityPersonas.map((persona) => (
              <tr key={persona.key}>
                <td><strong>{persona.key}</strong><small>{persona.label}</small></td><td><code>{persona.email}</code></td>
                <td>{persona.tenant}</td><td><code>{persona.role}</code></td><td><StatusPill status={persona.status} /></td><td>{persona.mfa}</td>
              </tr>
            ))}</tbody>
          </table>
        </div>
      </section>

      <section className="pf-content-card">
        <div className="pf-eyebrow">Tela 3 · matriz de papéis</div><h2>Permissão pertence à membership</h2>
        <p className="pf-muted">O mesmo usuário pode ser gerente na empresa A e consulta na empresa B.</p>
        <div className="pf-identity-role-grid">{roleMatrix.map((role) => (
          <article className={`pf-identity-role tone-${role.tone}`} key={role.key}>
            <div><code>{role.key}</code>{role.mfa && <span>MFA</span>}</div><h3>{role.name}</h3><p>{role.scope}</p>
          </article>
        ))}</div>
      </section>

      <section className="pf-content-card">
        <div className="pf-eyebrow">Tela 4 · MFA e step-up</div><h2>Ação privilegiada exige AAL2</h2>
        <div className="pf-identity-aal-flow" aria-label="Fluxo de elevação MFA">
          <div><span>1</span><strong>Sessão AAL1</strong><small>login válido</small></div><b>→</b>
          <div className="blocked"><span>2</span><strong>Ação bloqueada</strong><small>identities.manage</small></div><b>→</b>
          <div><span>3</span><strong>Validar TOTP</strong><small>fator Supabase Auth</small></div><b>→</b>
          <div className="approved"><span>4</span><strong>Sessão AAL2</strong><small>ação + auditoria</small></div>
        </div>
        <p className="pf-identity-deny">Sem membership, permissão explícita ou AAL mínimo: acesso negado por padrão.</p>
      </section>
    </>
  );
}
