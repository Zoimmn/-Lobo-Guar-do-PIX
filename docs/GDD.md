# Lobo-Guará do PIX — Documento de Design do Jogo (GDD)

Versão do jogo: 0.1.0 · Engine: Godot 4.7.2 (GDScript) · Plataforma: Android (APK)

## 1. Visão geral

| Item | Definição |
|------|-----------|
| Gênero | *Serious game* de gerenciamento financeiro: híbrido de *idle/management* e simulador textual |
| Público-alvo | Jovens brasileiros de 16 a 25 anos |
| Plataforma | Celular Android em pé (retrato), a partir do Android 7.0 |
| Sessão típica | Cerca de 15 minutos. Campanha completa: estimativa de 40 a 60 minutos, ainda não medida com jogadores |
| Jogadores | Um |
| Conexão | Nenhuma. O jogo não usa internet |

**Premissa.** O jogador é um jovem que vive de entregas por aplicativo. A renda oscila, as contas têm data marcada e o celular não para de trazer ofertas, golpes e imprevistos. A meta é juntar uma reserva de emergência de seis meses do custo de vida sem perder a saúde emocional no caminho.

**Proposta pedagógica.** O jogo desloca o foco da matemática contábil para a economia comportamental: as decisões são tomadas sob pressão de tempo, de dinheiro curto e de gatilhos sociais. O erro é permitido e explicado. Cada armadilha encontrada revela a técnica de manipulação usada, na forma de uma "vacina cognitiva".

## 2. Objetivos do artigo e mecânicas correspondentes

| Objetivo específico do projeto | Onde aparece no jogo |
|--------------------------------|----------------------|
| Representar a progressão de renda, do informal ao formal | Quatro trabalhos (entregador, "PJ" sem carteira, CLT e técnico), cursos e processo seletivo |
| Sistema de eventos aleatórios (golpes, influenciadores e apostas) | 49 eventos em JSON, sorteados por peso, com condições e esperas |
| Indicadores de saúde financeira ligados ao estresse | Equação 1 calculada todo dia e aberta, termo a termo, na aba Vida |
| Simular o FOMO com "escolha rápida" | 16 eventos com relógio; o tempo encurta quando o estresse está alto |
| Reserva de emergência de seis meses | Condição de vitória |
| Juros compostos contra e a favor | Rotativo do cartão com juros diários; reserva com rendimento diário |
| Impostos indiretos regressivos | Imposto embutido registrado em cada gasto e somado no fechamento do mês |
| Telemetria pedagógica anônima | Tabela `telemetria_decisoes` no SQLite |

## 3. Pilares da experiência

1. **O dinheiro anda sozinho.** O tempo corre em segundo plano: a renda entra, as contas vencem e os juros crescem mesmo sem toque na tela.
2. **Toda notificação é uma decisão.** O jogo chega ao jogador pelo celular, como na vida real. Nem toda oferta é golpe e nem todo gasto é erro.
3. **Estresse também é saldo.** A saúde emocional é um recurso finito, alimentado pela dívida, pelo cansaço e pela pressão das redes.
4. **Errar ensina.** Cair em um golpe custa dinheiro de mentira e entrega a explicação de verdade.

## 4. Ciclo de jogo

**Dia** (3 segundos na velocidade normal): entra a renda do dia, saem comida e transporte, vencem as contas com data, correm os juros, o estresse é recalculado e pode chegar uma notificação. O jogador pode pausar, acelerar (2x e 4x) e agir nas abas a qualquer momento. Toda janela aberta para o relógio.

**Mês** (30 dias): moradia no dia 10, contas da casa no dia 15, celular no dia 20, fechamento da fatura no dia 25 e vencimento no dia 5. No fim do mês aparece o fechamento: o que entrou, o que saiu, quanto foi juro, quanto foi imposto embutido e uma dica do Guará, o mentor do jogo.

**Partida:** começa em março, com R$ 600 na conta, e termina em vitória, falência técnica ou esgotamento. Depois da vitória o jogador pode continuar no modo livre.

## 5. Sistemas

### 5.1 Trabalho e renda

