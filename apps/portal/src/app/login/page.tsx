import { notFound, redirect } from 'next/navigation';
import { PublicFrame } from '@/components/PublicFrame';
import { safePortalRedirect } from '@/domain/redirect';
import { loadPortalAccess } from '@/lib/portal-context';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type LoginPageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

const ERROR_MESSAGES: Record<string, string> = {
  credenciais: 'E-mail ou senha inválidos.',
  configuracao: 'O ambiente de autenticação ainda não foi conectado.',
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const access = await loadPortalAccess();
  const errorCode = typeof params.erro === 'string' ? params.erro : '';
  const redirectPath = safePortalRedirect(
    typeof params.redirect === 'string' ? params.redirect : '/'
  );

  if (access.kind === 'not-found') notFound();
  if (access.kind === 'authorized') redirect('/dashboard');
  if (access.kind === 'select-membership') redirect('/selecionar-empresa');
  if (access.kind === 'no-membership') redirect('/sem-empresa');
  if (access.kind === 'forbidden') redirect('/acesso-negado');

  const configurationMissing = access.kind === 'configuration-missing';
  const unavailable = access.kind === 'service-unavailable';
  const tenantName = access.kind === 'login' && access.host.kind === 'tenant'
    ? access.host.tenantName
    : 'Portal empresarial';

  return (
    <PublicFrame>
      <span className="eyebrow">Acesso certificado</span>
      <h1>Entrar em {tenantName}</h1>
      <p className="lead">
        Use sua conta individual. O ambiente da empresa será confirmado novamente no servidor.
      </p>

      {configurationMissing ? (
        <div className="alert warning" role="status">
          Visualização local: autenticação staging ainda não conectada neste portão.
        </div>
      ) : null}
      {unavailable ? (
        <div className="alert danger" role="alert">
          Serviço de validação indisponível. O acesso permaneceu bloqueado.
        </div>
      ) : null}
      {ERROR_MESSAGES[errorCode] ? (
        <div className="alert danger" role="alert">{ERROR_MESSAGES[errorCode]}</div>
      ) : null}

      <form method="post" action="/auth/login" className="form-stack">
        <input type="hidden" name="redirect" value={redirectPath} />
        <label>
          E-mail
          <input
            name="email"
            type="email"
            autoComplete="username"
            required
            disabled={configurationMissing || unavailable}
          />
        </label>
        <label>
          Senha
          <input
            name="password"
            type="password"
            autoComplete="current-password"
            minLength={8}
            required
            disabled={configurationMissing || unavailable}
          />
        </label>
        <button className="button primary" type="submit" disabled={configurationMissing || unavailable}>
          Entrar com segurança
        </button>
      </form>
      <p className="fine-print">
        O endereço identifica a empresa, mas não concede acesso. Sua membership ativa é obrigatória.
      </p>
    </PublicFrame>
  );
}
