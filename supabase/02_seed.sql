-- =====================================================================
-- Dados de partida: critérios novos (1 a 4), faixas, regras, XP e loja.
-- Pode rodar de novo sem duplicar nada.
-- =====================================================================

insert into public.criterios (nome, avalia, ordem, escala_max, ativo) values
  ('Entregas', 'Cumprimento de prazos e qualidade do que é entregue.', 1, 4, true),
  ('Criatividade', 'Ideias novas e soluções próprias para os problemas do dia a dia.', 2, 4, true),
  ('Curiosidade', 'Vontade de aprender, perguntar e entender o porquê das coisas.', 3, 4, true),
  ('Iniciativa', 'Agir sem precisar ser cobrado e propor antes de ser pedido.', 4, 4, true),
  ('Planejamento/Organização', 'Organização das tarefas, do tempo e das informações.', 5, 4, true),
  ('Cooperação e Trabalho em Grupo', 'Ajuda aos colegas e contribuição para o resultado do time.', 6, 4, true),
  ('Maturidade/Postura', 'Postura profissional, responsabilidade e forma de lidar com feedback.', 7, 4, true),
  ('Comunicação', 'Clareza ao falar e escrever, e retorno no tempo certo.', 8, 4, true),
  ('Assiduidade', 'Presença e pontualidade nas atividades da empresa.', 9, 4, true),
  ('Eficiência/Qualidade no Trabalho', 'Fazer bem feito, com bom uso do tempo e sem retrabalho.', 10, 4, true),
  ('Conhecimento Teórico', 'Domínio dos conceitos e ferramentas necessários para a função.', 11, 4, true),
  ('Resistência à Pressão', 'Manter a qualidade e a calma em prazos curtos e situações difíceis.', 12, 4, true)
on conflict (nome) do update
  set avalia = excluded.avalia, ordem = excluded.ordem,
      escala_max = excluded.escala_max, ativo = excluded.ativo;

