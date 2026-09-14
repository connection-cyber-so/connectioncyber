import 'server-only';
import { createClient } from '@/lib/supabase/server';
import { loadPortalAccess } from '@/lib/portal-context';
import { dimensions, kinds, type Filters, type Item, type Asset } from './types';
import { pageNumber, uuid } from './validations';
export async function context() {
  if (process.env.KNOWLEDGE_BASE_ENABLED !== 'true') throw new Error('KB_DISABLED');
  const access = await loadPortalAccess();
  if (access.kind !== 'authorized') throw new Error('KB_ACCESS_DENIED');
  const client = await createClient();
  const tenantId = access.membership.tenantId;
  const { data, error } = await client.rpc('kb_context', { p_tenant: tenantId });
  if (error) throw new Error('KB_UNAVAILABLE');
  if (data?.access !== true) throw new Error('KB_SUBSCRIPTION_REQUIRED');
  return { client, tenantId, userId: access.membership.userId, manage: data.manage === true };
}
export async function command(
  action: string,
  id: string | null,
  revision: number | null,
  data: Record<string, unknown>,
) {
  const ctx = await context();
  const { data: result, error } = await ctx.client.rpc('kb_command', {
    p_tenant: ctx.tenantId,
    p_action: action,
    p_item: id ? uuid(id) : null,
    p_revision: revision,
    p_data: data,
  });
  if (error) {
    const code = error.message.match(/KB_[A-Z_]+/)?.[0];
    throw new Error(code ?? 'KB_COMMAND_FAILED');
  }
  return result as Item & { reserved_asset_id?: string; reserved_path?: string };
}
export async function catalog(filters: Filters) {
  const ctx = await context();
  const page = pageNumber(filters.page);
  let query = ctx.client
    .from('kb_items')
    .select('*', { count: 'exact' })
    .eq('tenant_id', ctx.tenantId);
  if (filters.q?.trim())
    query = query.textSearch('search_document', filters.q.slice(0, 200), {
      type: 'websearch',
      config: 'portuguese',
    });
  if (filters.kind && kinds.includes(filters.kind as Item['kind']))
    query = query.eq('kind', filters.kind);
  if (filters.stage && /^[0-4]$/.test(filters.stage))
    query = query.eq('stage', Number(filters.stage));
  if (filters.tag) query = query.contains('tags', [filters.tag.slice(0, 60).toLowerCase()]);
  for (const key of Object.keys(dimensions)) {
    const value = filters[key as keyof Filters];
    if (value) query = query.contains('taxonomy', { [key]: value.slice(0, 180) });
  }
  if (filters.score && /^\d{1,3}$/.test(filters.score))
    query = query.gte('score', Math.min(100, Number(filters.score)));
  if (filters.favorite === '1') {
    const { data, error } = await ctx.client
      .from('kb_favorites')
      .select('item_id')
      .eq('tenant_id', ctx.tenantId)
      .eq('user_id', ctx.userId);
    if (error) throw new Error('KB_UNAVAILABLE');
    query = query.in(
      'id',
      (data ?? []).map((row) => row.item_id),
    );
  }
  query = query
    .order(filters.sort === 'score' ? 'score' : 'updated_at', { ascending: false })
    .order('id')
    .range((page - 1) * 24, page * 24 - 1);
  const { data, count, error } = await query;
  if (error) throw new Error('KB_UNAVAILABLE');
  return { ...ctx, items: (data ?? []) as Item[], count: count ?? 0, page };
}
export async function detail(id: string) {
  const ctx = await context();
  uuid(id);
  const { data: item, error } = await ctx.client
    .from('kb_items')
    .select('*')
    .eq('tenant_id', ctx.tenantId)
    .eq('id', id)
    .maybeSingle();
  if (error) throw new Error('KB_UNAVAILABLE');
  if (!item) throw new Error('KB_NOT_FOUND');
  const [assets, versions, events, ratings, favorite] = await Promise.all([
    ctx.client
      .from('kb_assets')
      .select('*')
      .eq('tenant_id', ctx.tenantId)
      .eq('item_id', id)
      .order('created_at', { ascending: false }),
    ctx.client
      .from('kb_versions')
      .select('revision,created_at')
      .eq('tenant_id', ctx.tenantId)
      .eq('item_id', id)
      .order('revision', { ascending: false })
      .limit(50),
    ctx.client
      .from('kb_events')
      .select('id,action,revision,created_at,detail')
      .eq('tenant_id', ctx.tenantId)
      .eq('item_id', id)
      .order('created_at', { ascending: false })
      .limit(100),
    ctx.client
      .from('kb_ratings')
      .select('rating,comment,user_id')
      .eq('tenant_id', ctx.tenantId)
      .eq('item_id', id),
    ctx.client
      .from('kb_favorites')
      .select('item_id')
      .eq('tenant_id', ctx.tenantId)
      .eq('item_id', id)
      .eq('user_id', ctx.userId)
      .maybeSingle(),
  ]);
  if ([assets, versions, events, ratings, favorite].some((result) => result.error))
    throw new Error('KB_UNAVAILABLE');
  return {
    ...ctx,
    item: item as Item,
    assets: (assets.data ?? []) as Asset[],
    versions: versions.data ?? [],
    events: events.data ?? [],
    ratings: ratings.data ?? [],
    favorite: !!favorite.data,
  };
}
export async function dashboard() {
  const ctx = await context();
  const results = await Promise.all(
    [0, 1, 2, 3, 4].map((stage) =>
      ctx.client
        .from('kb_items')
        .select('id', { head: true, count: 'exact' })
        .eq('tenant_id', ctx.tenantId)
        .eq('stage', stage),
    ),
  );
  if (results.some((r) => r.error)) throw new Error('KB_UNAVAILABLE');
  const [downloads, favorites] = await Promise.all([
    ctx.client
      .from('kb_events')
      .select('id', { head: true, count: 'exact' })
      .eq('tenant_id', ctx.tenantId)
      .eq('action', 'download'),
    ctx.client
      .from('kb_favorites')
      .select('item_id', { head: true, count: 'exact' })
      .eq('tenant_id', ctx.tenantId)
      .eq('user_id', ctx.userId),
  ]);
  if (downloads.error || favorites.error) throw new Error('KB_UNAVAILABLE');
  return {
    counts: results.map((r) => r.count ?? 0),
    manage: ctx.manage,
    downloads: downloads.count ?? 0,
    favorites: favorites.count ?? 0,
  };
}

export async function version(id: string, revision: number) {
  const ctx = await context();
  uuid(id);
  if (!Number.isSafeInteger(revision) || revision < 1) throw new Error('KB_NOT_FOUND');
  const { data, error } = await ctx.client
    .from('kb_versions')
    .select('revision,created_at,snapshot')
    .eq('tenant_id', ctx.tenantId)
    .eq('item_id', id)
    .eq('revision', revision)
    .maybeSingle();
  if (error) throw new Error('KB_UNAVAILABLE');
  if (!data) throw new Error('KB_NOT_FOUND');
  return data;
}
