# M21-G7 — provisionamento real: Casa de Bolos Aconchego + Loja da Benção (MEI)

Data: 08/09/2026

Ambiente: Supabase staging `ozvylnaipubrmaadikvk` — **escrita real, dado real de identidade**

Resultado: **APROVADO E PROVISIONADO**

## Escopo

Execução de ponta a ponta, autorizada pelo usuário, do provisionamento real dos dois
clientes decididos em `IMPLANTACAO-CASA-DE-BOLOS-MEI.md`, usando a função original do M18
(`erp_prepare_pilot_provisioning_v1`, migration `0034`) e a extensão do M21-G6
(`erp_prepare_pilot_establishment_v1`, migration `0042`) — a primeira vez que a extensão do
M21-G6 roda contra dado real, não só contra o teste local/sintético.

## Execução

Diferente do M18-G21 (executado por script PowerShell), esta rodada foi executada **via SQL
Editor do painel Supabase**, com `set_config('request.jwt.claim.role','service_role',true)`
por transação — o script PowerShell original (`Invoke-Provisioning-*.ps1`) bateu num
mecanismo do Supabase que recusa uso de chave secreta em requisição HTTP com perfil de
navegador (`Forbidden use of secret API key in browser`); em vez de mascarar isso alterando
cabeçalhos da requisição (evitado de propósito — pareceria contornar um controle de
segurança do provedor), o caminho adotado foi o SQL Editor, que não depende da chave
secreta em HTTP nenhuma.

Cada chamada de escrita (preparar tenant/estabelecimento, registrar identidade Auth,
finalizar identidade/membership) foi feita manualmente no SQL Editor, com verificação no
banco logo em seguida, na mesma sessão/transação — sem exceção.

## Achados durante a execução

1. **Uma tentativa isolada não deixou rastro** (`idempotencyKey` `...-casadebolos-v1`): a
   função retornou um resultado aparentemente bem-sucedido (IDs válidos), mas nenhuma linha
   correspondente existia no banco em consultas subsequentes — nem na mesma sessão de
   verificação futura. Causa raiz não identificada (branch única confirmada, não é o caso
   de branching do Supabase). Resolvido reexecutando com nova `idempotencyKey` (`-v2`) e
   confirmando existência do registro **dentro da mesma transação e depois do commit**, no
   mesmo clique de execução — a partir daí, toda escrita foi verificada dessa forma.
2. **Link de convite expirado**: o primeiro convite da Eliana (Casa de Bolos) expirou antes
   dela conseguir aceitar, por causa do tempo gasto investigando o achado acima.
3. **Limite de e-mail do Supabase esgotado**: o serviço de e-mail padrão/gratuito do
   Supabase (usado por `Invite user`) tem limite baixo (poucos e-mails/hora); ao tentar
   reenviar o convite da Eliana e enviar o da Eliane, o segundo bateu no limite
   (`email rate limit exceeded`).
4. **Correção estrutural, não só contorno pontual**: configurado SMTP próprio (Resend, já
   usado no projeto) em Authentication → Emails → SMTP Settings — sobe o limite de 3 para
   30 e-mails/hora e vale para todo envio de Auth daqui pra frente, não só estes 3 convites.
5. **Lacuna do M18 original**: `erp_prepare_pilot_provisioning_v1` nunca grava
   `erp_establishments.vertical_code` (coluna que só passou a existir na migration `0038`,
   depois da `0034`) — os dois estabelecimentos criados por ela nesta rodada (Casa de Bolos,
   Unidade1-Aldo) precisaram de um `UPDATE` manual pontual pra preencher a vertical. A
   função nova do M21-G6 (`erp_prepare_pilot_establishment_v1`) já recebe `verticalCode`
   como campo obrigatório — a Unidade2-Eliane já nasceu correta.

## Resultado final confirmado no banco

- **Casa de Bolos Aconchego**: 1 tenant, 1 estabelecimento (`MATRIZ`, vertical
  `casa_de_bolos`), 1 membership `owner` com MFA obrigatório, convite aceito pelo link
  reenviado após a correção de SMTP.
- **Loja da Benção**: 1 tenant combinado, 2 estabelecimentos (`UNIDADE1`/Aldo e
  `UNIDADE2`/Eliane, ambos vertical `celular_multi_cnpj`), 2 memberships `owner` com MFA
  obrigatório — confirmado `total_memberships = 2` no mesmo `tenant_id`.
- Todos os `state_registration` gravados corretamente (Casa de Bolos com IE real; Aldo e
  Eliane com `ISENTO`, confirmado por consulta oficial SIMEI antes da execução).

## Segurança

- CNPJ, e-mail e demais dados de identidade real nunca entraram neste relatório nem em
  nenhum arquivo do repositório Git — todo SQL com dado real (dele em texto puro) foi salvo
  fora do repositório, em `C:\Users\joaqu\Downloads\DadosConnectionCyber\ArquvosSqlsC\`, por
  instrução explícita do usuário.
- Nenhuma senha de cliente foi definida ou vista pela ConnectionCyber — os 3 acessos foram
  criados por convite (`Invite user via email`), cada responsável define a própria senha.
- Chave `service_role`/API key do Resend nunca passaram por este agente — toda operação com
  segredo foi feita pelo usuário diretamente no painel Supabase/Resend.

## Ambiente / efeitos remotos

Escrita real em staging (`ozvylnaipubrmaadikvk`): 2 tenants novos, 3 estabelecimentos, 3
usuários Auth reais (convidados por e-mail), 3 memberships `owner`. SMTP customizado
(Resend) ativado para o projeto — efeito permanente, vale para todo envio de Auth futuro.
Nenhuma produção (`main`) tocada.

## Pendências (documentadas, não bloqueiam o que já está no ar)

- Produto/Catálogo real ainda não existe no `apps/portal` para nenhum dos 3 estabelecimentos
  (mesma limitação já registrada no M21-G4/G5 — falta `unit.create`).
- Causa raiz da tentativa `-v1` que não deixou rastro nenhum permanece desconhecida — não
  bloqueou o resultado final, mas vale investigar se se repetir em provisionamentos futuros.

## Decisão

**GATE_CONCLUIDO.** Próximo passo natural: confirmar com os 3 responsáveis (Eliana, Aldo,
Eliane) que aceitaram o convite e conseguem logar em `portal.connectioncyber.com.br`.