-- rubrica: o que cada nota significa
with r(criterio, nota, nivel, descritor) as (values
  ('Entregas', 4, 'Excelente', 'Entrega tudo dentro do prazo ou antes, com qualidade acima do esperado.'),
  ('Entregas', 3, 'Bom', 'Entrega no prazo, com a qualidade combinada e poucos ajustes.'),
  ('Entregas', 2, 'Regular', 'Atrasa algumas entregas ou precisa refazer partes do trabalho.'),
  ('Entregas', 1, 'Insuficiente', 'Atrasa com frequência ou entrega abaixo do combinado.'),
  ('Criatividade', 4, 'Excelente', 'Traz ideias originais com frequência e elas viram solução de verdade.'),
  ('Criatividade', 3, 'Bom', 'Propõe alternativas próprias quando o problema pede.'),
  ('Criatividade', 2, 'Regular', 'Contribui pouco com ideias e costuma seguir o caminho já conhecido.'),
  ('Criatividade', 1, 'Insuficiente', 'Não propõe ideias, mesmo quando é convidado.'),
  ('Curiosidade', 4, 'Excelente', 'Busca aprender por conta própria e compartilha o que descobre.'),
  ('Curiosidade', 3, 'Bom', 'Pergunta, pesquisa e procura entender o contexto das tarefas.'),
  ('Curiosidade', 2, 'Regular', 'Faz o que foi pedido sem buscar entender além disso.'),
  ('Curiosidade', 1, 'Insuficiente', 'Demonstra pouco interesse em aprender.'),
  ('Iniciativa', 4, 'Excelente', 'Antecipa problemas e age antes de ser pedido, puxando o time junto.'),
  ('Iniciativa', 3, 'Bom', 'Assume tarefas e resolve pendências sem precisar de cobrança.'),
  ('Iniciativa', 2, 'Regular', 'Age quando é cobrado, raramente por conta própria.'),
  ('Iniciativa', 1, 'Insuficiente', 'Espera ser chamado mesmo para o básico.'),
  ('Planejamento/Organização', 4, 'Excelente', 'Planeja com antecedência e mantém tudo organizado e acessível ao time.'),
  ('Planejamento/Organização', 3, 'Bom', 'Organiza bem as próprias tarefas e prazos.'),
  ('Planejamento/Organização', 2, 'Regular', 'Se perde em prazos ou informações de vez em quando.'),
  ('Planejamento/Organização', 1, 'Insuficiente', 'Desorganização atrapalha o próprio trabalho e o dos outros.'),
  ('Cooperação e Trabalho em Grupo', 4, 'Excelente', 'Apoia os colegas sempre e fortalece o resultado do grupo.'),
  ('Cooperação e Trabalho em Grupo', 3, 'Bom', 'Colabora bem e cumpre sua parte nas tarefas em grupo.'),
  ('Cooperação e Trabalho em Grupo', 2, 'Regular', 'Colabora pouco ou só quando é pedido.'),
  ('Cooperação e Trabalho em Grupo', 1, 'Insuficiente', 'Dificulta o trabalho em grupo ou não cumpre sua parte.'),
  ('Maturidade/Postura', 4, 'Excelente', 'É referência de postura e recebe feedback como oportunidade.'),
  ('Maturidade/Postura', 3, 'Bom', 'Age com responsabilidade e respeito nas situações do dia a dia.'),
  ('Maturidade/Postura', 2, 'Regular', 'Oscila na postura ou tem dificuldade com feedback.'),
  ('Maturidade/Postura', 1, 'Insuficiente', 'Postura inadequada para o ambiente da empresa.'),
  ('Comunicação', 4, 'Excelente', 'Comunica com clareza, no tempo certo e mantém todos informados.'),
  ('Comunicação', 3, 'Bom', 'Se comunica bem e responde dentro do esperado.'),
  ('Comunicação', 2, 'Regular', 'Demora a responder ou gera ruído em algumas situações.'),
  ('Comunicação', 1, 'Insuficiente', 'Falhas de comunicação frequentes atrapalham o time.'),
  ('Assiduidade', 4, 'Excelente', 'Presente e pontual em todas as atividades do mês.'),
  ('Assiduidade', 3, 'Bom', 'Raras faltas ou atrasos, sempre justificados.'),
  ('Assiduidade', 2, 'Regular', 'Algumas faltas ou atrasos no mês.'),
  ('Assiduidade', 1, 'Insuficiente', 'Faltas ou atrasos frequentes.'),
  ('Eficiência/Qualidade no Trabalho', 4, 'Excelente', 'Trabalho impecável, feito no tempo certo e sem retrabalho.'),
  ('Eficiência/Qualidade no Trabalho', 3, 'Bom', 'Trabalho de boa qualidade, com poucos ajustes.'),
  ('Eficiência/Qualidade no Trabalho', 2, 'Regular', 'Qualidade irregular ou demora acima do necessário.'),
  ('Eficiência/Qualidade no Trabalho', 1, 'Insuficiente', 'Trabalho precisa ser refeito com frequência.'),
  ('Conhecimento Teórico', 4, 'Excelente', 'Domina os conceitos da função e ensina os colegas.'),
  ('Conhecimento Teórico', 3, 'Bom', 'Conhece bem o que a função exige.'),
  ('Conhecimento Teórico', 2, 'Regular', 'Tem lacunas que às vezes atrapalham as tarefas.'),
  ('Conhecimento Teórico', 1, 'Insuficiente', 'Falta base para executar as tarefas da função.'),
  ('Resistência à Pressão', 4, 'Excelente', 'Mantém a calma e a qualidade mesmo nos momentos mais difíceis.'),
  ('Resistência à Pressão', 3, 'Bom', 'Lida bem com prazos curtos na maior parte das vezes.'),
  ('Resistência à Pressão', 2, 'Regular', 'A qualidade cai quando a pressão aumenta.'),
  ('Resistência à Pressão', 1, 'Insuficiente', 'Tem muita dificuldade sob pressão.')
)
insert into public.rubrica (criterio_id, nota, nivel, descritor)
select c.id, r.nota, r.nivel, r.descritor from r join public.criterios c on c.nome = r.criterio
on conflict (criterio_id, nota) do update set nivel = excluded.nivel, descritor = excluded.descritor;