| Trabalho | Vínculo | Renda | Requisitos | Particularidades |
|----------|---------|-------|------------|------------------|
| Entregador de app (bike) | Informal | R$ 40 a R$ 84 por dia rodado | Nenhum | Folga semanal sem renda; chuva (12% dos dias) derruba o ganho; sem direitos |
| Atendente "PJ" em loja | PJ | R$ 1.980 por mês | Curso de atendimento | Paga o boleto do MEI (R$ 85) e a passagem; 20% de chance de o pagamento atrasar; pode ser dispensado sem aviso |
| Auxiliar administrativo | CLT | R$ 2.150 brutos (cerca de R$ 1.850 líquidos) | Atendimento e informática | INSS, vale-transporte, vale-refeição de R$ 280, FGTS de 8% e 13º em dezembro |
| Técnico de suporte | CLT | R$ 3.200 brutos | Curso técnico e 2 meses de carteira | Melhor renda do jogo |

* **Ritmo de trabalho.** Leve (renda 25% menor, recupera o cansaço), normal ou puxado (renda 25% maior ou hora extra, o cansaço sobe todo dia). Quem tem salário fixo não tem o ritmo leve.
* **Processo seletivo.** Enviar currículo abre um processo de 4 a 8 dias. A chance de aprovação vai de 65% a 85% e sobe 15 pontos a cada nova tentativa.
* **O vão de renda.** Ao aceitar um salário, a renda diária para na hora e o primeiro pagamento só chega no dia 5 do mês seguinte. Sem caixa para atravessar esse período, a troca vira dívida. É a ligação entre a primeira meta (reserva de um mês) e a saída da informalidade.
* **Direitos na prática.** Doente, o informal perde os dias; o CLT entrega atestado. Na dispensa, o PJ sai sem nada; o CLT recebe aviso prévio e FGTS com multa.

### 5.2 Custo de vida

| Despesa | Valor | Quando |
|---------|-------|--------|
| Moradia | R$ 600 | Dia 10 |
| Contas da casa | cerca de R$ 160 | Dia 15 |
| Plano do celular | R$ 50 | Dia 20 |
| Alimentação | R$ 16 por dia | Todo dia |
| Transporte | Conforme o trabalho | Dias úteis |

O custo de vida de referência é de R$ 1.290 por mês. A meta de reserva é seis vezes esse valor: **R$ 7.740**. Conta sem saldo no vencimento entra em atraso com multa de 2%. Três contas com mais de 30 dias de atraso encerram a partida.

### 5.3 Conta, reserva e crédito

* **Reserva de emergência:** rende cerca de 1% ao mês com capitalização diária e pode ser resgatada a qualquer hora.
* **Cheque especial:** limite de R$ 300, oferecido no segundo mês (o jogador pode recusar). Conta negativa paga 8% ao mês.
* **Cartão de crédito:** oferecido entre os dias 9 e 14, com limite de R$ 700. No vencimento o jogador escolhe pagar o total, o mínimo (15%), parcelar em 6 vezes a 5,5% ao mês ou não pagar. O que sobra vai para o **rotativo**.
* **Rotativo:** juros compostos diários. A taxa é de 8% ao mês nos três primeiros meses e sobe até 14,5% ao mês (mais de 400% ao ano) no sexto mês. Essa rampa é a atenuação inicial da curva de juros discutida na seção 10 do artigo. Os juros param ao atingir 100% do valor original da dívida, como no teto em vigor no Brasil.
* **Empréstimos:** pessoal no aplicativo (7,5% ao mês), agiota (45% ao mês) e renegociação em feirão (2,9% ao mês, com desconto de 30% nos juros).

### 5.4 Estresse e saúde emocional

O estresse vai de 0 a 100 e segue a Equação 1 do artigo:

**S = S0 × e^(α × D) + β × F**

| Termo | Significado no jogo | Valor |
|-------|---------------------|-------|
| S0 | Estresse basal: base do trabalho (16 informal, 14 PJ, 11 e 10 CLT) + cansaço + choques recentes | Entre 4 e 45 |
| D | Dívida ativa ÷ renda dos últimos 30 dias | Calculado todo dia |
| α | Sensibilidade ao endividamento | 0,55 |
| F | Soma dos gatilhos de FOMO recentes; cada um perde 7% da força por dia | Calculado todo dia |
| β | Vulnerabilidade: 2,6 × (1 + 0,07 por gatilho cedido − 0,05 por vacina aprendida) | Entre 1,17 e 4,16 |

A dívida ativa soma rotativo, cheque especial, empréstimos e contas em atraso. O cansaço sobe com o ritmo puxado e com o estudo e cai 0,7 ponto por dia. Os choques vêm de golpes, atrasos e do aperto de ficar sem caixa para a semana.

