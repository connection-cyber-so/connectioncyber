# Visão de longo prazo — mapa de 104 módulos

> Origem: material fornecido por Joaquim Coelho em `C:\Users\joaqu\Downloads\connectionHMTL\`
> (16 arquivos HTML), avaliado em 2026-08-15. **Arquivado como referência de longo prazo — nada
> deste documento foi implementado em código, schema ou rota.** O roteiro ativo do projeto
> continua sendo `docs/parecer-tecnico-arquitetura.md` e o plano de ação do `apps/platform`
> (Fases 0-7, ainda na Fase 0).

## O que é

Um mapa aspiracional de **104 módulos**, organizados em 10 camadas de 10 módulos cada, mais 4
módulos extras (101-104). Descreve até onde a plataforma poderia crescer se um dia operar em
escala de hyperscaler — não é o próximo passo técnico do projeto.

## Por que foi arquivado, e não implementado

1. **Descompasso de escala.** As camadas 6 a 10 (51-100) são infraestrutura de nível
   Netflix/Google — multi-cloud, multi-edge, multi-cluster, auto-scaling global, orquestração
   de IA. A base de clientes real hoje são pequenos negócios locais (oficina mecânica,
   distribuidora de água, sorveteria, rede de restaurantes) — não há cenário de negócio que
   justifique essa infraestrutura no horizonte visível.
2. **Falha de segurança no código de exemplo.** As rotas de API mostradas em `mod0010.html`
   (`/api/tenants/create`, `/api/users/update`) não verificam sessão nenhuma — qualquer
   chamador poderia criar um tenant ou alterar o `role` de qualquer usuário passando um `id`
   arbitrário. Isso contraria diretamente o modelo de isolamento já adotado no projeto (nunca
   confiar em dado vindo do cliente, sempre derivar o tenant da sessão no servidor). Se algum
   módulo desta lista for implementado no futuro, o código-fonte original **não deve ser
   copiado como está** — precisa ser reescrito com autenticação e RLS corretos.
3. **Incompatibilidade técnica pontual.** O módulo 101 (Atendimento Remoto) usa `BullMQ` +
   `Redis` para workers — não roda em função serverless da Vercel sem infraestrutura adicional
   (fila gerenciada, processo Node persistente). Não é um bloqueio, é um custo de infra que
   precisaria entrar na decisão.
4. **Sobreposição com o que já existe.** O módulo 104 ("Tecnologia Seletor de Idioma") descreve
   o seletor PT/EN que **já está implementado e documentado** em
   `docs/tecnologia-seletor-idioma.md`. Não há nada novo a trazer daqui.

## Mapa completo (referência)

### Camada 1 — Fundamentos (1-10)
Autenticação, Usuários, Tenants, Produtos, Checkout, Marketplace, Chat, Automação,
Notificações, E-commerce.

> Autenticação, Usuários e Tenants já têm equivalente real e mais robusto no projeto
> (`supabase/migrations/0001`-`0003`, com RLS e trigger de auto-provisioning). Produtos e
> Checkout ainda não existem — candidatos genuínos para quando `apps/platform` chegar à fase de
> módulos operacionais (Fase 7 do plano de ação).

### Camada 2 — Operações (11-20)
Pagamentos, Assinaturas, Logs, Estoque, Logística, Financeiro, Suporte, CRM, Marketing,
Analytics.

### Camada 3 — Integração (21-30)
Webhooks, Auditoria, Permissões, Uploads, Mídia, Templates, IA, Configurações, Dashboard,
Relatórios.

### Camada 4 — Sistema (31-40)
Tarefas, Calendário, Comentários, Notas Internas, Favoritos, Endereços, Catálogo, Cupons,
Frete, Logs de Erro.

### Camada 5 — Infraestrutura (41-50)
Exportação, Importação, Etiquetas, Logs de Acesso, Filas Internas, WebSockets, Sessões,
Histórico, Logs de Sistema, Integrações.

### Camada 6 — Arquitetura Distribuída (51-60)
Backup, Restauração, Segurança Avançada, Monitoramento, Alertas, IA de Segurança, Governança,
Orquestração Global, Orquestração Distribuída, Arquitetura Distribuída (Microserviços, Edge,
CDN, IA).

### Camada 7 — Escalabilidade (61-70)
Auto-Scaling, Balanceamento Global, Replicação de Dados, Failover, Latência, CDN Inteligente,
IA de Infraestrutura, Regiões, Orquestração Multi-Região, Zero-Downtime.

### Camada 8 — Multi-Cloud / Multi-Edge (71-80)
Multi-Cloud, Migração entre Clouds, Edge Routing, Edge Analytics, CDN Multi-Região, Cache
Multi-Região, IA de Latência, Infraestrutura Paralela, Orquestração Paralela, Infraestrutura
Autônoma.

### Camada 9 — Multi-Infraestrutura Avançada (81-90)
Infraestrutura Auto-Reparável, Observável, Preditiva, Modular, Multi-Tenant Avançado,
Multi-Região Avançado, Multi-Cluster, Multi-Zona, Multi-Edge, Multi-CDN.

### Camada 10 — Orquestração Total (91-100)
Orquestração de IA Global, de Fluxos Multi-Negócio, de Marketing Inteligente, de Vendas
Inteligente, de Operações Inteligente, de Infraestrutura Inteligente, Multi-Empresa,
Multi-Vertical, Multi-Plataforma, Orquestração Total.

### Extras (101-104)
101. Atendimento Remoto ao Cliente (vídeo/áudio/chat + diagnóstico IA — requer Redis/BullMQ)
102. BI Avançado
103. Plano de Contas
104. Tecnologia Seletor de Idioma — **já implementado**, ver `docs/tecnologia-seletor-idioma.md`

## Quando reconsiderar

As camadas 1-5 (módulos 1-50) contêm ideias genuinamente aproveitáveis conforme os módulos
operacionais forem sendo construídos módulo a módulo (Fase 7 do plano de ação do
`apps/platform`) — sempre reescritas com o padrão de segurança do projeto, nunca copiadas
diretamente. As camadas 6-10 (51-100) só voltam a fazer sentido reavaliar se a base de clientes
e a receita crescerem a ponto de justificar infraestrutura multi-região/multi-cloud — não é uma
decisão para o estágio atual do projeto.
