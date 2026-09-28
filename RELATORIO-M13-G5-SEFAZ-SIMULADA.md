# M13-G5 — integração direta SEFAZ simulada

Data: 28/08/2026

## Resultado

- Adaptador local limitado à homologação simulada.
- Assinatura simulada sem certificado A1, chave privada ou XML fiscal válido.
- Cofre abstrato aceita apenas referências opacas; não importa nem exporta PFX.
- Transporte real, produção, CNPJ real, CSC e credenciais são recusados.
- Cenários autorizada, rejeitada, timeout e indisponibilidade são determinísticos.
- 68/68 testes aprovados.
- Simulação: `SEFAZ_HOMOLOGATION_SIMULATION_OK`, `networkCall=false`, `fiscalValue=false`.

## Empresa-piloto reservada para portão separado

- Identificação no Git: `pilot-maniademoda`.
- CNPJ mascarado: `09.***.***/****-10`.
- Subdomínio planejado: `maniademoda.connectioncyber.com.br`.
- Nenhuma credencial, certificado, CSC ou dado fiscal foi armazenado.

## Limites preservados

Nenhuma chamada à SEFAZ, transmissão de NF-e/NFC-e, instalação de certificado, alteração remota, criação de dados ou acesso à produção ocorreu. O uso da empresa-piloto depende de autorização específica e de um procedimento separado de custódia de credenciais.

