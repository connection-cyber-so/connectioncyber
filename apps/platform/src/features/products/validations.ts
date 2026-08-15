// Igual ao original (cc-commerce-studio/features/products/validations/product.schema.ts), menos brand_id.
import { z } from 'zod';

export const productSchema = z.object({
  name: z.string().trim().min(3, 'O nome deve possuir no mínimo 3 caracteres.').max(150, 'O nome deve possuir no máximo 150 caracteres.'),
  description: z.string().trim().max(500, 'A descrição deve possuir no máximo 500 caracteres.').optional(),
  status: z.enum(['draft', 'active', 'archived']).default('draft'),
});

export type ProductSchema = z.infer<typeof productSchema>;