| Faixa | Estresse | Efeito |
|-------|----------|--------|
| Tranquilo | até 29 | Nenhum |
| Atento | 30 a 49 | Nenhum |
| Tenso | 50 a 69 | A barra de estresse muda de cor |
| Ansioso | 70 a 84 | Entregas rendem 10% menos; o relógio das ofertas fica 30% mais curto |
| No limite | 85 ou mais | Quem ganha por dia tem 20% de chance de não conseguir trabalhar |
| Crítico | 95 ou mais | Dez dias seguidos encerram a partida por esgotamento |

Resistir a um gatilho mantém a exposição por alguns dias; ceder alivia na hora, mas aumenta β e a dívida. As vacinas reduzem β, e por isso resistir fica mais fácil conforme o jogador aprende. É a inoculação psicológica transformada em regra de jogo.

### 5.5 Eventos

| Categoria | Eventos | Exemplos |
|-----------|---------|----------|
| Golpes de PIX e engenharia social | 11 | Perfil clonado, falsa central do banco, PIX "por engano", link falso, comprovante falso |
| Bets | 6 | Print de ganho do amigo, influenciadora, bônus com meta, "recupere o prejuízo" |
| Influenciadores e consumo | 8 | Drop de tênis, celular parcelado, curso milagroso, cripto, Black Friday |
| Crédito | 8 | Cartão, aumento de limite, empréstimo pré-aprovado, agiota, feirão, FGTS |
| Imprevistos | 9 | Celular quebrado, pneu, doença, conta de luz, aplicativo bloqueado |
| Trabalho, sorte e tutorial | 7 | Comparação entre PJ e CLT, gorjeta, mensagens do Guará |

* **Sorteio:** a partir do terceiro dia há 30% de chance diária de um evento novo, com no máximo três notificações esperando. Cada evento tem peso, condições (dia mínimo, vínculo, saldo, cartão) e um tempo de espera antes de repetir.
* **O algoritmo aprende.** Cada clique em aposta, oferta ou crédito aumenta o interesse registrado naquela categoria, e o interesse multiplica a chance de eventos iguais. Silenciar, bloquear e o detox digital esfriam o perfil.
* **Escolha rápida.** Os eventos com relógio dão de 12 a 25 segundos. Quando o tempo acaba, vale a opção padrão.
* **Escolhas sem cor.** Os botões não indicam qual opção é segura. Uma escolha sem saldo ou sem limite aparece bloqueada, com o motivo.
* **Resultado.** Depois da decisão o jogo mostra o que aconteceu, o efeito em conta, dívida e estresse e a vacina correspondente.

### 5.6 Vacinas cognitivas

São 27, cada uma com nome, técnica de manipulação, explicação e forma de proteção. Exemplos: urgência fabricada, perfil clonado, falsa autoridade, a isca do começo, recuperar o prejuízo, viés de sobrevivência, prova social, escassez, ancoragem, "cabe no bolso", juros compostos contra e a favor, limite não é renda, o pacote do ano (PJ e CLT), imposto escondido no preço e o algoritmo que aprende o ponto fraco. A vacina é entregue tanto a quem cai quanto a quem escapa. A coleção fica guardada entre as partidas.

### 5.7 Estudos, bens e lazer

* **Cursos:** atendimento (gratuito, 20 aulas), informática (R$ 240, 40 aulas) e técnico (R$ 650, 80 aulas). Depois da matrícula o curso avança uma aula por dia e pode ser pausado.
* **Bens:** bicicleta e celular antigo no início. Na loja: mochila térmica (renda 8% maior), capa de chuva, celular intermediário e notebook (estudo em dobro). Compras por impulso entram no inventário com valor de revenda baixo.
* **Folga e lazer:** folga (quem é informal perde a renda do dia), rolê com os amigos, cinema e detox digital, cada um com custo e intervalo.

### 5.8 Metas, vitória e derrota

Sete metas: fechar um mês sem dívida, reserva de 1 mês, concluir um curso, 6 vacinas, carteira assinada, reserva de 3 meses e reserva de 6 meses.

* **Vitória:** reserva de seis meses do custo de vida e nenhuma dívida ativa.
* **Falência técnica:** fechar um mês com dívida ativa igual ou maior que três meses de renda, ou acumular três contas com mais de 30 dias de atraso. O jogo avisa quando a dívida passa de 1,5 mês de renda.
* **Esgotamento:** dez dias seguidos com estresse 95 ou mais. O jogo avisa no primeiro dia.
* **Pontuação:** patrimônio ÷ 10 + 150 por golpe evitado + 120 por vacina + 250 por meta − 80 por golpe sofrido − 3 × estresse médio.

