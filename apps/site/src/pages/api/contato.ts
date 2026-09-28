import type { NextApiRequest, NextApiResponse } from 'next';
import { env, isSupabaseConfigured } from '@/config/env';
import { consumeRateLimit } from '@/lib/rateLimit';
import { getSupabaseAdminClient } from '@/lib/supabaseClient';

interface ContactPayload {
  nome: string;
  email: string;
  telefone: string | null;
  empresa: string | null;
  mensagem: string;
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MAX_BODY_BYTES = 16_384;

function optionalText(value: unknown, maxLength: number): string | null | undefined {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string') return undefined;
  const normalized = value.trim();
  if (!normalized || normalized.length > maxLength) return undefined;
  return normalized;
}

function requiredText(value: unknown, minLength: number, maxLength: number): string | undefined {
  if (typeof value !== 'string') return undefined;
  const normalized = value.trim();
  if (normalized.length < minLength || normalized.length > maxLength) return undefined;
  return normalized;
}

function parseContactPayload(value: unknown): ContactPayload | null {
  if (!value || typeof value !== 'object') return null;
  const body = value as Record<string, unknown>;
  const nome = requiredText(body.nome, 2, 120);
  const email = requiredText(body.email, 5, 254)?.toLowerCase();
  const telefone = optionalText(body.telefone, 30);
  const empresa = optionalText(body.empresa, 160);
  const mensagem = requiredText(body.mensagem, 10, 4_000);

  if (!nome || !email || !EMAIL_PATTERN.test(email) || telefone === undefined || empresa === undefined || !mensagem) {
    return null;
  }
  return { nome, email, telefone, empresa, mensagem };
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Método não permitido' });
  }
  if (!req.headers['content-type']?.toLowerCase().startsWith('application/json')) {
    return res.status(415).json({ error: 'Formato não suportado' });
  }
  const contentLength = Number(req.headers['content-length'] ?? 0);
  if (Number.isFinite(contentLength) && contentLength > MAX_BODY_BYTES) {
    return res.status(413).json({ error: 'Mensagem muito grande' });
  }
  if (typeof req.body?.website === 'string' && req.body.website.trim()) {
    return res.status(200).json({ ok: true });
  }
  if (!isSupabaseConfigured) {
    return res.status(503).json({ error: 'Formulário temporariamente indisponível' });
  }

  const payload = parseContactPayload(req.body);
  if (!payload) return res.status(400).json({ error: 'Dados inválidos' });

  try {
    if (!(await consumeRateLimit(req, 'contact', 5, 60))) {
      res.setHeader('Retry-After', '60');
      return res.status(429).json({ error: 'Muitas mensagens. Aguarde e tente novamente.' });
    }

    const admin = getSupabaseAdminClient();
    const { data: message, error: insertError } = await admin
      .from('contact_messages')
      .insert(payload)
      .select('id')
      .single();
    if (insertError || !message) throw insertError ?? new Error('Mensagem não persistida');

    if (env.n8n.baseUrl) {
      const automationResponse = await fetch(`${env.n8n.baseUrl}/webhook/contato`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(env.n8n.webhookToken ? { Authorization: `Bearer ${env.n8n.webhookToken}` } : {}),
          'Idempotency-Key': `contact:${message.id}`,
        },
        body: JSON.stringify({ messageId: message.id, ...payload }),
        signal: AbortSignal.timeout(8_000),
      });
      if (!automationResponse.ok) {
        console.error('[api/contato] automação recusou mensagem', {
          messageId: message.id,
          status: automationResponse.status,
        });
      }
    }

    return res.status(200).json({ ok: true });
  } catch (error) {
    console.error('[api/contato] erro ao processar formulário', error);
    return res.status(500).json({ error: 'Erro ao processar formulário' });
  }
}
