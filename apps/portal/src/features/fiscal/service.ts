import 'server-only';
import { createClient } from '@/lib/supabase/server';

type PortalClient = Awaited<ReturnType<typeof createClient>>;

// M24 - Envio ao contador: pacote fiscal mensal (XML + DANFE) com recibo e visao
// cross-tenant do papel contador SEMPRE pela RPC auditada (nenhum select direto).

export type AccountantFile = {
  id: string;
  package_id: string;
  storage_path: string;
  file_name: string;
  content_hash: string;
  byte_size: number;
  kind: 'xml' | 'danfe';
  url?: string;
};

export type AccountantPackage = {
  id: string;
  tenant_id: string;
  competencia: string;
  status: 'ready' | 'acknowledged' | 'void';
  content_hash: string;
  file_count: number;
  total_bytes: number;
  acknowledged_at: string | null;
  acknowledged_note: string | null;
  created_at: string;
  tenant_nome?: string;
};

export type PackageView = { pkg: AccountantPackage; files: AccountantFile[] };

const PACKAGE_COLUMNS =
  'id, tenant_id, competencia, status, content_hash, file_count, total_bytes, acknowledged_at, acknowledged_note, created_at';

export async function isAccountant(supabase: PortalClient): Promise<boolean> {
  const { data, error } = await supabase.rpc('is_accountant');
  return !error && data === true;
}

export async function signFileUrl(supabase: PortalClient, path: string): Promise<string | null> {
  const { data, error } = await supabase.storage.from('fiscal-deliveries').createSignedUrl(path, 3600);
  if (error) return null;
  return data.signedUrl;
}

export async function logDownload(
  supabase: PortalClient,
  tenantId: string,
  packageId: string,
  fileCount: number
): Promise<void> {
  await supabase.rpc('erp_log_accountant_download', {
    p_tenant_id: tenantId,
    p_package_id: packageId,
    p_file_count: fileCount,
  });
}

// Visao do dono: select direto sob RLS (só o proprio tenant).
export async function listOwnPackages(
  supabase: PortalClient,
  tenantId: string
): Promise<AccountantPackage[]> {
  const { data, error } = await supabase
    .from('erp_accountant_packages')
    .select(PACKAGE_COLUMNS)
    .eq('tenant_id', tenantId)
    .order('competencia', { ascending: false })
    .limit(60);
  if (error) return [];
  return (data ?? []) as AccountantPackage[];
}

export async function listOwnFiles(
  supabase: PortalClient,
  packageIds: string[]
): Promise<AccountantFile[]> {
  if (packageIds.length === 0) return [];
  const { data, error } = await supabase
    .from('erp_accountant_package_files')
    .select('id, package_id, storage_path, file_name, content_hash, byte_size, kind')
    .in('package_id', packageIds)
    .order('file_name');
  if (error) return [];
  return (data ?? []) as AccountantFile[];
}

// Visao do contador: cross-tenant somente pela RPC (uma chamada = um log).
export async function listAccountantPackages(
  supabase: PortalClient
): Promise<Array<{ pkg: AccountantPackage; files: AccountantFile[] }>> {
  const { data, error } = await supabase.rpc('erp_list_accountant_packages', {
    p_tenant_id: null,
    p_limit: 60,
  });
  if (error || !Array.isArray(data)) return [];
  return data as Array<{ pkg: AccountantPackage; files: AccountantFile[] }>;
}

export async function buildPackageViews(
  supabase: PortalClient,
  tenantId: string,
  accountant: boolean
): Promise<PackageView[]> {
  if (accountant) {
    const rows = await listAccountantPackages(supabase);
    const views: PackageView[] = [];
    for (const row of rows) {
      const files: AccountantFile[] = [];
      for (const file of row.files) {
        const url = await signFileUrl(supabase, file.storage_path);
        files.push({ ...file, url: url ?? undefined });
      }
      await logDownload(supabase, row.pkg.tenant_id, row.pkg.id, files.length);
      views.push({ pkg: row.pkg, files });
    }
    return views;
  }
  const packages = await listOwnPackages(supabase, tenantId);
  const files = await listOwnFiles(supabase, packages.map((p) => p.id));
  return packages.map((pkg) => ({
    pkg,
    files: files
      .filter((f) => f.package_id === pkg.id)
      .map((f) => ({ ...f, url: undefined })),
  }));
}

export async function signOwnFiles(
  supabase: PortalClient,
  views: PackageView[]
): Promise<PackageView[]> {
  return Promise.all(
    views.map(async (view) => ({
      pkg: view.pkg,
      files: await Promise.all(
        view.files.map(async (file) => ({
          ...file,
          url: file.url ?? (await signFileUrl(supabase, file.storage_path)) ?? undefined,
        }))
      ),
    }))
  );
}
