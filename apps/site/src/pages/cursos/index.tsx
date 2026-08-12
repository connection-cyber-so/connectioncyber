import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import Layout from '@/components/Layout';
import { useLanguage } from '@/context/LanguageContext';
import { isSupabaseConfigured } from '@/config/env';
import { getSupabaseClient } from '@/lib/supabaseClient';
import { routes } from '@/config/routes';

interface Course {
  id: string;
  titulo: string;
  descricao: string;
  categoria: string;
  preco: number;
  idioma: string;
}

const FALLBACK_COURSES: Course[] = [
  {
    id: 'demo-1',
    titulo: 'Formação em Infraestrutura e Redes Corporativas',
    descricao: 'Fundamentos de redes cabeadas, Wi-Fi e segurança de rede para times de TI.',
    categoria: 'Infraestrutura',
    preco: 0,
    idioma: 'pt-BR',
  },
  {
    id: 'demo-2',
    titulo: 'Assessoria e Governança de TI',
    descricao: 'Planejamento tecnológico, auditoria de sistemas e acompanhamento técnico contínuo.',
    categoria: 'Gestão de TI',
    preco: 0,
    idioma: 'pt-BR',
  },
  {
    id: 'demo-3',
    titulo: 'Desenvolvimento de Sistemas Corporativos',
    descricao: 'Arquitetura moderna, segurança avançada e escalabilidade na prática.',
    categoria: 'Desenvolvimento',
    preco: 0,
    idioma: 'pt-BR',
  },
];

export default function CursosPage() {
  const { t } = useLanguage();
  const [courses, setCourses] = useState<Course[]>(FALLBACK_COURSES);
  const [source, setSource] = useState<'supabase' | 'demo'>('demo');

  useEffect(() => {
    if (!isSupabaseConfigured) return;
    let active = true;
    (async () => {
      try {
        const supabase = getSupabaseClient();
        const { data, error } = await supabase
          .from('courses')
          .select('id, titulo, descricao, categoria, preco, idioma')
          .eq('status', 'publicado');
        if (!error && data && data.length > 0 && active) {
          setCourses(data as Course[]);
          setSource('supabase');
        }
      } catch {
        // mantém fallback de demonstração
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  return (
    <Layout title={t('courses.title')} description={t('courses.subtitle')}>
      <section className="section">
        <div className="container" style={{ maxWidth: 780 }}>
          <div className="eyebrow">{t('nav.courses')}</div>
          <h1>{t('courses.title')}</h1>
          <p style={{ fontSize: '1.05rem' }}>{t('courses.subtitle')}</p>
          <div style={{ display: 'flex', gap: 10, marginTop: 8 }}>
            {(t('courses.modalities') as string[]).map((m) => (
              <span key={m} className="badge">
                {m}
              </span>
            ))}
          </div>
          {source === 'demo' && (
            <p style={{ fontSize: '0.8rem', marginTop: 8, color: 'var(--cc-warning)' }}>
              Exibindo cursos de demonstração — conecte o Supabase (tabela <code>courses</code>) para listar
              o catálogo real.
            </p>
          )}
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <div className="grid grid-3">
            {courses.map((c) => (
              <div key={c.id} className="card">
                <span className="badge">{c.categoria}</span>
                <h3 style={{ marginTop: 12 }}>{c.titulo}</h3>
                <p>{c.descricao}</p>
                <Link href={routes.contato} className="btn btn-outline-dark" style={{ marginTop: 8 }}>
                  {t('courses.cta')}
                </Link>
              </div>
            ))}
          </div>
        </div>
      </section>
    </Layout>
  );
}
