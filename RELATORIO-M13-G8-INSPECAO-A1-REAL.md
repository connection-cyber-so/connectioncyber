# M13-G8 — inspeção local do A1 real

Data: 28/08/2026

## Resultado

- A tentativa de leitura efêmera do arquivo PKCS#12 foi encerrada após rejeição da senha pelo provedor criptográfico.
- O certificado já instalado foi inspecionado no repositório pessoal do Windows, aberto somente para leitura.
- O primeiro certificado selecionado foi descartado por estar vencido e pertencer a outro contexto.
- O seletor foi corrigido para apresentar somente certificados com chave privada e validade atual.
- A seleção final retornou `chainValid=true` e `validNow=true`.
- 104/104 testes locais aprovados.

## Privacidade e segurança

O projeto registra somente os estados booleanos da validação. Titular, CNPJ, impressão digital, senha, caminho e conteúdo do certificado não foram gravados. A chave privada não foi exportada. Não houve assinatura, uso de CSC, transmissão, acesso à SEFAZ, alteração de Supabase ou acesso à produção.

## Próximo portão

M13-G9 — assinatura local controlada de XML sintético sem valor fiscal, usando o certificado instalado e validando a assinatura localmente. Esse portão exige autorização específica e continuará sem CSC, transmissão ou produção.

