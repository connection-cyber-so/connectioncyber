import { createClient } from '@/lib/supabase/server';

/**
 * Verifica se o usuário autenticado é equipe ConnectionCyber (admin/suporte),
 * chamando a mesma função SQL usada nas policies de RLS do projeto
 * (public.is_platform_staff(), ver supabase/migrations/0002_multi_tenant.sql).
 *
 * Achado em 2026-08-15 (validação de acesso admin/aluno/cliente): a RLS já
 * impedia um usuário comum de ver dado de outro tenant, mas nada impedia o
 * LOGIN em si no painel — qualquer conta autenticada (mesmo aluno/cliente)
 * conseguia abrir o dashboard e os módulos. Esta função fecha essa lacuna,
 * usada no layout do route group (painel).
 */
export async function isPlatformStaff(): Promise<boolean> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc('is_platform_staff');
  if (error) return false;
  return data === true;
}
