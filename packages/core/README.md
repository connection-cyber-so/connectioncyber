# packages/core — núcleo canônico compartilhado (M01 definido; implementação no M02+)

Lógica de domínio comum a todos os tenants da ConnectionCyber. O que muda por
empresa é a combinação de estabelecimentos, memberships, permissões,
capacidades e configurações tipadas — nunca um fork de código ou banco.

A decisão vigente está em `../../ARQUITETURA-CANONICA-MULTISSEGMENTO.md`.
O backup legado será uma fonte futura de migração e não definirá este núcleo.

Responsabilidades planejadas:

- contratos e tipos canônicos de tenant, estabelecimento e membership;
- resolução segura do contexto de tenant no servidor;
- catálogo de capacidades e perfis de segmento;
- validações compartilhadas de pessoas, catálogo, valores e quantidades;
- máquinas de estado e invariantes de estoque, comercial e financeiro;
- contratos versionados para importadores legados;
- utilitários sem dependência de interface ou fornecedor externo.

Não pertence a este pacote:

- componentes de interface;
- acesso direto ao banco a partir do navegador;
- segredos, PFX ou credenciais;
- tipos específicos das tabelas do site/Mercado Pago;
- regras codificadas para um cliente individual.
