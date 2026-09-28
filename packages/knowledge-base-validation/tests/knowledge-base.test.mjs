import fs from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..');
const db = new PGlite();
await db.exec(`create role anon; create role authenticated; create role service_role bypassrls; create schema auth; create schema erp_security; create schema storage;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
grant usage on schema public,auth,erp_security,storage to authenticated,anon,service_role;
create table public.tenants(id uuid primary key,ativo boolean default true);
create table public.users(id uuid primary key,ativo boolean default true);
create table public.erp_tenant_memberships(id uuid primary key,tenant_id uuid,user_id uuid,status text,starts_at timestamptz,ends_at timestamptz);
create table public.erp_roles(id uuid primary key,tenant_id uuid,active boolean,requires_mfa boolean);
create table public.erp_membership_roles(tenant_id uuid,membership_id uuid,role_id uuid);
create table public.erp_role_permissions(tenant_id uuid,role_id uuid,permission_id uuid);
create table public.erp_permissions(id uuid primary key default gen_random_uuid(),key text unique,name text,category text,active boolean default true);
create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint);
create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text,unique(bucket_id,name));
alter table storage.objects enable row level security;grant select,insert,update,delete on storage.objects to authenticated;
`);
for (const [file, names] of [
  ['0016_erp_foundation.sql', ['is_tenant_member', 'has_permission']],
  ['0018_identity_rbac_mfa_hardening.sql', ['current_aal', 'has_permission_at_aal']],
]) {
  const sql = fs.readFileSync(root + '/supabase/migrations/' + file, 'utf8');
  for (const name of names) {
    const start = sql.indexOf('create or replace function erp_security.' + name + '(');
    const end = sql.indexOf('$$;', start) + 3;
    if (start < 0 || end < 3) throw Error('helper missing');
    await db.exec(sql.slice(start, end));
  }
}
await db.exec(fs.readFileSync(root + '/supabase/migrations/0043_m22_knowledge_base.sql', 'utf8'));
console.log('MIGRATION_EXECUTED');
const t = '00000000-0000-4000-8000-000000000001',
  other = '00000000-0000-4000-8000-000000000002';
const author = '10000000-0000-4000-8000-000000000001',
  curator = '10000000-0000-4000-8000-000000000002',
  reader = '10000000-0000-4000-8000-000000000003',
  outsider = '10000000-0000-4000-8000-000000000004';
