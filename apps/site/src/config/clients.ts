/**
 * Carteira de clientes ConnectionCyber — Área de Clientes.
 *
 * ATENÇÃO (ação pendente para Joaquim): os itens abaixo são placeholders
 * estruturais para os 15 clientes com contrato ativo há mais de 10 anos
 * mencionados no briefing. Substitua "nome", "logoUrl", "segmento",
 * "servicos" e "anosParceria" pelos dados reais de cada cliente antes de
 * publicar em produção — nomes reais de empresas não foram fornecidos no
 * briefing, então não foram inventados aqui.
 */
export interface ClientEntry {
  id: string;
  nome: string;
  logoUrl?: string;
  segmento: string;
  servicos: string[];
  anosParceria: number;
  depoimento?: string;
}

export const clientPortfolio: ClientEntry[] = Array.from({ length: 15 }, (_, i) => ({
  id: `cliente-${i + 1}`,
  nome: `Cliente Corporativo ${i + 1}`,
  segmento: 'A definir',
  servicos: ['Assessoria Técnica', 'Suporte Global'],
  anosParceria: 10,
}));
