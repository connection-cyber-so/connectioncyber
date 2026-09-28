import { InvalidWebhookSignatureError, WebhookSignatureValidator } from 'mercadopago';

export interface WebhookSignatureInput {
  headers: Record<string, string | string[] | undefined>;
  dataId: string;
  secret: string;
  now?: () => number;
}

export function validateMercadoPagoWebhookSignature(input: WebhookSignatureInput): boolean {
  if (!input.secret) return false;

  try {
    const signature = Array.isArray(input.headers['x-signature'])
      ? input.headers['x-signature'][0]
      : input.headers['x-signature'];
    const timestamp = signature
      ?.split(',')
      .map((part) => part.trim())
      .find((part) => part.startsWith('ts='))
      ?.slice(3);
    if (!timestamp || !/^\d+$/.test(timestamp)) return false;

    const timestampNumber = Number(timestamp);
    const timestampMs = timestampNumber < 1_000_000_000_000 ? timestampNumber * 1_000 : timestampNumber;
    const nowMs = (input.now ?? Date.now)();
    if (Math.abs(nowMs - timestampMs) > 300_000) return false;

    WebhookSignatureValidator.validate({
      xSignature: input.headers['x-signature'],
      xRequestId: input.headers['x-request-id'],
      dataId: input.dataId,
      secret: input.secret,
    });
    return true;
  } catch (error) {
    if (error instanceof InvalidWebhookSignatureError) return false;
    throw error;
  }
}
