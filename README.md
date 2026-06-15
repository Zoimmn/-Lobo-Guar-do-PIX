# 🐺 Lobo-Guará do PIX

> **Simulador Digital de Economia Comportamental baseado na Realidade Socioeconômica Brasileira**

---

## 📌 Sobre o Projeto

O **Lobo-Guará do PIX** é um *serious game* de gerenciamento (estilo *idle/management* e simulador textual) desenvolvido como projeto de pesquisa acadêmica para a **Universidade Católica de Santa Catarina**. 

O objetivo do ecossistema é preencher um vazio pedagógico no mercado de educação financeira, movendo o foco da matemática contábil tradicional (geralmente elitista e focada em realidades estáveis) para a **Economia Comportamental**. O jogo desafia jovens de 16 a 25 anos a sobreviverem ao "corre" do mês brasileiro, enfrentando a informalidade, flutuações de renda e pressões psicológicas da era digital.

---

## 🚀 Diferenciais e Inovação

* **Contextualização Regional:** Simulação de contratos PJ precários, juros abusivos do cartão de crédito rotativo nacional (superiores a 400% a.a.) e a dinâmica de impostos indiretos.
* **Mecânicas de Risco Modernas:** O jogador recebe notificações dinâmicas emulando engenharia social, golpes de clonagem de mensagens, phishing e o mercado agressivo de apostas esportivas (*bets*).
* **Vacinação Cognitiva (Inoculação Psicológica):** O simulador permite o erro, a queda em fraudes e a falência técnica dentro de um ambiente *sandbox* seguro, gerando defesas psicológicas ativas para o mundo real.

---

## 🧠 O Algoritmo de Estresse

A lógica do jogo integra a **Saúde Emocional** como um recurso finito do jogador. O nível de ansiedade e esgotamento é governado por uma equação exponencial inédita de Estresse Acumulado ($S_t$):

$$S_t = S_0 \times e^{\alpha \times D} + \sum (\beta \times F_{fomo})$$

* **$D$ (Razão Dívida/Renda):** Representa o impacto do endividamento sobre a saúde mental (modelado de forma exponencial para simular o efeito "bola de neve").
* **$F_{fomo}$ (Frequência de FOMO):** O acúmulo de gatilhos e pressões de consumo imediatistas das redes sociais (*Fear of Missing Out*), ponderados pelo coeficiente de vulnerabilidade $\beta$.

---

## 🛠️ Arquitetura e Tecnologias

Para garantir a democratização do acesso e o funcionamento estável em dispositivos móveis de entrada, o projeto foi estruturado utilizando:

* **Engine:** [Godot Engine](https://godotengine.org/) (GDScript) pela sua arquitetura modular e extrema leveza de execução.
* **Banco de Dados:** [SQLite](https://www.sqlite.org/) via GDExtension para persistência local robusta de transações e logs de comportamento (telemetria pedagógica).
* **Interface de Usuário:** Sistema nativo de *Control Nodes* e *Containers* da Godot para responsividade automática em múltiplas resoluções de tela.

---

## 📂 Estrutura do Repositório

```text
├── .godot/                # Arquivos de cache da engine
├── src/
│   ├── autoload/          # Scripts globais (GameManager.gd)
│   ├── database/          # Conexão e esquemas do SQLite
│   ├── scenes/            # Cenas do jogo (Menus, HUD, Eventos)
│   └── scripts/           # Lógica comportamental e equações
├── assets/                # Identidade visual (artes do Lobo-Guará) e fontes
├── docs/                  # Artigo científico científico (SBC Template)
└── README.md              # Documentação principal
