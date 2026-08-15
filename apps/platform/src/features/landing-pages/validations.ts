import { z } from 'zod';

export const landingPageSchema = z.object({
  title: z.string().trim().min(3, 'O título deve possuir no mínimo 3 caracteres.').max(150, 'O título deve possuir no máximo 150 caracteres.'),
  slug: z
    .string()
    .trim()
    .min(3, 'O slug deve possuir no mínimo 3 caracteres.')
    .max(100, 'O slug deve possuir no máximo 100 caracteres.')
    .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, 'O slug deve conter apenas letras minúsculas, números e hífens.'),
  content: z.string().trim().max(5000, 'O conteúdo deve possuir no máximo 5000 caracteres.').optional(),
  status: z.enum(['draft', 'published']).default('draft'),
  offer_id: z.string().uuid('Selecione uma oferta válida.'),
});

export type LandingPageSchema = z.infer<typeof landingPageSchema>;
