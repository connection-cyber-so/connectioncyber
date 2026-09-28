# Parecer técnico M13-G0 — fiscal, NF-e/NFC-e, contingência e certificado A1

Data: 28/08/2026  
Ambiente analisado: desenvolvimento/staging  
Decisão: viável com isolamento por tenant, motor fiscal desacoplado e segredos fora do banco e do navegador.

## 1. Decisão arquitetural

O fiscal será um contexto separado do PDV, financeiro e agente local. A venda aprovada cria uma solicitação fiscal idempotente; um serviço de backend valida, numera, assina, transmite e reconcilia. Navegador, PDV e agente local nunca recebem certificado, senha, CSC ou credencial da SEFAZ.

Recomendação inicial: integrar por uma interface neutra de provedor fiscal, começar com provedor homologado e preservar no domínio próprio o XML autorizado, protocolo, eventos, hashes e trilha de auditoria. Integração direta com cada SEFAZ somente após matriz técnica demonstrar vantagem operacional e equipe para acompanhar notas técnicas, schemas, indisponibilidades e particularidades por UF.

## 2. Isolamento e autorização

- Todas as entidades fiscais terão `tenant_id`, RLS e testes negativos cross-tenant.
- Papéis separados: `fiscal.read`, `fiscal.issue`, `fiscal.cancel`, `fiscal.configure`, `fiscal.certificate.manage` e `fiscal.audit`.
- Configuração tributária, certificado, cancelamento e inutilização exigirão MFA/AAL2 e auditoria imutável.
- O serviço de assinatura/transmissão terá privilégio mínimo; `service_role` não será exposto a aplicações clientes.
- Homologação e produção terão projetos, credenciais, séries, filas, webhooks e armazenamento separados.

## 3. Certificado A1 e evolução criptográfica

O arquivo PFX e sua senha não serão gravados no PostgreSQL, Git, `.env.local`, Vercel compartilhado, logs, navegador ou dispositivo do operador. O banco guardará apenas referência opaca do segredo, CNPJ/subject, emissor, número de série, impressão digital, validade, estado e modalidade de custódia.

Custódia preferencial: provedor fiscal ou cofre/KMS/HSM dedicado com criptografia por envelope, chave por tenant, rotação, acesso auditado e destruição verificável. A importação, quando necessária, ocorrerá apenas em backend seguro e sem persistir arquivo temporário além da operação.

A interface de assinatura será independente do PFX e aceitará `software_a1`, `remote_hsm`, `provider_custody` e `electronic_seal`. Essa abstração é obrigatória porque a ICP-Brasil prevê transição futura das assinaturas de pessoa jurídica para selo eletrônico em processos automatizados.

## 4. Modelo fiscal proposto para o M13-G2

Próxima migration local prevista: `0030`, sem execução remota automática.

- `erp_tax_regimes`, `erp_tax_profiles`, `erp_tax_rules` e `erp_fiscal_schema_versions`;
- `erp_fiscal_series` e `erp_fiscal_number_reservations` com exclusividade por tenant, modelo, série, número e ambiente;
- `erp_fiscal_documents` e `erp_fiscal_document_items` com fotografia tributária imutável;
- `erp_fiscal_transmissions`, `erp_fiscal_events` e `erp_fiscal_contingencies` append-only;
- `erp_fiscal_xml_artifacts` com caminho protegido, hash, versão do schema e protocolo;
- `erp_certificate_refs` sem material criptográfico nem senha.

Documentos antigos não serão recalculados quando uma regra tributária mudar. Cada emissão conservará valores, regras, versão de schema, origem e arredondamentos usados naquele instante.

## 5. Máquina de estados e idempotência

Fluxo-base: `draft → validated → queued → signing → signed → transmitting → authorized`. Saídas controladas: `rejected`, `denied`, `contingency_pending`, `cancelled` e eventos posteriores. Timeout não será tratado como rejeição: ele exige consulta e reconciliação para impedir emissão duplicada.

Chaves de idempotência incluirão tenant, ambiente, modelo, série, número e operação. Webhooks serão autenticados, tolerantes a repetição e reconciliados com consulta ativa. XML assinado, protocolo e eventos autorizados serão imutáveis e armazenados criptografados com hash; retenção será parametrizada conforme orientação fiscal, contábil e contratual aplicável.

