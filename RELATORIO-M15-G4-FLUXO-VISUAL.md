# M15-G4 — Primeiro fluxo visual demonstrável

Data: 30/08/2026

## Resultado

**APROVADO — dashboard demonstrável disponível localmente em `/demo`.**

## Entregas

- entrada “Abrir demonstração” quando o Supabase não está configurado;
- dashboard responsivo com marca ConnectionCyber;
- alternância interativa entre MEI, ME e LTDA;
- módulos de cadastros, estoque, vendas/PDV, caixa e financeiro;
- indicadores, acessos rápidos e pendências operacionais sintéticas;
- estoque indisponível no perfil MEI para demonstrar capacidades por plano;
- aviso permanente de ambiente local sem dados reais;
- rota sem indexação e sem cliente Supabase ou chamadas de rede.

## Quality gates

- portal: 24/24 testes;
- TypeScript: aprovado;
- ESLint: aprovado;
- build: aprovado, rota `/demo` gerada estaticamente;
- desktop: aprovado;
- troca MEI/ME/LTDA: aprovada;
- celular 390 × 844: aprovado, sem overflow da página; navegação permanece rolável dentro da própria barra.

## Limites

Nenhuma conta, tenant, fixture ou dado real foi criado. Supabase remoto, Vercel e produção não foram alterados.

## Como visualizar

Executar o portal de staging na porta 3021 e abrir `http://localhost:3021/demo`.
