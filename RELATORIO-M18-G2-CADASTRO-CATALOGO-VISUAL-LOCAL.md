# M18-G2 — cadastro e catálogo na fronteira visual local

Data: 31/08/2026

Resultado: aprovado localmente.

## Entrega

- `/cadastros` passou a executar `party.create` pelo cliente server-side M18.
- `/catalogo` passou a executar `catalog.item.create` pela mesma fronteira.
- Transporte local sintético compartilha snapshots de clientes e produtos durante a sessão do servidor.
- Tenant sintético permanece somente no módulo server-side e não aparece nas páginas ou formulários.
- Unidade `UN` é fixa neste gate; criação de unidades permanece bloqueada porque não integra as sete RPCs contratadas.
- As duas telas informam explicitamente que os registros são sintéticos, não chegam ao Supabase e desaparecem ao reiniciar.

## Segurança

1. Ações não importam `createClient`, `requireCurrentTenantId` ou serviços de escrita Supabase.
2. Payload de cliente contém somente dados comerciais validados; papel comercial não é confundido com papel de acesso.
3. Payload de produto não contém tenant, ator, preço, saldo ou autorização.
4. Apenas duas RPCs estão habilitadas no transporte M18-G2; demais comandos falham fechado.
5. Duplicidade de CPF/CNPJ ou código de item retorna erro público idempotente.

## Evidências

- 40/40 testes da plataforma aprovados, incluindo oito testes específicos M18-G2.
- 49/49 testes do contrato visual aprovados.
- TypeScript, ESLint e build Next.js aprovados.
- Rotas `/cadastros` e `/catalogo` compiladas como páginas dinâmicas.
- Supabase, banco, Vercel, GitHub remoto e produção não acessados.
- Contas e dados reais criados: zero.

Marcador: `M18_G2_MASTER_DATA_VISUAL_LOCAL_OK`.

Próxima etapa automática: **M18-G3 — integrar estoque, abertura de caixa e PDV à fronteira visual, inicialmente com transporte local sintético.**
