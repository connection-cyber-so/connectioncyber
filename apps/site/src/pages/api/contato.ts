import type { NextApiRequest, NextApiResponse } from 'next';
import { isSupabaseConfigured } from '@/config/env';
import { getSupabaseAdminClient } from '@/lib/supabaseClient';
import { env } from '@/config/env';

interface ContactPayload {
  nome: string;
  email: string;
  telefone?: string;
  empresa?: string;
  mensagem: string;
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Método não permitido' });
  }

  const payload = req.body as ContactPayload;
  if (!payload?.nome || !payload?.email || !payload?.mensagem) {
    return res.status(400).json({ error: 'Campos obrigatórios ausentes' });
  }

  try {
    // Persiste no Supabase quando configurado (tabela contact_messages).
    if (isSupabaseConfigured) {
      const admin = getSupabaseAdminClient();
      await admin.from('contact_messages').insert({
        nome: payload.nome,
        email: payload.email,
        telefone: payload.telefone ?? null,
        empresa: payload.empresa ?? null,
        mensagem: payload.mensagem,
      });
    }

    // Dispara automação n8n (notificação interna, CRM, e-mail) quando configurado.
    if (env.n8n.baseUrl) {
      fetch(`${env.n8n.baseUrl}/webhook/contato`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      }).catch(() => undefined);
    }

    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('[api/contato] erro ao processar formulário', err);
    return res.status(500).json({ error: 'Erro ao processar formulário' });
  }
}
