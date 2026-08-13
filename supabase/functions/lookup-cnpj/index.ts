// ============================================================================
// PROJETO: connectioncyber (ConnectionCyberSO)
// FUNÇÃO: lookup-cnpj
// ORIGEM: padrão trazido da auditoria multi-projeto — reaproveitado de
//         bpo-system-web-os/supabase/functions/lookup-cnpj (mesma lógica,
//         mesma fonte de dados). Ver docs/auditoria-ecossistema-connectioncyberos.md.
// DESCRIÇÃO: Consulta a BrasilAPI (dados públicos da Receita Federal) por
//            CNPJ e devolve os campos já mapeados para as colunas de
//            enriquecimento cadastral que um tenant/cliente pode ter.
//            Não grava nada no banco — quem chama decide o que fazer com
//            o resultado (ex: pré-preencher um formulário de onboarding).
// ============================================================================

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { cnpj } = await req.json();

    if (!cnpj) {
      return new Response(
        JSON.stringify({ error: "Campo cnpj obrigatorio." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const cnpjLimpo = String(cnpj).replace(/\D/g, "");

    if (cnpjLimpo.length !== 14) {
      return new Response(
        JSON.stringify({ error: "CNPJ invalido: precisa ter 14 digitos." }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const resposta = await fetch(`https://brasilapi.com.br/api/cnpj/v1/${cnpjLimpo}`);

    if (!resposta.ok) {
      const detalhe = await resposta.text();
      return new Response(
        JSON.stringify({ error: `Consulta a Receita Federal falhou (status ${resposta.status}).`, detalhe }),
        { status: 502, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const dados = await resposta.json();

    const resultado = {
      cnpj: cnpjLimpo,
      razao_social: dados.razao_social ?? null,
      nome_fantasia: dados.nome_fantasia ?? null,
      cnae_principal: dados.cnae_fiscal ? String(dados.cnae_fiscal) : null,
      cnae_descricao: dados.cnae_fiscal_descricao ?? null,
      porte: dados.porte ?? null,
      situacao_cadastral: dados.descricao_situacao_cadastral ?? null,
      municipio: dados.municipio ?? null,
      uf: dados.uf ?? null,
      data_abertura: dados.data_inicio_atividade ?? null,
      natureza_juridica: dados.natureza_juridica ?? null,
      dados_receita_raw: dados,
    };

    return new Response(
      JSON.stringify({ success: true, data: resultado }),
      { headers: { "Content-Type": "application/json", ...corsHeaders }, status: 200 }
    );
  } catch (error) {
    console.error("Erro no lookup-cnpj:", error);
    const message =
      error && typeof error === "object" && "message" in error
        ? String((error as { message: unknown }).message)
        : String(error);
    return new Response(
      JSON.stringify({ error: message }),
      { headers: { "Content-Type": "application/json", ...corsHeaders }, status: 400 }
    );
  }
});