await db.exec(`insert into public.tenants values('${t}',true),('${other}',true);
insert into public.users values('${author}',true),('${curator}',true),('${reader}',true),('${outsider}',true);
insert into public.erp_tenant_memberships(id,tenant_id,user_id,status) values('${author}','${t}','${author}','active'),('${curator}','${t}','${curator}','active'),('${reader}','${t}','${reader}','active'),('${outsider}','${other}','${outsider}','active');
insert into public.erp_roles values('${curator}','${t}',true,true);
insert into public.erp_membership_roles values('${t}','${curator}','${curator}');
insert into public.erp_role_permissions select '${t}','${curator}',id from public.erp_permissions where key='knowledge.manage';
insert into public.kb_entitlements select m.tenant_id,m.user_id,'active',now()-interval '1 day',now()+interval '1 day','synthetic',now() from public.erp_tenant_memberships m;`);
let passed = 0;
function ok(value, name) {
  if (!value) throw Error('FAIL: ' + name);
  passed++;
  console.log('PASS ' + name);
}
async function as(user, aal = 'aal1') {
  await db.exec('reset role');
  await db.query(
    "select set_config('request.jwt.claim.sub',$1,false),set_config('request.jwt.claim.aal',$2,false)",
    [user, aal],
  );
  await db.exec('set role authenticated');
}
async function command(action, id = null, revision = null, data = {}, tenant = t) {
  const r = await db.query('select public.kb_command($1,$2,$3,$4,$5) as result', [
    tenant,
    action,
    id,
    revision,
    JSON.stringify(data),
  ]);
  return r.rows[0].result;
}
async function denied(fn, name) {
  let failed = false;
  try {
    await fn();
  } catch {
    failed = true;
  }
  ok(failed, name);
}
await as(author);
let item = await command('create', null, null, {
  title: 'Synthetic SQL reference',
  kind: 'code',
  body: 'select 1;',
});
const id = item.id;
ok(item.stage === 0 && item.revision === 1, 'entry starts M0 v1');
await denied(
  () => db.exec(`update public.kb_items set stage=4 where id='${id}'`),
  'direct DML denied',
);
await denied(() => command('advance', id, 1, {}), 'author cannot approve');
await denied(() => command('revise', id, 99, { body: 'stale' }), 'stale revision rejected');
await as(reader);
ok(
  (await db.query('select * from public.kb_items')).rows.length === 0,
  'subscriber cannot read draft',
);
await as(outsider);
ok(
  (await db.query('select * from public.kb_items')).rows.length === 0,
  'cross tenant draft blocked',
);
await denied(
  () => command('create', null, null, { title: 'Cross tenant', kind: 'code' }),
  'forged tenant rejected',
);
await as(curator);
await denied(() => command('advance', id, 1, {}), 'curator AAL1 denied');
await as(curator, 'aal2');
await denied(() => command('advance', id, 1, {}), 'M1 requires taxonomy');
await as(author);
item = await command('classify', id, 1, {
  taxonomy: Object.fromEntries(
    ['ai', 'sector', 'segment', 'theme', 'project', 'technical_application', 'repository'].map(
      (k) => [k, 'test'],
    ),
  ),
  tags: ['sql'],
});
await as(curator, 'aal2');
item = await command('advance', id, item.revision, {});
ok(item.stage === 1, 'classified item reaches M1');
await denied(
  () =>
    command('advance', id, item.revision, {
      score: 59,
      application: 'Evidence of useful technical application',
    }),
  'M2 score threshold',
);
item = await command('advance', id, item.revision, {
  score: 80,
  application: 'Evidence of useful technical application',
});
await denied(
  () => command('advance', id, item.revision, { repository: 'https://evil.example/path' }),
  'M3 requires GitHub',
);
item = await command('advance', id, item.revision, {
  repository: 'https://github.com/connection-cyber-so/connectioncyber',
});
await denied(() => command('advance', id, item.revision, {}), 'M4 requires review evidence');
item = await command('advance', id, item.revision, {
  rights: true,
  secrets_checked: true,
  technical_checked: true,
  evidence: 'Synthetic independent technical validation evidence',
});
ok(item.stage === 4, 'independent reviewer releases');
await as(reader);
ok((await db.query('select * from public.kb_items')).rows.length === 1, 'subscriber reads release');
ok(
  (await db.query('select * from public.kb_versions')).rows.length === 0,
  'subscriber cannot read historical drafts',
);
await command('favorite', id, null, { enabled: true });
await command('rate', id, null, { rating: 5, comment: 'Useful' });
await command('download', id, null, {});
ok((await db.query('select * from public.kb_favorites')).rows.length === 1, 'favorite persists');
await as(outsider);
ok(
  (await db.query('select * from public.kb_items')).rows.length === 0,
  'cross tenant released item blocked',
);
await as(author);
await denied(() => command('rate', id, null, { rating: 5 }), 'self rating denied');
item = await command('revise', id, item.revision, { title: 'New revision', body: 'select 2;' });
ok(item.stage === 0, 'revision returns to M0');
await as(reader);
ok(
  (await db.query('select * from public.kb_items')).rows.length === 0,
  'revised content is unpublished',
);
await db.exec('reset role');
await db.exec(
  `update public.kb_entitlements set ends_at=now()-interval '1 second' where user_id='${reader}'`,
);
await as(reader);
await denied(
  () => command('create', null, null, { title: 'Expired', kind: 'code' }),
  'expired subscription denied',
);
await db.exec('reset role');
await db.exec('set role anon');
await denied(() => db.query('select public.kb_context($1)', [t]), 'anonymous context denied');
await db.exec('reset role');
ok(
  (await db.query('select * from public.kb_events')).rows.length >= 8,
  'audit persists successful operations',
);
// Final summary follows the adversarial storage cases below.
/*console.log(JSON.stringify({passed,engine:'PGlite PostgreSQL',scope:'0043 with synthetic prerequisite tables and original authorization helper functions'}));
 */
