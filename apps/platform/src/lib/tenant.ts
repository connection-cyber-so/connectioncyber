import { createClient } from '@/lib/supabase/server';

/**
 * Deriva o tenant_id do usuário autenticado a partir da SESSÃO (public.users,
 * mesma tabela que public.current_tenant_id() lê no banco) — nunca de um
 * dado enviado pelo cliente (form, query string, etc.).
 *
 * Correção deliberada em relação ao código de origem (cc-commerce-studio):
 * lá, o `workspace_id` vinha direto de `formData.get("workspace_id")` nas
 * Server Actions — o RLS ainda protegia (a escrita falharia se o usuário não
 * fosse membro do workspace), mas não seguia o padrão "servidor deriva o
 * tenant da sessão" já adotado neste projeto. Aqui a Server Action nunca
 * recebe tenant_id do formulário — sempre chama esta função.
 */
export async function getCurrentTenantId(): Promise<string | null> {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) return null;

  const { data, error } = await supabase
    .from('users')
    .select('tenant_id')
    .eq('id', user.id)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data?.tenant_id ?? null;
}

/** Mesma coisa, mas lança erro se não houver tenant — para uso em Server Actions que exigem sessão válida. */
export async function requireCurrentTenantId(): Promise<string> {
  const tenantId = await getCurrentTenantId();
  if (!tenantId) {
    throw new Error('Sessão expirada ou usuário sem tenant associado. Faça login novamente.');
  }
  return tenantId;
}
