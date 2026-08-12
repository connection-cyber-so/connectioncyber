import React from 'react';
import Head from 'next/head';
import Header from './Header';
import Footer from './Footer';
import FloatingSocialButtons from './FloatingSocialButtons';

interface LayoutProps {
  children: React.ReactNode;
  title?: string;
  description?: string;
}

export default function Layout({ children, title, description }: LayoutProps) {
  const pageTitle = title
    ? `${title} | ConnectionCyber`
    : 'ConnectionCyber — Assessoria e Treinamento Tecnológico';
  const pageDescription =
    description ??
    'Tecnologia que traz conhecimento e gestão. Desenvolvimento de sistemas, treinamento tecnológico, assessoria técnica, implantação de sistemas e redes.';

  return (
    <>
      <Head>
        <title>{pageTitle}</title>
        <meta name="description" content={pageDescription} />
        <meta property="og:title" content={pageTitle} />
        <meta property="og:description" content={pageDescription} />
        <meta property="og:type" content="website" />
        <link rel="icon" href="/logo.png" />
      </Head>
      <a href="#main-content" className="skip-link">
        Pular para o conteúdo
      </a>
      <Header />
      <main id="main-content">{children}</main>
      <Footer />
      <FloatingSocialButtons />
    </>
  );
}