-- faixas na escala 1 a 4, proporcionais às da planilha (5 / 4,8 / 4,5 / 4 / 3 na escala de 5)
insert into public.faixas_ranking (id, nome, minimo, descricao) values
  ('diamante', 'Diamante', 4.00, 'Mês perfeito: nota máxima em todos os critérios.'),
  ('platina',  'Platina',  3.85, null),
  ('ouro',     'Ouro',     3.60, null),
  ('prata',    'Prata',    3.25, null),
  ('bronze',   'Bronze',   2.50, null)
on conflict (id) do update set nome = excluded.nome, minimo = excluded.minimo, descricao = excluded.descricao;

-- regras de penalidade (confira com o Regimento e ajuste na tabela se precisar)
insert into public.regras_penalidade (chave, janela, limite, minimo, advertencia) values
  ('faltas',           'trimestre', 3,    null, true),
  ('atrasos_reuniao',  'trimestre', 3,    null, true),
  ('atrasos_entrega',  '3meses',    3,    null, false),
  ('media_entregas',   null,        null, 2.50, false),
  ('advertencias',     null,        2,    null, false)
on conflict (chave) do nothing;

insert into public.xp_objetivos (nome, multiplicador, ordem) values
  ('Presença em eventos Extra', 3, 1),
  ('Cursos de Especialização', 5, 2),
  ('Realização de tarefas extras', 4, 3),
  ('Trazer LEADS', 10, 4),
  ('Criação de projeto interno', 4, 5)
on conflict (nome) do update set multiplicador = excluded.multiplicador, ordem = excluded.ordem;

insert into public.loja_produtos (id, nome, titulo, descricao, requer_ranking, preco, estoque, por_pessoa, status, ordem) values
  ('sharktank', 'Sharktank', 'Ingresso Shark Tank', 'Vaga garantida na plateia do Shark Tank interno da Saint Paul Jr.', 'bronze', 10, 0, 1, 'disponivel', 1),
  ('aula-sheets', 'Google sheets básica', 'Aula Google Sheets básica', 'Treinamento ao vivo de Google Sheets do zero ao intermediário.', 'prata', 0, null, 1, 'disponivel', 2),
  ('aula-sheets-avancada', 'Aula de sheets avançada', 'Aula Google Sheets avançada', 'Fórmulas matriciais, tabelas dinâmicas e automação de planilha.', 'ouro', 0, 5, 1, 'disponivel', 3),
  ('aula-valuation', 'Aula de Valuation', 'Aula de Valuation', 'Como avaliar uma empresa: fluxo de caixa descontado e múltiplos.', null, 0, 16, 1, 'disponivel', 4),
  ('almoco', 'Almoço Paulinhos Garden', 'Almoço Paulinhos Garden', 'Almoço no Paulinhos Garden com a diretoria.', null, 25, null, null, 'em_breve', 5),
  ('polo', 'Polo Saint Paul Jr', 'Polo Saint Paul Jr', 'Uniforme oficial da equipe.', null, 0, null, null, 'em_breve', 6),
  ('caneca', 'Caneca Saint Paul Jr', 'Caneca Saint Paul Jr', 'Caneca institucional para o dia a dia.', null, 0, null, null, 'em_breve', 7),
  ('moletom', 'Moletom Saint Paul Jr', 'Moletom Saint Paul Jr', 'Moletom da identidade visual da empresa.', null, 0, null, null, 'em_breve', 8),
  ('porta-cartoes', 'Porta cartões', 'Porta cartões', 'Porta-cartões em couro com a marca.', null, 0, null, null, 'em_breve', 9)
on conflict (id) do nothing;
