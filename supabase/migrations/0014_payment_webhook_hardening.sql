-- ConnectionCyber — idempotência e rastreabilidade do webhook Mercado Pago.
-- Aplicação remota exige preflight para detectar transaction_id duplicado.

alter table public.payments
  add column if not exists automation_notified_at timestamptz;

create unique index if not exists payments_gateway_transaction_uidx
  on public.payments (gateway, transaction_id);

comment on column public.payments.automation_notified_at is
  'Instante em que a automação pós-pagamento confirmou o recebimento do evento.';
