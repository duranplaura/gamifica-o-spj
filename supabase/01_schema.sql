-- =====================================================================
-- Gamificação Saint Paul Jr · banco no Supabase
-- Rode este arquivo inteiro uma vez no SQL Editor do projeto.
-- =====================================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------- associados
create table if not exists public.associados (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  email       text not null unique check (email = lower(email)),
  area        text,                       -- Comercial, Marketing, Projetos, ADF...
  papel       text not null default 'associado'
              check (papel in ('associado', 'diretor', 'presidencia')),
  avaliado    boolean not null default true,   -- false: não entra no ranking
  foto        text,
  ativo       boolean not null default true,
  user_id     uuid unique references auth.users (id) on delete set null,
  criado_em   timestamptz not null default now()
);

-- -------------------------------------------------------------- critérios
create table if not exists public.criterios (
  id          serial primary key,
  nome        text not null unique,
  avalia      text,
  ordem       int not null default 0,
  escala_max  int not null default 4,      -- 4 na avaliação nova; 5 no legado
  ativo       boolean not null default true
);

create table if not exists public.rubrica (
  criterio_id int not null references public.criterios (id) on delete cascade,
  nota        int not null,
  nivel       text,
  descritor   text,
  primary key (criterio_id, nota)
);

-- ------------------------------------------------------------- avaliações
create table if not exists public.avaliacoes (
  id            bigserial primary key,
  associado_id  uuid not null references public.associados (id) on delete cascade,
  ano           int not null,
  mes           int not null check (mes between 1 and 12),
  criterio_id   int not null references public.criterios (id),
  nota          numeric(4,2) not null,
  avaliador_id  uuid references public.associados (id) on delete set null,
  atualizado_em timestamptz not null default now(),
  unique (associado_id, ano, mes, criterio_id)
);

-- médias da planilha antiga (escala 1 a 5), guardadas como estavam
create table if not exists public.medias_legado (
  associado_id  uuid not null references public.associados (id) on delete cascade,
  ano           int not null,
  mes           int not null check (mes between 1 and 12),
  media         numeric(4,2) not null,
  escala_max    int not null default 5,
  primary key (associado_id, ano, mes)
);

-- --------------------------------------------------------- ranking/faixas
create table if not exists public.faixas_ranking (
  id         text primary key,
  nome       text not null,
  minimo     numeric(4,2) not null,       -- na escala 1 a 4
  descricao  text
);

-- ------------------------------------------------------------ penalidades
create table if not exists public.penalidades (
  associado_id  uuid not null references public.associados (id) on delete cascade,
  ano           int not null,
  mes           int not null check (mes between 1 and 12),
  tipo          text not null check (tipo in ('faltas', 'atrasos_reuniao', 'atrasos_entrega')),
  quantidade    int not null default 0 check (quantidade >= 0),
  lancado_por   uuid references public.associados (id) on delete set null,
  atualizado_em timestamptz not null default now(),
  primary key (associado_id, ano, mes, tipo)
);

create table if not exists public.regras_penalidade (
  chave        text primary key,           -- faltas, atrasos_reuniao, atrasos_entrega, media_entregas, advertencias
  janela       text check (janela in ('trimestre', '3meses', 'bimestre')),
  limite       int,
  minimo       numeric(4,2),
  advertencia  boolean not null default false
);

create table if not exists public.ocorrencias (
  id            bigserial primary key,
  associado_id  uuid not null references public.associados (id) on delete cascade,
  data          date not null default current_date,
  tipo          text,
  justificativa text,
  lancado_por   uuid references public.associados (id) on delete set null,
  criado_em     timestamptz not null default now()
);

-- --------------------------------------------------------------------- XP
create table if not exists public.xp_objetivos (
  id             serial primary key,
  nome           text not null unique,
  multiplicador  int not null default 1,
  ordem          int not null default 0,
  ativo          boolean not null default true
);

create table if not exists public.xp_lancamentos (
  id            bigserial primary key,
  associado_id  uuid not null references public.associados (id) on delete cascade,
  objetivo_id   int not null references public.xp_objetivos (id),
  ocorrencias   int,                         -- vazio no legado
  xp            int not null,                -- já multiplicado
  data          date not null default current_date,
  observacao    text,
  lancado_por   uuid references public.associados (id) on delete set null,
  criado_em     timestamptz not null default now()
);

-- ------------------------------------------------------------------- loja
create table if not exists public.loja_produtos (
  id              text primary key,
  nome            text not null unique,      -- nome usado nas compras
  titulo          text,
  descricao       text,
  requer_ranking  text,                      -- id da faixa
  preco           int not null default 0,
  estoque         int,                       -- vazio = sem controle
  por_pessoa      int,                       -- vazio = sem limite
  status          text not null default 'disponivel' check (status in ('disponivel', 'em_breve')),
  ordem           int not null default 0
);

