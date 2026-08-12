import React, { useEffect, useState } from 'react';
import Layout from '@/components/Layout';
import { useLanguage } from '@/context/LanguageContext';
import { isSupabaseConfigured } from '@/config/env';
import { getSupabaseClient } from '@/lib/supabaseClient';

interface Product {
  id: string;
  nome: string;
  tipo: 'fisico' | 'digital';
  preco: number;
  estoque: number | null;
}

const FALLBACK_PRODUCTS: Product[] = [
  { id: 'demo-p1', nome: 'Kit de Infraestrutura de Rede Corporativa', tipo: 'fisico', preco: 0, estoque: null },
  { id: 'demo-p2', nome: 'E-book: Governança de TI para PMEs', tipo: 'digital', preco: 0, estoque: null },
];

export default function ProdutosPage() {
  const { t } = useLanguage();
  const [products, setProducts] = useState<Product[]>(FALLBACK_PRODUCTS);

  useEffect(() => {
    if (!isSupabaseConfigured) return;
    (async () => {
      try {
        const supabase = getSupabaseClient();
        const { data, error } = await supabase
          .from('products')
          .select('id, nome, tipo, preco, estoque')
          .eq('status', 'ativo');
        if (!error && data && data.length > 0) setProducts(data as Product[]);
      } catch {
        // mantém fallback
      }
    })();
  }, []);

  return (
    <Layout title={t('nav.products')}>
      <section className="section">
        <div className="container" style={{ maxWidth: 780 }}>
          <div className="eyebrow">{t('nav.products')}</div>
          <h1>Produtos Físicos e Digitais</h1>
          <p style={{ fontSize: '1.05rem' }}>
            Produtos complementares à nossa consultoria: kits de infraestrutura, materiais de apoio e conteúdos
            digitais para acelerar a maturidade tecnológica da sua empresa.
          </p>
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <div className="grid grid-3">
            {products.map((p) => (
              <div key={p.id} className="card">
                <span className="badge">{p.tipo === 'digital' ? 'Digital' : 'Físico'}</span>
                <h3 style={{ marginTop: 12 }}>{p.nome}</h3>
                <p>
                  {p.preco > 0
                    ? p.preco.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })
                    : 'Sob consulta'}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>
    </Layout>
  );
}