## 6. Interface

Toda a interface usa Control Nodes e Containers nativos da Godot, com base de 720 × 1280 e ajuste automático à tela e à área segura do aparelho.

* **Título:** continuar, nova partida, como jogar e coleção de vacinas.
* **Cabeçalho fixo:** mês e dia, controle de velocidade, saldo, reserva em meses, dívida ativa e estresse.
* **Início:** notificações, resumo do mês, próximos vencimentos, metas e diário.
* **Trabalho:** emprego atual e direitos, ritmo, estudos e vagas.
* **Banco:** conta, reserva, cartão, rotativo, empréstimos e extrato com o imposto embutido de cada gasto.
* **Vida:** saúde emocional, folga e lazer, a Equação 1 com os valores do momento, o perfil traçado pelo algoritmo, bens e loja.
* **Relatório:** gráfico de patrimônio e estresse, indicadores da partida, decisões registradas e meses anteriores.
* **Janelas:** evento (com relógio quando há), resultado com vacina, fechamento do mês, fim de partida e menu.

## 7. Dados e telemetria

Banco SQLite local, acessado pelo plugin godot-sqlite (GDExtension):

| Tabela | Conteúdo |
|--------|----------|
| `transacoes` | Histórico de transações: dia, categoria, descrição, valor, meio, saldo e imposto embutido |
| `inventario_bens` | Bens móveis adquiridos e vendidos |
| `log_estresse` | Um registro por dia: estresse, S0, D, F e patrimônio |
| `telemetria_decisoes` | Evento, escolha, tipo de escolha, tempo de resposta e contexto (estresse, D, saldo) |
| `partidas` | Resultado, duração, patrimônio final e pontuação |
| `vacinas` | Vacinas já descobertas no aparelho |
| `estado_salvo` | Partida em andamento e configurações |

Nenhum dado pessoal é coletado e nada sai do aparelho. Em celulares Android de 32 bits, para os quais o plugin não tem binário, os mesmos dados vão para um arquivo JSON.

## 8. Arquitetura

* **Autoloads:** `GameManager` (estado global, relógio e sinais) e `Database` (persistência).
* **Simulação isolada:** `scripts/sim/simulacao.gd` contém todo o estado e todas as regras, sem acesso à interface nem ao disco. Isso permite rodar partidas inteiras em testes.
* **Conteúdo em dados:** eventos, vacinas, empregos, cursos, bens, lazer e metas ficam em JSON.
* **Calibração central:** números da economia em `economia.gd`, coeficientes do estresse em `modelo_estresse.gd`.
* **Testes:** 1.189 verificações automáticas (fórmulas, livro-caixa, cartão, catálogo, salvar e carregar, banco de dados) e bots que jogam partidas completas.

## 9. Equilíbrio medido

Trinta partidas simuladas por perfil, com até 36 meses cada. O percentual indica quantas decisões o perfil toma por impulso.

| Perfil | Vitória | Falência | Esgotamento | Mês típico do desfecho |
|--------|---------|----------|-------------|------------------------|
| Prudente (0%) | 100% | 0% | 0% | Vitória no mês 10 |
| Atento (15%) | 100% | 0% | 0% | Vitória no mês 10 |
| Regular (30%, mas planeja) | 100% | 0% | 0% | Vitória no mês 10 ou 11 |
| Médio (50%, sem planejar) | 0% | 27% | 73% | Derrota por volta do mês 7 |
| Impulsivo (100%) | 0% | 7% | 93% | Derrota por volta do mês 6 |

A diferença entre o perfil regular e o médio está menos na quantidade de erros e mais no planejamento: guardar, estudar e usar a reserva para quitar dívida cara.

## 10. Limitações e próximos passos

* A versão 0.1.0 foi verificada no computador e em um build exportado; ainda falta o teste em celular.
* O jogo não tem som.
* Os valores de salários, juros e impostos são aproximações didáticas, calibradas para o ritmo do jogo.
* A calibração foi feita com jogadores simulados. O artigo prevê o ajuste com um grupo focal de 15 estudantes (Fase 4).
* A telemetria fica no aparelho; a exportação para análise (Fase 6) ainda não existe.
