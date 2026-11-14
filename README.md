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

## 🎮 Estado atual

**Versão 0.1.0: primeira versão jogável.** O jogador começa como entregador de aplicativo, com R$ 600 na conta, e precisa juntar uma reserva de emergência de seis meses do custo de vida. No caminho:

* o dinheiro entra e sai sozinho, dia após dia (renda, contas com data marcada, juros);
* notificações pedem decisões: 49 eventos entre golpes de PIX, bets, influenciadores, crédito fácil, imprevistos e trabalho, alguns com relógio;
* cada armadilha revela uma **vacina cognitiva** (27 no total), que explica a técnica de manipulação usada;
* o estresse segue a Equação 1 e aparece aberto, termo a termo, na aba Vida;
* a progressão de renda vai do informal ao formal: entregador, "PJ" sem carteira, CLT e técnico, com cursos e processo seletivo;
* a partida termina em vitória (reserva completa), falência técnica ou esgotamento.

## ▶️ Como rodar no computador

1. Instale o [Godot 4.7.2](https://godotengine.org/download) (versão padrão, não a .NET).
2. No Godot, escolha **Importar** e aponte para o arquivo `project.godot` desta pasta.
3. Na primeira abertura o editor carrega o plugin de SQLite. Se aparecer algum erro nessa hora, feche o projeto e abra de novo.
4. Aperte **F5**. A janela abre no formato de um celular em pé.

## 📱 Como gerar o APK

**Pelo editor:** instale os modelos de exportação (Editor > Gerenciar modelos de exportação), configure o Android SDK e o JDK 17 nas configurações do editor e use Projeto > Exportar > Android. O preset já está no repositório (`export_presets.cfg`).

**Pela linha de comando (Linux):**

```bash
sudo bash ferramentas/preparar_ambiente.sh
```

```bash
bash ferramentas/construir_apk.sh
```

O segundo comando roda os testes e grava `build/LoboGuaraDoPIX.apk`, assinado com a chave de depuração do projeto (`ferramentas/android/lobo-guara-debug.keystore`). Essa chave existe só para que todas as versões de teste tenham a mesma assinatura; não serve para publicar em loja.

O APK inclui Android de 64 e de 32 bits. O plugin de SQLite só tem binário para 64 bits: em aparelhos de 32 bits o jogo funciona igual, mas grava os mesmos dados em um arquivo JSON. A tela de título mostra qual mecanismo está em uso.

## 🧩 Estrutura do projeto

| Pasta | Conteúdo |
|-------|----------|
| `autoload/` | `GameManager` (estado global e relógio) e `Database` (SQLite) |
| `scripts/sim/` | Simulação sem interface: `simulacao.gd`, `economia.gd`, `modelo_estresse.gd`, `catalogo.gd` |
| `scripts/ui/` | Tema, componentes, modais e as cinco abas (`telas/`) |
| `cenas/` | Tela de título e cena principal do jogo |
| `dados/` | Conteúdo em JSON: eventos, vacinas, empregos, cursos, bens, lazer e metas |
| `recursos/` | Fontes, ícones e logo |
| `testes/` | Testes automáticos, bots de calibração e roteiro de capturas de tela |
| `ferramentas/` | Scripts de build e a chave de depuração do Android |
| `addons/godot-sqlite/` | Plugin de SQLite (GDExtension) |

## 🔧 Onde ajustar o jogo

* **Eventos e textos:** `dados/eventos.json` e `dados/vacinas.json`. Não é preciso programar para criar um evento novo.
* **Números da economia** (custos, juros, datas): `scripts/sim/economia.gd`.
* **Coeficientes do estresse** (α, β, limites): `scripts/sim/modelo_estresse.gd`.
* **Empregos, cursos e bens:** os outros arquivos de `dados/`.

Depois de qualquer ajuste, rode os testes. Com `--bots` eles também jogam 30 partidas por perfil de jogador e mostram se o equilíbrio continua de pé:

```bash
godot --headless --path . res://testes/testes.tscn -- --bots
```

## 🗄️ Dados e privacidade

O jogo não usa internet e não pede nenhuma permissão além da vibração. Tudo fica em um banco SQLite local, com as tabelas `transacoes` (histórico de transações), `inventario_bens` (bens móveis), `log_estresse` (um registro por dia de jogo), `telemetria_decisoes` (escolha, tipo e tempo de resposta em cada notificação, sem dado pessoal), `partidas`, `vacinas` e `estado_salvo`.

## 📄 Licenças e créditos

* Código do jogo: licença MIT (arquivo `LICENSE`).
* [Godot Engine](https://godotengine.org/): licença MIT.
* [godot-sqlite](https://github.com/2shady4u/godot-sqlite), de Piet Bronders e Jeroen De Geeter: licença MIT.
* Fontes [Nunito](https://github.com/googlefonts/nunito) e [Baloo 2](https://github.com/EkType/Baloo2): SIL Open Font License 1.1.
* Ícones e logo: desenhados para este projeto.

Os valores de juros, impostos e salários são aproximações didáticas da realidade brasileira, calibradas para o ritmo do jogo.