create table if not exists public.loja_compras (
  id            uuid primary key default gen_random_uuid(),
  associado_id  uuid not null references public.associados (id) on delete cascade,
  produto_id    text not null references public.loja_produtos (id),
  xp            int not null default 0,
  data          date not null default current_date,
  entregue      boolean not null default false,
  criado_em     timestamptz not null default now()
);

-- ============================================================== permissões

-- quem está logado
create or replace function public.eu() returns public.associados
language sql stable security definer set search_path = public as $$
  select * from public.associados where user_id = auth.uid() and ativo limit 1
$$;

create or replace function public.eh_presidencia() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select papel = 'presidencia' from public.eu()), false)
$$;

-- presidência gere todos; diretor gere a própria área
create or replace function public.pode_gerir(alvo uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select e.papel = 'presidencia'
        or (e.papel = 'diretor' and e.area is not null and e.area = a.area and a.id <> e.id)
    from public.eu() e, public.associados a
    where a.id = alvo
  ), false)
$$;

create or replace function public.eh_gestor() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select papel in ('diretor', 'presidencia') from public.eu()), false)
$$;

-- só e-mail cadastrado em associados consegue criar senha
create or replace function public.checar_cadastro() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.associados
                 where email = lower(new.email) and ativo and user_id is null) then
    raise exception 'Este e-mail não está na lista de associados ou já tem senha criada. Procure a diretoria.';
  end if;
  return new;
end $$;

create or replace function public.ligar_cadastro() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.associados set user_id = new.id
   where email = lower(new.email) and user_id is null;
  return new;
end $$;

drop trigger if exists antes_de_criar_usuario on auth.users;
create trigger antes_de_criar_usuario before insert on auth.users
  for each row execute function public.checar_cadastro();

drop trigger if exists depois_de_criar_usuario on auth.users;
create trigger depois_de_criar_usuario after insert on auth.users
  for each row execute function public.ligar_cadastro();

-- ------------------------------------------------------------------- RLS
alter table public.associados        enable row level security;
alter table public.criterios         enable row level security;
alter table public.rubrica           enable row level security;
alter table public.avaliacoes        enable row level security;
alter table public.medias_legado     enable row level security;
alter table public.faixas_ranking    enable row level security;
alter table public.penalidades       enable row level security;
alter table public.regras_penalidade enable row level security;
alter table public.ocorrencias       enable row level security;
alter table public.xp_objetivos      enable row level security;
alter table public.xp_lancamentos    enable row level security;
alter table public.loja_produtos     enable row level security;
alter table public.loja_compras      enable row level security;

-- leitura: qualquer associado logado vê o catálogo e as regras
do $$
declare t text;
begin
  foreach t in array array['criterios','rubrica','faixas_ranking','regras_penalidade','xp_objetivos','loja_produtos'] loop
    execute format('drop policy if exists ler on public.%I', t);
    execute format('create policy ler on public.%I for select to authenticated using (true)', t);
    execute format('drop policy if exists gerir on public.%I', t);
    execute format('create policy gerir on public.%I for all to authenticated using (public.eh_presidencia()) with check (public.eh_presidencia())', t);
  end loop;
end $$;

-- associados: todo mundo logado vê a lista (nome, área, foto); só a presidência edita
drop policy if exists ler on public.associados;
create policy ler on public.associados for select to authenticated using (true);
drop policy if exists gerir on public.associados;
create policy gerir on public.associados for all to authenticated
  using (public.eh_presidencia()) with check (public.eh_presidencia());

-- dados de cada associado: ele mesmo vê os seus; gestores veem os de quem gerem
do $$
declare t text;
begin
  foreach t in array array['avaliacoes','medias_legado','penalidades','ocorrencias','xp_lancamentos'] loop
    execute format('drop policy if exists ler on public.%I', t);
    execute format('create policy ler on public.%I for select to authenticated using (associado_id = (public.eu()).id or public.pode_gerir(associado_id))', t);
    execute format('drop policy if exists gerir on public.%I', t);
    execute format('create policy gerir on public.%I for all to authenticated using (public.pode_gerir(associado_id)) with check (public.pode_gerir(associado_id))', t);
  end loop;
end $$;

drop policy if exists ler on public.loja_compras;
create policy ler on public.loja_compras for select to authenticated
  using (associado_id = (public.eu()).id or public.pode_gerir(associado_id));
drop policy if exists gerir on public.loja_compras;
create policy gerir on public.loja_compras for all to authenticated
  using (public.eh_presidencia()) with check (public.eh_presidencia());

-- ================================================================ cálculos

-- (view de conferência) média do mês na escala 1 a 4
create or replace view public.medias_mensais with (security_invoker = true) as
with nova as (
  select v.associado_id, v.ano, v.mes,
         avg(1 + (v.nota - 1) * 3.0 / (c.escala_max - 1)) as media
  from public.avaliacoes v join public.criterios c on c.id = v.criterio_id
  group by 1, 2, 3
),
legado as (
  select associado_id, ano, mes, 1 + (media - 1) * 3.0 / (escala_max - 1) as media
  from public.medias_legado
)
select coalesce(n.associado_id, l.associado_id) as associado_id,
       coalesce(n.ano, l.ano) as ano,
       coalesce(n.mes, l.mes) as mes,
       round(coalesce(n.media, l.media), 2) as media
