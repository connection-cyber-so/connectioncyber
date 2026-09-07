'use server';
import { revalidatePath } from 'next/cache';
import { visualPersistenceClient } from '@/features/persistence/selected';
import { setSelectedEstablishmentId } from '@/lib/establishment-scope';

// M20-G4 — formulário 100% servidor (mesmo padrão do M19-G4), sem JS de cliente.
export async function setEstablishmentScopeAction(formData: FormData): Promise<void> {
  const raw = formData.get('establishment_id');
  const value = typeof raw === 'string' && raw !== 'all' ? raw : null;
  await setSelectedEstablishmentId(value);
  revalidatePath('/operacoes');
  revalidatePath('/vendas');
  revalidatePath('/servicos');
  revalidatePath('/catalogo');
}

export type EstablishmentActionState = { error: string | null; success: boolean };

// M20-G2/G4 — atribui uma vertical (M20-G2) a um estabelecimento específico.
export async function setEstablishmentVerticalAction(_: EstablishmentActionState, formData: FormData): Promise<EstablishmentActionState> {
  const establishmentId = String(formData.get('establishment_id') ?? '');
  const verticalCode = String(formData.get('vertical_code') ?? '');
  if (!establishmentId || !verticalCode) return { error: 'Selecione o estabelecimento e a vertical.', success: false };
  try {
    const result = await visualPersistenceClient.execute('establishment.vertical.set', { establishmentId, verticalCode });
    if (!result.ok) return { error: result.error.message, success: false };
    revalidatePath('/operacoes');
    revalidatePath('/catalogo');
    return { error: null, success: true };
  } catch {
    return { error: 'Não foi possível salvar a vertical nesta sessão.', success: false };
  }
}
