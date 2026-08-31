export type DemoProduct={id:string;name:string;code:string;price:number;stock:number};
export type DemoCustomer={id:string;name:string;email:string;kind:'Pessoa'|'Empresa'};
export type DemoPayment='pix'|'dinheiro'|'cartao';
export type DemoCashMovement={id:string;kind:'Abertura'|'Venda'|'Entrada'|'Saída'|'Fechamento';amount:number;label:string;payment?:DemoPayment};
export type DemoFinancialTitle={id:string;kind:'Receber'|'Pagar';description:string;amount:number;due:string;status:'Aberto'|'Baixado'};

export const initialDemoProducts:DemoProduct[]=[
  {id:'synthetic-001',name:'Camiseta Essential',code:'SYN-001',price:59.9,stock:18},
  {id:'synthetic-002',name:'Calça Jeans Classic',code:'SYN-002',price:129.9,stock:9},
  {id:'synthetic-003',name:'Tênis Urban',code:'SYN-003',price:189.9,stock:6},
  {id:'synthetic-004',name:'Bolsa Compacta',code:'SYN-004',price:89.9,stock:12},
  {id:'synthetic-005',name:'Jaqueta Leve',code:'SYN-005',price:159.9,stock:4},
  {id:'synthetic-006',name:'Cinto Casual',code:'SYN-006',price:39.9,stock:21},
];

export const initialDemoCustomers:DemoCustomer[]=[
  {id:'synthetic-customer-001',name:'Consumidor final sintético',email:'consumidor@example.invalid',kind:'Pessoa'},
  {id:'synthetic-customer-002',name:'Cliente Preferencial Sintético',email:'preferencial@example.invalid',kind:'Pessoa'},
];