## 6. NF-e, NFC-e e contingência

- NF-e e NFC-e compartilharão núcleo, mas terão regras, eventos, DANFE, QR Code e contingências distintas.
- Contingência offline será habilitada somente para NFC-e e somente quando a UF e a regra vigente permitirem.
- Nenhum prazo universal será fixado em código; regras por UF, ambiente e vigência serão versionadas.
- Venda offline do M12 não vira automaticamente documento fiscal: haverá fila fiscal assinada, impressão sinalizada, transmissão após recuperação e reconciliação antes de nova tentativa.
- CSC será tratado como segredo: apenas referência no cofre, nunca banco, browser, log ou repositório.
- O motor aceitará coexistência de tributos legados e IBS/CBS, com catálogos oficiais importados por versão, vigência e hash; alíquotas e códigos não serão hardcoded na aplicação.

## 7. Provedor fiscal — critérios do portão

Antes de contratar ou integrar, comparar: UFs/modelos atendidos, atualização de notas técnicas e RTC, homologação, contingência, SLA, fila e consulta, assinatura/custódia, webhook assinado, idempotência, exportação integral de XML/protocolos, LGPD, resposta a incidentes, suporte e saída sem lock-in.

## 8. Riscos bloqueadores

1. Segredo fiscal em banco/browser/log: bloqueio absoluto.
2. Numeração concorrente ou repetida: reserva transacional e reconciliação obrigatórias.
3. Regra fiscal codificada sem vigência: catálogo versionado obrigatório.
4. Timeout tratado como falha definitiva: consulta de situação obrigatória.
5. Mistura homologação/produção: credenciais e filas fisicamente separadas.
6. Contingência genérica para todas as UFs/modelos: configuração oficial por vigência.
7. Dependência irreversível do provedor: contrato canônico e exportação integral.

## 9. Portões determinísticos

1. **M13-G0 — concluído:** parecer, fronteiras, riscos e critérios.
2. **M13-G1 — automático local:** contrato canônico, modelo de ameaças e matriz de provedores; sem credenciais.
3. **M13-G2 — automático local:** migration `0030`, preflight, rollback, pgTAP e simuladores; sem aplicação remota.
4. **M13-G3/G4 — autorização explícita:** validação transacional e depois aplicação exclusiva no Supabase staging.
5. **M13-G5/G6 — autorizações separadas:** provedor em homologação com dados sintéticos; certificado real/piloto e produção continuam bloqueados.

## 10. Critérios de aceite

RLS negativa por tenant, segredo ausente do banco/log/browser, numeração concorrente segura, idempotência comprovada, máquina de estados testada, reconciliação após timeout, contingência por UF, XML/protocolo íntegros, catálogos versionados, rollback sem resíduos e zero dados/certificados reais antes do portão específico.

Este documento é um parecer de arquitetura. Regras fiscais, tributárias, de guarda e operação por UF/regime deverão ser validadas por contador e assessoria fiscal antes da homologação e da produção.

## 11. Fontes oficiais verificadas

- Portal Nacional da NF-e — manuais e MOC: https://www.nfe.fazenda.gov.br/portal/consulta.aspx/listaConteudo.aspx?tipoConteudo=ndIjl+iEFdE%3D
- Portal Nacional da NF-e — contingência offline NFC-e: https://www.nfe.fazenda.gov.br/pOrtaL/listaHistorico.aspx?tipoConteudo=GKxb5ZZeQIM%3D
- Portal Nacional da NF-e — informes e notas técnicas: https://www.nfe.fazenda.gov.br/portal/informe.aspx?AspxAutoDetectCookieSupport=1&ehCTG=false&page=1&pagesize=30
- ITI — perguntas frequentes sobre certificação digital: https://www.gov.br/iti/pt-br/acesso-a-informacao/perguntas-frequentes/certificacao-digital
- ITI — modernização da ICP-Brasil: https://www.gov.br/iti/pt-br/assuntos/consulta-publica/consultas-anteriores/01-2024-modernizacao-da-icp-brasil/questionamentos-mais-frequentes

