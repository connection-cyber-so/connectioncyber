// Rota pública, sem autenticação — a página que o LEAD vê ao clicar num
// anúncio/link de uma oferta. Gerenciada em apps/platform ("/landing-pages"),
// servida aqui porque apps/site já é 100% público desde o início; ver
// docs/migracao-diagnostico-digital-cc-commerce-studio.md (decisão de
// arquitetura de 2026-08-15) e supabase/migrations/0012_modulo_landing_pages.sql.
//
// Funciona sem sessão porque a policy de RLS "público vê landing pages
// publicadas" não depende de auth.uid() — só de status = 'published' — e a
// tabela tem GRANT SELECT explícito para o role anon.
import type { GetServerSideProps, NextPage } from 'next';
import Head from 'next/head';
import { getSupabaseClient } from '@/lib/supabaseClient';

interface LandingPageProps {
  title: string;
  content: string | null;
}

const LandingPage: NextPage<LandingPageProps> = ({ title, content }) => {
  return (
    <>
      <Head>
        <title>{title} | ConnectionCyber</title>
        <meta name="description" content={content?.slice(0, 160) ?? title} />
        <meta property="og:title" content={title} />
        <meta property="og:type" content="website" />
        <link rel="icon" href="/logo.png" />
      </Head>
      <main id="main-content">
        <section className="section" style={{ minHeight: '70vh', display: 'flex', alignItems: 'center' }}>
          <div className="container" style={{ maxWidth: 720 }}>
            <h1>{title}</h1>
            {content && (
              <p style={{ marginTop: 20, fontSize: '1.1rem', lineHeight: 1.7, whiteSpace: 'pre-line' }}>{content}</p>
            )}
          </div>
        </section>
      </main>
    </>
  );
};

export const getServerSideProps: GetServerSideProps<LandingPageProps> = async (context) => {
  const slug = context.params?.slug;

  if (typeof slug !== 'string') {
    return { notFound: true };
  }

  try {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase
      .from('mpi_landing_pages')
      .select('title, content')
      .eq('slug', slug)
      .eq('status', 'published')
      .maybeSingle();

    if (error || !data) {
      return { notFound: true };
    }

    return { props: { title: data.title, content: data.content } };
  } catch {
    // Supabase não configurado (modo demonstração) — sem dado real pra mostrar.
    return { notFound: true };
  }
};

export default LandingPage;
