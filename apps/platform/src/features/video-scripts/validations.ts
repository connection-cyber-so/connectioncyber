import { z } from 'zod';

export const videoScriptSchema = z.object({
  title: z.string().trim().min(3, 'O título deve possuir no mínimo 3 caracteres.').max(150, 'O título deve possuir no máximo 150 caracteres.'),
  script: z.string().trim().max(4000, 'O roteiro deve possuir no máximo 4000 caracteres.').optional(),
  status: z.enum(['draft', 'generated']).default('draft'),
  offer_id: z.string().uuid('Selecione uma oferta válida.'),
});

export type VideoScriptSchema = z.infer<typeof videoScriptSchema>;
