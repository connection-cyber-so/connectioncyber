# M22 — Biblioteca Técnica — Arquitetura 0.1.0

## Estado e fronteiras

Implementação local protegida por feature flag. Não ativada em banco remoto ou produção. O catálogo é por empresa; não há compartilhamento automático entre tenants. O site público e a área de alunos não foram convertidos em portal ERP.

## Contratos e responsabilidades

- UI: apps/portal/src/app/(portal)/biblioteca: catálogo, novo item, página do item, administração.
- Domínio e serviços: apps/portal/src/features/knowledge-base. Tipos, validações, contexto autorizado, consultas, comandos e adaptador Gemini separados.
- Transporte: POST /api/knowledge-base para formulários; GET /api/knowledge-base/[id]/download para conteúdo ou anexo. Tenant derivado exclusivamente de loadPortalAccess.
- Persistência: public.kb_command serializa comandos por usuário/tenant e bloqueia o item; exige revisão atual nas mutações de conteúdo. public.kb_context informa acesso/curadoria sem conceder privilégios.
- Banco: migration 0043_m22_knowledge_base.sql, aditiva, sem seed de usuários, assinatura, papel, cliente ou conteúdo real.
- Não utiliza service-role na aplicação. O Supabase SSR usa JWT validado e RLS. Toda API repete a autorização; layout não é a única barreira.

## Modelo de dados

| Tabela | Responsabilidade | Chave/isolamento |
|---|---|---|
| kb_entitlements | Assinatura verificada, intervalo de vigência e referência comercial | tenant_id + user_id |
| kb_items | Conteúdo atual, classificação, score, gate e revisão | tenant_id + id |
| kb_versions | Snapshot de conteúdo e anexos em cada alteração | item_id + revision; FK composta |
| kb_events | Ator, ação, revisão, evidência e solicitação de download | tenant_id + item_id |
| kb_assets | Arquivo imutável, SHA256 declarado, tamanho, quarentena e decisão | tenant_id + item_id; object_path único |
| kb_favorites | Favorito pessoal | item_id + user_id |
| kb_ratings | Uma avaliação por pessoa e item, substituível | item_id + user_id |

Todas as sete tabelas têm RLS. authenticated tem SELECT com policies; as escritas de conteúdo são somente por RPC autorizada. Assinatura é provisionada por operador/backend confiável, fora do navegador. Tokens comerciais nunca entram em external_reference.

Índices: GIN em tsvector português e tags; catálogo tenant/gate/atualização; eventos por item. Filtros por tipo, todas as sete dimensões, tag, score mínimo, gate e favoritos. Ordenação por atualização ou score, com desempate por ID. Paginação de 24 itens. Histórico exibe as 50 revisões e 100 eventos mais recentes; dados anteriores permanecem no banco para consulta administrativa.

## Matriz de acesso

| Perfil | Ler | Escrever | Liberar |
|---|---|---|---|
| Anônimo/sem assinatura vigente | Nada | Nada | Nada |
| Assinante com membership vigente | M4 da própria empresa; próprias entradas | Criar e revisar próprias entradas; classificar; avaliar itens de outros autores; favoritos | Não |
| Curador com knowledge.manage e AAL2 | Conteúdo da própria empresa e quarentena mediante evento de inspeção | Classificação, revisão, gates e anexos | M4 exige outro autor e outro último editor do conteúdo |
| Staff sem membership/assinatura | Sem bypass | Sem bypass | Sem bypass |

Permissões e assinatura são cumulativas. Status active exige início <= agora e fim > agora. Membership, usuário e empresa devem estar ativos. Papéis que exigem MFA bloqueiam o acesso abaixo de AAL2, inclusive na RLS. knowledge.manage não é atribuído automaticamente.

## Máquina de estados do conteúdo

| Transição | Critério | Efeito |
|---|---|---|
| Criar → M0 | Tipo válido, título, limites e URL quando necessária | v1, autor e último editor registrados |
| M0 → M1 | Todas as dimensões preenchidas e curador autenticado com MFA | Classificação aprovada |
| M1 → M2 | Aplicação técnica com evidência; score 60–100 | Uso documentado |
| M2 → M3 | URL de repositório GitHub válida | Destino confirmado, sem escrita no GitHub |
| M3 → M4 | Direitos, segredos e qualidade técnica revisados; evidência >=20 caracteres; anexos resolvidos; revisão independente | Item disponível aos assinantes |
| Revisar → M0 | Autor ou curador e revisão atual | Retira da liberação, preserva snapshots anteriores |

