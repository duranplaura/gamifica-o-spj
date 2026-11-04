-- =====================================================================
-- Formulário oficial: descrições das competências, conceitos de 1 a 4,
-- textos da avaliação (Parte 2) e autoavaliação do associado (Parte 1).
-- =====================================================================

update public.criterios c set avalia = v.d from (values
  ('Entregas', 'Cumpre o que foi combinado dentro do prazo e com qualidade, sem retrabalho.'),
  ('Criatividade', 'Identifica, sugere e implementa novas ideias para solução de problemas e consegue executar modificações ou inovações que beneficiam tanto o seu aprendizado quanto a empresa.'),
  ('Curiosidade', 'Pergunta "por quê" antes de aceitar o "como", vai ver a operação com os próprios olhos e desconfia do "sempre foi assim".'),
  ('Iniciativa', 'Procura atividades para desenvolver, traz ideias próprias, propõe melhorias e vai além do que foi solicitado.'),
  ('Planejamento/Organização', 'Mostra a capacidade de planejar e distribuir o tempo das tarefas e dos recursos relacionados às responsabilidades assumidas e mantém em ordem a sua mesa e material de trabalho.'),
  ('Cooperação e Trabalho em Grupo', 'Revela ter facilidade de integração e relacionamento com os colegas no ambiente de trabalho, independente do nível hierárquico. Interage com outras pessoas, dentro de uma atuação cooperativa, onde seja estabelecida a empatia, o respeito e a colaboração, garantindo a eficiência do trabalho em conjunto.'),
  ('Maturidade/Postura', 'Apresenta conduta adequada, na forma de agir, comunicar, de se portar e de se expressar, sabendo se posicionar em diferentes situações.'),
  ('Comunicação', 'Organiza e apresenta ideias de modo claro e eficaz, tanto verbalmente como por escrito, apresentando habilidade de saber ouvir e fazer-se entender.'),
  ('Assiduidade', 'Cumpre adequadamente a sua carga horária de estágio de acordo com o especificado em seu contrato.'),
  ('Eficiência/Qualidade no Trabalho', 'Realiza as atividades dentro de um planejamento, com os recursos disponíveis, cumprindo os prazos previstos e contribuindo para os resultados da empresa. Há qualidade na apresentação, execução e precisão no desempenho seu trabalho, levando em consideração o resultado final.'),
  ('Conhecimento Teórico', 'Possui conhecimentos teóricos da sua área acadêmica, demonstrado na execução das atividades.'),
  ('Resistência à Pressão', 'Revela autocontrole para trabalhos sob pressão, atitudes positivas diante de conflitos, tato no relacionamento, controle de emoções, adaptabilidade a novas e diferentes situações.')
) as v(n, d) where c.nome = v.n;

-- os quatro conceitos do formulário valem para todas as competências
update public.rubrica r set nivel = v.nivel, descritor = v.descr
from (values
  (1, 'Abaixo do exigido', 'Abaixo do exigido, atuação comprometeu o alcance dos resultados.'),
  (2, 'Precisa desenvolver', 'Corresponde razoavelmente ao exigido, mas necessita desenvolver-se.'),
  (3, 'Adequado', 'Nível adequado, contribui de acordo com as expectativas.'),
  (4, 'Acima, supera', 'Acima do nível de exigência, superando os objetivos e expectativas.')
) as v(nota, nivel, descr)
where r.nota = v.nota and r.criterio_id in (select id from public.criterios where escala_max = 4);

-- Parte 2: o que o avaliador escreve
create table if not exists public.avaliacoes_textos (
  associado_id    uuid not null references public.associados (id) on delete cascade,
  ano             int not null,
  mes             int not null check (mes between 1 and 12),
  avaliador_nome  text,
  avaliador_cargo text,
  data_avaliacao  date,
  positivas       text,
  desenvolver     text,
  inovacao        text,
  comentarios     text,
  avaliador_id    uuid references public.associados (id) on delete set null,
  atualizado_em   timestamptz not null default now(),
  primary key (associado_id, ano, mes)
);

-- Parte 1: o que o associado escreve sobre o próprio mês
create table if not exists public.autoavaliacoes (
  associado_id         uuid not null references public.associados (id) on delete cascade,
  ano                  int not null,
  mes                  int not null check (mes between 1 and 12),
  atividades           text,
  depto                jsonb not null default '[]'::jsonb,   -- 5 notas de 1 a 3
  periodo              text,
  comentarios_periodo  text,
  atualizado_em        timestamptz not null default now(),
  primary key (associado_id, ano, mes)
);

alter table public.avaliacoes_textos enable row level security;
alter table public.autoavaliacoes   enable row level security;

drop policy if exists ler on public.avaliacoes_textos;
create policy ler on public.avaliacoes_textos for select to authenticated
  using (associado_id = (public.eu()).id or public.pode_gerir(associado_id));
drop policy if exists gerir on public.avaliacoes_textos;
create policy gerir on public.avaliacoes_textos for all to authenticated
  using (public.pode_gerir(associado_id)) with check (public.pode_gerir(associado_id));

-- a autoavaliação é escrita pelo próprio associado (ou pelo gestor dele)
drop policy if exists ler on public.autoavaliacoes;
create policy ler on public.autoavaliacoes for select to authenticated
  using (associado_id = (public.eu()).id or public.pode_gerir(associado_id));
drop policy if exists escrever on public.autoavaliacoes;
create policy escrever on public.autoavaliacoes for all to authenticated
  using (associado_id = (public.eu()).id or public.pode_gerir(associado_id))
  with check (associado_id = (public.eu()).id or public.pode_gerir(associado_id));

select (select count(*) from criterios where avalia like 'Cumpre o que%') entregas_ok,
       (select count(*) from rubrica where nivel = 'Adequado') rubrica_ok;
