// M21-G5 — mesmo switcher validado em cadastros-tela-unica.html, reaproveitado nas 3
// páginas reais de cadastro do apps/platform (Cadastros/Catálogo/Empresa).
export function CadastroSwitchBar({ active }: { active: 'cliente' | 'produto' | 'empresa' }) {
  return (
    <div className="switch-bar">
      <a className={`switch-btn${active === 'cliente' ? ' on' : ''}`} href="/cadastros">Cadastro de cliente</a>
      <a className={`switch-btn${active === 'produto' ? ' on' : ''}`} href="/catalogo">Cadastro de produto</a>
      <a className={`switch-btn${active === 'empresa' ? ' on' : ''}`} href="/empresa">Empresa</a>
    </div>
  );
}