As sete dimensões são IA, setor, segmento, tema, projeto, aplicação técnica e repositório. O score técnico é avaliação da curadoria, separado da nota comunitária 1–5. A sugestão de pasta GitHub é determinística e revisável; nenhuma branch, commit ou PR de conteúdo é publicado automaticamente.

## Arquivos, importação e downloads

Entrada aceita prompt, link, vídeo, script, código, migração, estudo e arquivo. Links são referências: o servidor não faz crawler, não baixa URLs arbitrárias e não executa scripts. Importação consiste em colar conteúdo/URL e anexar arquivo; não há ingestão automática de repositórios ou transcrição de vídeo.

Upload: até 3 MiB por arquivo e 30 anexos por item. Formatos: PDF, TXT, MD, JSON, CSV, ZIP, SQL, JS, TS, PY, SH, PS1, MP4 e WEBM. Vídeos maiores devem ser referenciados por link. A requisição é lida com teto de 4 MiB, mantendo folga sob o limite de 4,5 MB da Vercel.

Reserva de caminho aleatório → upload sem upsert em bucket privado → finalização confere existência do objeto → quarentena. Falha de upload deixa reserva pendente visível; outro curador pode rejeitá-la. Não há exclusão automática de objetos ou dados.

SHA256 do fluxo normal é calculado no servidor; chamadas diretas ao RPC podem declarar metadados. Por isso a aprovação exige inspeção real independente, conferência do hash/tamanho e evidência. Este módulo não inclui engine antimalware: a inspeção ocorre em ambiente isolado do operador. ZIPs e scripts nunca são abertos/executados pelo sistema. O revisor não pode aprovar anexo próprio. Arquivos não resolvidos impedem M4.

Storage exige autorização por tenant, estado do item/anexo e um evento de download/inspeção nos últimos 60 segundos. A rota registra esse evento antes de assinar. URLs assinadas duram 60 segundos, são para download, têm no-store e não são registradas em logs. A revogação não invalida uma URL assinada já emitida durante essa janela. Auditoria mede solicitação autorizada, não conclusão da transferência nem cada reutilização da mesma URL.

Preflight deve inspecionar todas as policies remotas de Storage: policies permissivas alheias podem ampliar SELECT/INSERT. As policies restritivas de UPDATE/DELETE e anon protegem contra mudanças indevidas no bucket. O ambiente remoto não foi inspecionado nesta entrega.

## IA

Adaptador Gemini REST com modelo explicitamente configurado em KB_GEMINI_MODEL e chave server-only KB_GEMINI_API_KEY. Sem valores secretos no repositório. Não há modelo presumido nem fallback que finja resultado de IA.

Consentimento por operação antes de enviar título/tipo e até 12.000 caracteres ao provedor. Conteúdo tratado como dados não confiáveis, sem ferramentas. Resposta JSON validada e limitada; falha não altera classificação. Resultado permanece em M0 para revisão humana. Eventos registram provedor/modelo e pedido; nenhum prompt completo ou credencial vai para auditoria. Limite de 3 pedidos de IA/minuto por usuário/empresa e 120 comandos bem-sucedidos/minuto no banco.

## Documentação e controle de mudança

Fonte canônica Markdown em staging/knowledge-base; HTML equivalente escapado; manifesto SHA256 dos arquivos do módulo. O prebuild gera automaticamente os arquivos, e o CI recusa divergências com --check. O manifesto identifica exatamente qual código acompanha a versão 0.1.0; mudanças de contrato exigem incremento explícito da versão e atualização desta especificação. Gerar HTML não comprova validade técnica das descrições.

## Referências técnicas consultadas

- Supabase Storage e RLS: https://supabase.com/docs/guides/storage/security/access-control
- Downloads privados e URLs assinadas: https://supabase.com/docs/guides/storage/serving/downloads
- Autorização em cada ponto de entrada Next.js: https://nextjs.org/docs/15/app/guides/data-security
- Limite de requisição da Vercel: https://vercel.com/docs/functions/limitations
