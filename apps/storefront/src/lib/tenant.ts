import { headers } from "next/headers";
import { TENANT_HEADER } from "@/lib/tenant-host";

/**
 * Tenant da requisição atual. Vem SEMPRE do middleware, que resolve o hostname
 * (src/middleware.ts + src/lib/tenant-host.ts) e grava o header abaixo.
 *
 * O middleware apaga qualquer x-cc-tenant-id enviado pelo cliente antes de gravar
 * o seu, então o valor nunca vem de query string, form field ou cabeçalho do cliente.
 *
 * Sem header = requisição não passou pelo middleware → erro, nunca um tenant padrão.
 */
export function getCurrentTenantId(): string {
  const tenantId = headers().get(TENANT_HEADER);
  if (!tenantId) {
    throw new Error("Tenant nao resolvido para esta requisicao.");
  }
  return tenantId;
}
