import { CrmShell } from '@/components/crm/CrmShell';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type PageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
};

// Placeholder de módulos do menu que ainda não foram portados do protótipo.
export default async function EmConstrucaoPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const raw = typeof params.modulo === 'string' ? params.modulo : '';
  const modulo = raw.slice(0, 60) || 'Módulo';

  return (
    <CrmShell>
      <div style={{ padding: '24px 28px' }}>
        <h1 style={{ margin: 0, fontSize: 26 }}>{modulo}</h1>
        <p style={{ margin: '12px 0 0', opacity: 0.7 }}>
          Em construção. Esta tela ainda não foi portada do protótipo.
        </p>
      </div>
    </CrmShell>
  );
}
