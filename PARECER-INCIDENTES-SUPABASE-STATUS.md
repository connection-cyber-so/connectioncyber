# Parecer — Incidentes ativos no Supabase (status.supabase.com)

Data da análise: 04/09/2026 · Fonte: `status.supabase.com` (página oficial, capturada em
`DadosConnectionCyber/supabase/SUPABASE.txt` + `001.png`/`002.png`/`003.png`) e reconferida ao
vivo no momento deste parecer.

## 1. Do que se trata

Os arquivos são a página pública de status do Supabase — o provedor por trás dos dois projetos
deste ecossistema (`ozvylnaipubrmaadikvk`, staging; `qfggetvashdxyuvlhihq`, produção, ambos em
`sa-east-1`). Não é um problema do nosso código, é um incidente do lado do fornecedor,
acontecendo agora.

## 2. Estado ao vivo (reconferido, não só a captura de tela)

| Componente | Estado |
|---|---|
| **Management API** | 🔴 **Major Outage** |
| **API Gateway** | 🟠 **Degraded Performance** |
| Auth | 🟢 Operational |
| Database | 🟢 Operational |
| Dashboard | 🟢 Operational |
| Realtime / Storage / Connection Pooler | 🟢 Operational |

## 3. Os 3 incidentes

### 3.1 Project Lifecycle Actions com erro elevado em todas as regiões — **ativo agora**

- Início: 04/09/2026 00:15 UTC. Última atualização: 00:58 UTC — "aplicamos uma correção, mas a
  taxa de erro continua alta".
- Afeta: **criação, mudança de configuração, restart e mudança de tamanho de compute** de
  projetos — tudo que passa pela **Management API**.
- **Não afeta**: projetos já rodando, Data APIs (REST/PostgREST) nem conexão direta ao Postgres.
- Recomendação oficial do próprio Supabase: evitar essas 4 ações até o incidente fechar.

### 3.2 Erros 401 por rejeição de JWT — em mitigação desde 14/08, ainda não fechado

- Causa identificada: cache de tempo (stale time cache) fazendo JWTs recém-renovados serem
  rejeitados. Correção em teste interno, ainda não publicada (última atualização 02/09).
- Sintoma pra quem usa o produto: sessão caindo com 401 sem motivo aparente; reabrir/relogar
  costuma resolver na hora; reiniciar o projeto pelo dashboard também ajudou outros clientes.

### 3.3 Bloqueio de rede em Mianmar — sem relevância pra nós

- Afeta só ISPs específicos de Mianmar. Nenhum usuário nosso está lá. Citado só por completude.

## 4. O que isso significa pra este projeto, concretamente

| Ação | Depende de Management API? | Situação agora |
|---|---|---|
| `supabase db push` (aplicar migration nova) | Sim | Evitar até o incidente 3.1 fechar |
| `supabase migration list` / `db dump` | Parcial (só leitura) | Já testado hoje, funcionou — mas pode ficar lento/instável |
| Criar/restart/redimensionar projeto Supabase | Sim | **Não fazer agora** |
| Login/portal em produção (`apps/portal`, `apps/site`) | Não (usa Data API/Auth) | Sem impacto — Auth e Database operacionais |
| Ativação do usuário-piloto (M18-G22: aceitar convite + MFA) | Não diretamente | Sem impacto esperado; se aparecer 401 aleatório no meio do fluxo, é candidato a ser o incidente 3.2, não bug nosso — orientar a pessoa a tentar de novo |
| Deploy do `apps/portal` na Vercel | Não | Sem impacto — infraestrutura separada |

## 5. Recomendação

1. **Não abrir novas migrations nem mexer em configuração/restart de projeto Supabase** (staging
   ou produção) até o componente **Management API** voltar a "Operational" em
   `status.supabase.com` — o próprio fornecedor pede isso.
2. Trabalho já em andamento (Portão 0 — deploy do portal, DNS na Hostinger, ativação do
   usuário-piloto) **pode continuar normalmente** — nenhum desses passos depende da Management
   API.
3. Se o dono(a) da Mania de Modas relatar erro de login/sessão caindo sozinha ao tentar entrar
   pela primeira vez, checar `status.supabase.com` antes de investigar código — pode ser o
   incidente 3.2 (JWT), resolvido tentando de novo ou aguardando a correção oficial.
4. Revisitar este parecer quando o Management API voltar a "Operational" antes de retomar
   qualquer migration nova.

## 6. Não é bloqueio para o que está em curso

Nenhum dos 3 incidentes impede continuar o Portão 0 (deploy do `apps/portal`, DNS, ativação do
usuário-piloto) — o gargalo desta fase é a Hostinger, não o Supabase.
