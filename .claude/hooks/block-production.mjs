#!/usr/bin/env node
// .claude/hooks/block-production.mjs
//
// PreToolUse hook: bloqueia comandos que toquem o Supabase de PRODUÇÃO
// (project id qfggetvashdxyuvlhihq) ou que façam push/merge na branch `main`,
// sem autorização explícita separada.
//
// Regra de origem: GOVERNANCA-EXECUCAO-AUTOMATICA.md + STATUS-MESTRE-DESENVOLVIMENTO.md
// — "produção exige autorização e checklist próprios"; "Nenhum erro será contornado
// com... alteração silenciosa de produção".

let raw = "";
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.exit(0); // não conseguiu ler o payload, não bloqueia
  }

  const toolName = input.tool_name || "";
  const toolInput = input.tool_input || {};

  const PROD_PROJECT_ID = "qfggetvashdxyuvlhihq";

  const haystackParts = [];

  if (toolName === "Bash" || toolName === "PowerShell") {
    haystackParts.push(String(toolInput.command || ""));
  }

  if (toolName.startsWith("mcp__claude_ai_Supabase__")) {
    haystackParts.push(JSON.stringify(toolInput));
  }

  const haystack = haystackParts.join("\n");

  if (!haystack) process.exit(0);

  const reasons = [];

  if (haystack.includes(PROD_PROJECT_ID)) {
    reasons.push(`referencia o projeto Supabase de PRODUÇÃO (${PROD_PROJECT_ID})`);
  }

  // git push para main/origin main, ou merge de PR (que via de regra vai para main)
  const pushMainPattern =
    /git\s+push[^\n]*\b(origin\s+)?main\b|git\s+push[^\n]*refs\/heads\/main|gh\s+pr\s+merge/i;
  if (pushMainPattern.test(haystack)) {
    reasons.push("faz push/merge na branch main (produção)");
  }

  if (reasons.length === 0) process.exit(0);

  const msg = [
    "BLOQUEADO pela governança do projeto (connectioncyber-staging).",
    "",
    `Este comando ${reasons.join(" e ")}.`,
    "",
    "GOVERNANCA-EXECUCAO-AUTOMATICA.md / STATUS-MESTRE-DESENVOLVIMENTO.md exigem que",
    "mudanças em produção sempre passem por autorização explícita separada e checklist",
    "próprio (Commit → Push → PR → Revisão → Merge → Backup de produção → Deploy),",
    "nunca de forma silenciosa ou automática.",
    "",
    "Se isso é intencional e já autorizado pelo responsável: peça para o usuário",
    "confirmar explicitamente e executar o comando ele mesmo, ou adicionar uma",
    "exceção específica em .claude/settings.json.",
  ].join("\n");

  process.stderr.write(msg + "\n");
  process.exit(2); // exit 2 = bloqueia a chamada da ferramenta
});
