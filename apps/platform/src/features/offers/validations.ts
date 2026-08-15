import { z } from 'zod';

export const offerSchema = z.object({
  title: z.string().trim().min(3, 'O título deve possuir no mínimo 3 caracteres.').max(150, 'O título deve possuir no máximo 150 caracteres.'),
  copy: z.string().trim().max(2000, 'A copy deve possuir no máximo 2000 caracteres.').optional(),
  status: z.enum(['draft', 'generated', 'published']).default('draft'),
  product_id: z.string().uuid('Selecione um produto válido.'),
});

export type OfferSchema = z.infer<typeof offerSchema>;