from nova n full join legado l
  on l.associado_id = n.associado_id and l.ano = n.ano and l.mes = n.mes;

-- ranking da equipe: médias de todos, sem expor as notas por critério
create or replace function public.ranking_do_ano(p_ano int)
returns table (associado_id uuid, nome text, foto text, mes int, media numeric)
language sql stable security definer set search_path = public as $$
  with base as (
    select v.associado_id, v.ano, v.mes,
           avg(1 + (v.nota - 1) * 3.0 / (c.escala_max - 1)) as media
    from avaliacoes v join criterios c on c.id = v.criterio_id
    where v.ano = p_ano group by 1, 2, 3
  ), leg as (
    select associado_id, ano, mes, 1 + (media - 1) * 3.0 / (escala_max - 1) as media
    from medias_legado where ano = p_ano
  ), junto as (
    select coalesce(b.associado_id, l.associado_id) as associado_id,
           coalesce(b.mes, l.mes) as mes,
           round(coalesce(b.media, l.media), 2) as media
    from base b full join leg l
      on l.associado_id = b.associado_id and l.mes = b.mes
  )
  select a.id, a.nome, a.foto, j.mes, j.media
  from junto j join associados a on a.id = j.associado_id
  where auth.uid() is not null and a.ativo and a.avaliado
$$;

-- XP ganho por todos, para o pódio de XP (só totais)
create or replace function public.saldo_xp(p_associado uuid)
returns int language sql stable security definer set search_path = public as $$
  select case when p_associado = (select id from eu()) or pode_gerir(p_associado) then
       coalesce((select sum(xp) from xp_lancamentos where associado_id = p_associado), 0)
     - coalesce((select sum(xp) from loja_compras where associado_id = p_associado), 0)
  end
$$;

-- resgate na loja: confere tudo no servidor e grava numa transação só
create or replace function public.resgatar(p_produto text, p_compra uuid)
returns json language plpgsql security definer set search_path = public as $$
declare
  me      associados;
  prod    loja_produtos;
  ja      int;
  saldo   int;
  minimo  numeric;
  media   numeric;
begin
  select * into me from eu();
  if me.id is null then raise exception 'Faça login de novo.'; end if;

  if exists (select 1 from loja_compras where id = p_compra) then
    return json_build_object('ok', true, 'repetida', true);
  end if;

  select * into prod from loja_produtos where id = p_produto for update;
  if prod.id is null then raise exception 'Produto não encontrado.'; end if;
  if prod.status <> 'disponivel' then raise exception 'Este item ainda não está disponível.'; end if;
  if prod.estoque is not null and prod.estoque <= 0 then raise exception 'Esgotado.'; end if;

  select count(*) into ja from loja_compras where associado_id = me.id and produto_id = prod.id;
  if prod.por_pessoa is not null and ja >= prod.por_pessoa then
    raise exception 'Você já resgatou este item o máximo de vezes.';
  end if;

  if prod.requer_ranking is not null and prod.requer_ranking <> '' then
    select f.minimo into minimo from faixas_ranking f where f.id = prod.requer_ranking;
    select r.media into media from ranking_do_ano(extract(year from now())::int) r
      where r.associado_id = me.id order by r.mes desc limit 1;
    if minimo is not null and coalesce(media, 0) < minimo then
      raise exception 'Seu ranking atual não libera este item.';
    end if;
  end if;

  saldo := saldo_xp(me.id);
  if prod.preco > saldo then raise exception 'XP insuficiente.'; end if;

  insert into loja_compras (id, associado_id, produto_id, xp)
  values (p_compra, me.id, prod.id, prod.preco);
  if prod.estoque is not null then
    update loja_produtos set estoque = estoque - 1 where id = prod.id;
  end if;
  return json_build_object('ok', true);
end $$;

grant execute on function public.ranking_do_ano(int) to authenticated;
grant execute on function public.resgatar(text, uuid) to authenticated;
grant execute on function public.saldo_xp(uuid) to authenticated;
grant execute on function public.eu() to authenticated;
grant execute on function public.eh_presidencia() to authenticated;
grant execute on function public.pode_gerir(uuid) to authenticated;
grant execute on function public.eh_gestor() to authenticated;
grant select on public.medias_mensais to authenticated;

-- e-mail cadastrado? (para a tela de primeiro acesso dar um recado claro)
create or replace function public.email_cadastrado(p_email text)
returns text language sql stable security definer set search_path = public as $$
  select case
    when not exists (select 1 from associados where email = lower(trim(p_email)) and ativo) then 'nao'
    when exists (select 1 from associados where email = lower(trim(p_email)) and user_id is not null) then 'ja_tem_senha'
    else 'ok' end
$$;
grant execute on function public.email_cadastrado(text) to anon, authenticated;
