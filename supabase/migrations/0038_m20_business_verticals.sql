-- ConnectionCyber — M20-G2: verticais de segmento + atributos exigidos por item.
--
-- Ver PARECER-TECNICO-M20-G0-CADASTROS-ESTRUTURAIS-SEGMENTOS.md, seção 6, decisão 3
-- (14 verticais confirmadas) e a correção de auditoria registrada no RELATORIO-M20-G2:
-- `public.erp_segment_profiles` (migration 0016, M16) JÁ resolve "quais MÓDULOS/
-- capacidades" um segmento típico usa (5 perfis largos: retail_general,
-- apparel_stationery, workshop, food_service, professional_services) — não é
-- redundante recriar isso aqui. O que faltava, e esta migration resolve, é uma camada
-- mais fina: "quais CAMPOS extras um item deste ramo de negócio precisa" (ex.: validade
-- pra casa de bolos, teor alcoólico pra adega) — apoiada no EAV genérico já existente
-- (`erp_attributes`/`erp_item_attribute_values`, migration 0021), que é por-tenant.
--
-- Como erp_attributes é por-tenant (cada tenant cria suas próprias linhas de atributo)
-- e uma vertical é um conceito global (ConnectionCyber, não um cliente específico), o
-- vínculo aqui é um TEMPLATE (attribute_code/name/data_type), não uma FK direta para
-- erp_attributes — materializar essas linhas de fato no erp_attributes de um tenant
-- quando ele adota uma vertical é trabalho de um portão futuro (provisionamento), não
-- desta migration.
begin;

create table public.erp_business_verticals (
  code text primary key check (code ~ '^[a-z][a-z0-9_]{1,63}$'),
  name text not null,
  description text,
  segment_profile_key text references public.erp_segment_profiles(key) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.erp_business_verticals is
  'Catálogo global de ramos de negócio (moda, oficina, restaurante, ...), mais fino que erp_segment_profiles — ver M20-G2.';

create table public.erp_vertical_attribute_requirements (
  id uuid primary key default gen_random_uuid(),
  vertical_code text not null references public.erp_business_verticals(code) on delete cascade,
  attribute_code text not null check (attribute_code ~ '^[a-z][a-z0-9_]{1,63}$'),
  attribute_name text not null,
  data_type text not null default 'text' check (data_type in ('option','text','number','boolean')),
  required boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (vertical_code,attribute_code)
);
comment on table public.erp_vertical_attribute_requirements is
  'Template de atributo extra que um item deveria ter por vertical — materialização em erp_attributes por-tenant fica para um portão futuro de provisionamento.';

alter table public.erp_establishments
  add column vertical_code text references public.erp_business_verticals(code) on delete set null;

create trigger trg_erp_business_verticals_updated_at before update on public.erp_business_verticals for each row execute function public.set_updated_at();

insert into public.erp_business_verticals(code,name,description,segment_profile_key) values
('moda','Moda/vestuário','Roupas, acessórios e calçados em geral.','apparel_stationery'),
('oficina','Oficina (mecânica/CFTV/elétrica/solar)','Manutenção, instalação e reparo com peças e mão de obra.','workshop'),
('restaurante','Restaurante/alimentação','Preparo e venda de refeições, comandas e produção de cozinha.','food_service'),
('papelaria','Papelaria','Material de escritório, escolar e afins.','apparel_stationery'),
('material_construcao','Material de construção','Insumos e materiais para obra e reforma.','retail_general'),
('celular_multi_cnpj','Celular (venda e reparo, multi-CNPJ)','Venda de aparelhos/acessórios e reparo técnico, tipicamente em mais de um estabelecimento.','workshop'),
('adega','Adega','Bebidas alcoólicas para revenda.','retail_general'),
('casa_de_bolos','Casa de bolos (fabricação e venda)','Fabrica e vende — ficha técnica/receita e validade por lote.','food_service'),
('loja_variedades','Loja de variedades','Bazar e utilidades diversas.','apparel_stationery'),
('cabeleireiro_barbeiro','Cabeleireiro e barbeiro','Serviços agendados de estética capilar.','professional_services'),
('perfumaria_cosmetico','Perfumaria e cosmético','Fragrâncias e cosméticos para revenda.','retail_general'),
('loja_calcados','Loja de calçados','Calçados em geral, com numeração.','apparel_stationery'),
('servicos_mei_pf','Serviços ME/PF','Prestação de serviço genérica, sem estoque físico obrigatório.','professional_services'),
('servicos_informatica','Serviços de informática','Suporte técnico, manutenção e venda de periféricos.','professional_services')
on conflict (code) do update set name=excluded.name,description=excluded.description,segment_profile_key=excluded.segment_profile_key,active=true;

insert into public.erp_vertical_attribute_requirements(vertical_code,attribute_code,attribute_name,data_type,required,sort_order) values
('moda','tamanho','Tamanho','option',true,1),
('moda','cor','Cor','option',true,2),
('oficina','garantia_dias','Garantia (dias)','number',false,1),
('restaurante','tempo_preparo_min','Tempo de preparo (min)','number',false,1),
('material_construcao','medida_padrao','Medida padrão de venda','text',false,1),
('celular_multi_cnpj','imei_obrigatorio','Exige IMEI','boolean',true,1),
('adega','teor_alcoolico','Teor alcoólico (%)','number',true,1),
('adega','volume_ml','Volume (ml)','number',false,2),
('casa_de_bolos','validade_dias','Validade padrão (dias após fabricação)','number',true,1),
('cabeleireiro_barbeiro','duracao_min','Duração do serviço (min)','number',true,1),
('perfumaria_cosmetico','registro_anvisa','Registro ANVISA','text',false,1),
('loja_calcados','numeracao','Numeração','option',true,1),
('servicos_informatica','garantia_dias','Garantia (dias)','number',false,1)
on conflict (vertical_code,attribute_code) do update set attribute_name=excluded.attribute_name,data_type=excluded.data_type,required=excluded.required,sort_order=excluded.sort_order;

-- RLS: catálogo global (igual erp_segment_profiles/erp_permissions) — leitura livre pra
-- qualquer autenticado, escrita só por migration/service_role (nenhuma policy de
-- insert/update pra authenticated, de propósito).
alter table public.erp_business_verticals enable row level security;
create policy erp_business_verticals_select_authenticated on public.erp_business_verticals for select to authenticated using (true);

alter table public.erp_vertical_attribute_requirements enable row level security;
create policy erp_vertical_attribute_requirements_select_authenticated on public.erp_vertical_attribute_requirements for select to authenticated using (true);

revoke all on table public.erp_business_verticals, public.erp_vertical_attribute_requirements from anon,authenticated;
grant select on table public.erp_business_verticals, public.erp_vertical_attribute_requirements to authenticated;
grant all on table public.erp_business_verticals, public.erp_vertical_attribute_requirements to service_role;

commit;
