import { getSupabaseClient } from './supabaseClient';

export type UserRole = 'admin' | 'instrutor' | 'aluno' | 'cliente' | 'suporte' | 'tecnico' | 'visitante';

export interface AuthUser {
  id: string;
  email: string;
  roles: UserRole[];
}

/** Login por e-mail e senha (Supabase Auth). */
export async function signInWithPassword(email: string, password: string) {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

/** Cadastro de novo usuário. */
export async function signUp(email: string, password: string) {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase.auth.signUp({ email, password });
  if (error) throw error;
  return data;
}

/** Logout. */
export async function signOut() {
  const supabase = getSupabaseClient();
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

/** Envia e-mail de recuperação de senha. */
export async function requestPasswordReset(email: string) {
  const supabase = getSupabaseClient();
  const { error } = await supabase.auth.resetPasswordForEmail(email);
  if (error) throw error;
}

/** Retorna a sessão atual (ou null se não autenticado). */
export async function getCurrentSession() {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase.auth.getSession();
  if (error) throw error;
  return data.session;
}

/**
 * Busca os papéis (roles) do usuário autenticado via tabela user_roles + roles.
 * Depende do schema definido em supabase/migrations/0001_init_schema.sql.
 */
export async function getUserRoles(userId: string): Promise<UserRole[]> {
  const supabase = getSupabaseClient();
  const { data, error } = await supabase
    .from('user_roles')
    .select('roles ( nome )')
    .eq('user_id', userId);

  if (error) throw error;

  return (data ?? [])
    .map((row: any) => row.roles?.nome)
    .filter(Boolean) as UserRole[];
}

/** Verifica se o usuário possui ao menos um dos papéis exigidos. */
export function hasRole(userRoles: UserRole[], required: UserRole[]): boolean {
  return required.some((role) => userRoles.includes(role));
}

/**
 * Registra evento de acesso na tabela logs_access (auditoria).
 * Deve ser chamado a partir de uma API route (contexto server-side) para
 * capturar IP/user-agent de forma confiável.
 */
export async function logAccess(params: {
  userId: string | null;
  rota: string;
  ip?: string;
  userAgent?: string;
}) {
  const supabase = getSupabaseClient();
  await supabase.from('logs_access').insert({
    user_id: params.userId,
    rota: params.rota,
    ip: params.ip ?? null,
    user_agent: params.userAgent ?? null,
  });
}
