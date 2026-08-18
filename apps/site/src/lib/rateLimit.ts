import { createHash } from 'node:crypto';
import type { NextApiRequest } from 'next';
import { env } from '@/config/env';
import { getSupabaseAdminClient } from '@/lib/supabaseClient';

function firstHeader(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function getClientIp(req: NextApiRequest): string {
  const forwarded = firstHeader(req.headers['x-forwarded-for']);
  return forwarded?.split(',')[0]?.trim() || req.socket.remoteAddress || 'unknown';
}

export async function consumeRateLimit(
  req: NextApiRequest,
  scope: string,
  limit: number,
  windowSeconds: number,
): Promise<boolean> {
  if (!env.security.rateLimitSalt) {
    throw new Error('RATE_LIMIT_SALT não configurado');
  }

  const key = createHash('sha256')
    .update(`${env.security.rateLimitSalt}:${scope}:${getClientIp(req)}`)
    .digest('hex');
  const admin = getSupabaseAdminClient();
  const { data, error } = await admin.rpc('consume_api_rate_limit', {
    p_key: key,
    p_limit: limit,
    p_window_seconds: windowSeconds,
  });
  if (error) throw error;
  return data === true;
}
