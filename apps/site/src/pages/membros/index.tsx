import React from 'react';
import Layout from '@/components/Layout';
import ProtectedRoute from '@/components/ProtectedRoute';

/**
 * Área de Membros (estilo Netflix) — trilhas, progresso, quizzes, provas,
 * gamificação e recomendações. Protegida por autenticação Supabase.
 *
 * Esta página entrega a estrutura de navegação e os componentes de UI;
 * a integração de dados (progresso real, trilhas, IA/RAG) depende das
 * tabelas trails/enrollments/quizzes/exams definidas em
 * supabase/migrations/0001_init_schema.sql e é o próximo passo natural
 * de implementação incremental.
 */
export default function MembrosPage() {
  return (
    <ProtectedRoute allowedRoles={['aluno', 'admin', 'instrutor']}>
      <Layout title="Área de Alunos">
        <section className="section">
          <div className="container">
            <div className="eyebrow">Área de Alunos</div>
            <h1>Continue de onde parou</h1>

            <div className="grid grid-4" style={{ marginTop: 24 }}>
              {['Trilha: Redes Corporativas', 'Trilha: Governança de TI', 'Trilha: Dev de Sistemas', 'Trilha: Segurança'].map(
                (trilha) => (
                  <div key={trilha} className="card">
                    <div
                      style={{
                        height: 120,
                        borderRadius: 8,
                        background:
                          'linear-gradient(135deg, var(--cc-teal), var(--cc-primary))',
                        marginBottom: 12,
                      }}
                    />
                    <h4 style={{ marginBottom: 6 }}>{trilha}</h4>
                    <div style={{ background: 'var(--cc-border)', height: 6, borderRadius: 4 }}>
                      <div style={{ width: '35%', height: '100%', background: 'var(--cc-success)', borderRadius: 4 }} />
                    </div>
                  </div>
                )
              )}
            </div>

            <p style={{ marginTop: 40, fontSize: '0.85rem', color: 'var(--cc-text-muted)' }}>
              Módulos planejados nesta área: gamificação (pontos, medalhas, ranking), quizzes interativos,
              simulados e provas com correção automática, certificados, recomendações por IA/RAG e
              reconhecimento facial opcional para validação de presença — ver roadmap no README.
            </p>
          </div>
        </section>
      </Layout>
    </ProtectedRoute>
  );
}
