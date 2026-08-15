// Igual ao original (cc-commerce-studio/features/diagnostic-engine/validations/diagnostic.schema.ts) — nenhuma regra de negócio mudou, só o módulo que a hospeda.
import { z } from 'zod';

export const diagnosticSchema = z.object({
  title: z
    .string()
    .trim()
    .min(3, 'O título deve possuir no mínimo 3 caracteres.')
    .max(150, 'O título deve possuir no máximo 150 caracteres.'),

  canais_digitais: z
    .string()
    .trim()
    .min(3, 'Descreva os canais digitais atuais.')
    .max(500, 'Máximo de 500 caracteres.'),

  publico_alvo: z
    .string()
    .trim()
    .min(3, 'Descreva o público-alvo.')
    .max(500, 'Máximo de 500 caracteres.'),

  concorrentes: z.string().trim().max(500, 'Máximo de 500 caracteres.').optional(),

  objetivo_principal: z.enum(['aumentar_vendas', 'gerar_leads', 'construir_marca', 'outro']),

  maturidade_digital: z.enum(['iniciante', 'intermediario', 'avancado']),
});

export type DiagnosticSchema = z.infer<typeof diagnosticSchema>;