await as(author);
let fileItem = await command('create', null, null, { title: 'Synthetic attachment', kind: 'file' });
let reserved = await command('reserve_asset', fileItem.id, fileItem.revision, {
  filename: 'reference.sql',
  mime: 'text/plain',
  size_bytes: 9,
  sha256: 'a'.repeat(64),
});
const assetId = reserved.reserved_asset_id;
const objectPath = reserved.reserved_path;
await denied(
  () => command('finalize_asset', fileItem.id, reserved.revision, { asset_id: assetId }),
  'missing storage object cannot finalize',
);
await as(reader);
await denied(
  () =>
    db.query("insert into storage.objects(bucket_id,name) values('knowledge-base',$1)", [
      objectPath,
    ]),
  'another subscriber cannot upload reserved object',
);
await as(author);
await denied(
  () =>
    db.query("insert into storage.objects(bucket_id,name) values('knowledge-base',$1)", [
      objectPath + '-forged',
    ]),
  'unreserved path blocked',
);
await db.query("insert into storage.objects(bucket_id,name) values('knowledge-base',$1)", [
  objectPath,
]);
fileItem = await command('finalize_asset', fileItem.id, reserved.revision, { asset_id: assetId });
ok(
  (await db.query('select * from storage.objects')).rows.length === 0,
  'author cannot directly read quarantined bytes',
);
await as(curator, 'aal2');
ok(
  (await db.query('select * from storage.objects')).rows.length === 0,
  'curator requires audited inspection lease',
);
await command('inspect', fileItem.id, null, { asset_id: assetId });
ok(
  (await db.query('select * from storage.objects')).rows.length === 1,
  'curator can inspect quarantined bytes',
);
await denied(
  () =>
    command('review_asset', fileItem.id, fileItem.revision, {
      asset_id: assetId,
      approved: true,
      evidence: 'short',
    }),
  'file approval requires evidence',
);
fileItem = await command('review_asset', fileItem.id, fileItem.revision, {
  asset_id: assetId,
  approved: true,
  evidence: 'Synthetic isolated scan and hash verification evidence',
});
fileItem = await command('classify', fileItem.id, fileItem.revision, {
  taxonomy: Object.fromEntries(
    ['ai', 'sector', 'segment', 'theme', 'project', 'technical_application', 'repository'].map(
      (k) => [k, 'test'],
    ),
  ),
});
fileItem = await command('advance', fileItem.id, fileItem.revision, {});
fileItem = await command('advance', fileItem.id, fileItem.revision, {
  score: 80,
  application: 'Synthetic useful application evidence',
});
fileItem = await command('advance', fileItem.id, fileItem.revision, {
  repository: 'https://github.com/connection-cyber-so/connectioncyber',
});
fileItem = await command('advance', fileItem.id, fileItem.revision, {
  rights: true,
  secrets_checked: true,
  technical_checked: true,
  evidence: 'Synthetic independent security and rights evidence',
});
await as(author);
ok(
  (await db.query('select * from storage.objects')).rows.length === 0,
  'released bytes require audited download lease',
);
await command('download', fileItem.id, null, { asset_id: assetId });
ok(
  (await db.query('select * from storage.objects')).rows.length === 1,
  'approved released bytes visible to entitled author',
);
await db.query("update storage.objects set name='overwritten' where name=$1", [objectPath]);
ok(
  (await db.query('select name from storage.objects')).rows[0].name === objectPath,
  'object overwrite denied by RLS',
);
await as(outsider);
ok(
  (await db.query('select * from storage.objects')).rows.length === 0,
  'cross tenant bytes blocked',
);
await as(reader);
ok(
  (await db.query('select * from storage.objects')).rows.length === 0,
  'expired subscription cannot read bytes',
);
await as(curator, 'aal2');
let own = await command('create', null, null, { title: 'Curator own document', kind: 'study' });
own = await command('classify', own.id, own.revision, {
  taxonomy: Object.fromEntries(
    ['ai', 'sector', 'segment', 'theme', 'project', 'technical_application', 'repository'].map(
      (k) => [k, 'test'],
    ),
  ),
});
own = await command('advance', own.id, own.revision, {});
own = await command('advance', own.id, own.revision, {
  score: 90,
  application: 'Useful reference application evidence',
});
own = await command('advance', own.id, own.revision, {
  repository: 'https://github.com/connection-cyber-so/connectioncyber',
});
await denied(
  () =>
    command('advance', own.id, own.revision, {
      rights: true,
      secrets_checked: true,
      technical_checked: true,
      evidence: 'Self approval must never pass even with permission',
    }),
  'curator cannot release own content',
);
await as(author);
let draft = await command('create', null, null, { title: 'AI request budget', kind: 'prompt' });
for (let n = 0; n < 3; n++) await command('ai_request', draft.id, draft.revision, {});
await denied(
  () => command('ai_request', draft.id, draft.revision, {}),
  'AI requests throttled atomically',
);
await db.exec('reset role');
await db.exec(
  "update public.kb_entitlements set status='suspended' where user_id='" + author + "'",
);
await as(author);
await denied(
  () => command('create', null, null, { title: 'Suspended access', kind: 'code' }),
  'suspended subscription denied',
);
await db.exec('reset role');
await db.exec(
  "update public.kb_entitlements set status='active',starts_at=now()+interval '1 hour' where user_id='" +
    author +
    "'",
);
await as(author);
await denied(
  () => command('create', null, null, { title: 'Future access', kind: 'code' }),
  'future subscription denied',
);
await db.exec('reset role');
ok(
  (
    await db.query(
      "select count(*)::int as n from pg_tables where schemaname='public' and tablename like 'kb_%' and rowsecurity",
    )
  ).rows[0].n === 7,
  'RLS enabled on all seven KB tables',
);
console.log(
  JSON.stringify({
    passed,
    engine: 'PGlite PostgreSQL',
    scope:
      '0043 with synthetic prerequisite tables and original authorization helper functions; Storage SQL policies, not the Storage HTTP service',
  }),
);
await db.close();
