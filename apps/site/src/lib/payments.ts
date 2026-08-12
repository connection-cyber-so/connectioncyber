import { MercadoPagoConfig, Preference, Payment } from 'mercadopago';
import { env, isMercadoPagoConfigured } from '@/config/env';

/**
 * Módulo de pagamentos — Mercado Pago.
 * Usar SOMENTE em código server-side (API routes). O access token
 * é uma credencial privada e nunca deve chegar ao browser.
 */

function getClient(): MercadoPagoConfig {
  if (!isMercadoPagoConfigured) {
    throw new Error(
      'Mercado Pago não configurado. Preencha MERCADOPAGO_ACCESS_TOKEN no .env.local'
    );
  }
  return new MercadoPagoConfig({ accessToken: env.mercadoPago.accessToken });
}

export interface PreferenceItemInput {
  id: string;
  title: string;
  quantity: number;
  unitPrice: number;
  currencyId?: string;
}

export interface CreatePreferenceParams {
  orderId: string;
  items: PreferenceItemInput[];
  payerEmail?: string;
}

/**
 * Cria uma preferência de pagamento (curso, produto físico ou digital)
 * e retorna a URL de checkout (init_point) para redirecionar o usuário.
 */
export async function createPaymentPreference(params: CreatePreferenceParams) {
  const client = getClient();
  const preference = new Preference(client);

  const response = await preference.create({
    body: {
      items: params.items.map((item) => ({
        id: item.id,
        title: item.title,
        quantity: item.quantity,
        unit_price: item.unitPrice,
        currency_id: item.currencyId ?? 'BRL',
      })),
      payer: params.payerEmail ? { email: params.payerEmail } : undefined,
      external_reference: params.orderId,
      back_urls: {
        success: `${env.site.url}/pagamento/sucesso`,
        failure: `${env.site.url}/pagamento/erro`,
        pending: `${env.site.url}/pagamento/sucesso`,
      },
      auto_return: 'approved',
      notification_url: `${env.site.url}/api/payments/webhook`,
    },
  });

  return {
    preferenceId: response.id,
    checkoutUrl: response.init_point,
    sandboxCheckoutUrl: response.sandbox_init_point,
  };
}

/** Consulta o status de um pagamento a partir do ID enviado no webhook. */
export async function getPaymentStatus(paymentId: string) {
  const client = getClient();
  const payment = new Payment(client);
  const result = await payment.get({ id: paymentId });
  return {
    id: result.id,
    status: result.status,
    externalReference: result.external_reference,
    transactionAmount: result.transaction_amount,
  };
}

/**
 * Valida a assinatura do webhook do Mercado Pago (x-signature).
 * Implementação de referência — ajustar conforme documentação oficial
 * ao ativar credenciais reais de produção.
 * https://www.mercadopago.com.br/developers/pt/docs/your-integrations/notifications/webhooks
 */
export function isValidWebhookSignature(_headers: Record<string, string | string[] | undefined>): boolean {
  if (!env.mercadoPago.webhookSecret) {
    // Sem segredo configurado ainda: aceitar em desenvolvimento, mas alertar.
    console.warn('[payments] MERCADOPAGO_WEBHOOK_SECRET não configurado — validação de assinatura desativada.');
    return true;
  }
  // TODO: implementar validação HMAC real com o segredo quando disponível.
  return true;
}
