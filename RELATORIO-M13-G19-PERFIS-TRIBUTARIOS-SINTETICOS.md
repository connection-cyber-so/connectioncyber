# M13-G19 — perfis tributários sintéticos

Data: 29/08/2026
Ambiente: staging local
Decisão: **APROVADO PARA DESENVOLVIMENTO; EMISSÃO REAL BLOQUEADA**

## Entrega

O motor agora resolve o perfil tributário por tenant e recusa combinações incompatíveis antes de gerar XML.

| Perfil | CRT | Código ICMS | Estado |
|---|---:|---|---|
| Regime Normal/RPA | 3 | CST | Liberado apenas para testes sintéticos |
| Simples Nacional | 1 | CSOSN | Liberado apenas para testes sintéticos |
| Simples com excesso de sublimite | 2 | CST | Liberado apenas para testes sintéticos |
| MEI | 4 | CSOSN | Bloqueado até regras oficiais e aprovação contábil |

## Controles

- tenant obrigatório e resolução sem acesso cruzado;
- CRT e família CST/CSOSN coerentes;
- NCM, CFOP de saída e versão da regra obrigatórios;
- aprovação contábil explícita obrigatória;
- produção proibida;
- zero XML, assinatura, persistência ou transmissão.

## Evidências

- suíte fiscal: `234/234` testes aprovados;
- marcador: `M13_G19_SYNTHETIC_PROFILES_OK`;
- versão de regra sintética fixada: `NFE_4.00_2026.06`;
- Supabase remoto e produção: não acessados.

## Empresa-piloto

O cadastro oficial indica Regime Normal/RPA. A vinculação definitiva continua bloqueada até confirmação de CRT, CST, NCM, CFOP, série, número e credenciamento. Nenhum dado real foi gravado.
