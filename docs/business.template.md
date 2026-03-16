# business.md — Schema Canônico do Experimento
#
# Este template define a estrutura do business.md para cada experimento.
# Campos marcados com (*) são parseados automaticamente pelo Passo 2
# (inferência de contas) do PROMPT_D_PREINSTALL.md.
#
# Setup:
#   cp docs/business.template.md experiments/<slug>/business.md
#   Preencher campos e remover comentários de instrução.
#
# Convenções:
#   [x] = ativo/selecionado    [ ] = inativo/não selecionado
#   [NÃO ENCONTRADO — preencher] = campo obrigatório ainda vazio
#   [não definido — ajustar depois] = campo opcional ainda vazio

---

## 1. Identidade

- **Nome do negócio:** [NÃO ENCONTRADO — preencher]
- **Slug:** [preenchido automaticamente]
- **Tagline:** [NÃO ENCONTRADO — preencher]
- **Descrição (1-2 frases):** [NÃO ENCONTRADO — preencher]
- **Problema que resolve:** [NÃO ENCONTRADO — preencher]
- **Público-alvo:** [NÃO ENCONTRADO — preencher]
- **Diferencial competitivo:** [não definido — ajustar depois]

## 2. Mercado

- **Setor/Nicho:** [NÃO ENCONTRADO — preencher]
- **Geografia inicial:** [não definido — ajustar depois]
- **Tamanho estimado do mercado:** [não definido — ajustar depois]
- **Concorrentes diretos:** [não definido — ajustar depois]
- **Tendências relevantes:** [não definido — ajustar depois]

## 3. Modelo de Negócio

- **Tipo:** [NÃO ENCONTRADO — preencher]
  <!-- Exemplos: SaaS mensal, assinatura anual, transacional por uso,
       marketplace com comissão, freemium, venda única -->
- **Preço principal:** [NÃO ENCONTRADO — preencher]
  <!-- Ex: R$ 97/mês, R$ 497 único, 15% de comissão -->
- **Planos/tiers:** [não definido — ajustar depois]
- **Free trial / freemium:** [ ] sim  [ ] não
- **Receita recorrente (MRR) alvo (6 meses):** [não definido — ajustar depois]

## 4. Produto / MVP

- **O que o MVP entrega:** [NÃO ENCONTRADO — preencher]
- **Funcionalidades core (v1):**
  1. [NÃO ENCONTRADO — preencher]
  2. [não definido — ajustar depois]
  3. [não definido — ajustar depois]
- **Funcionalidades futuras (v2+):** [não definido — ajustar depois]
- **Status atual:** [ ] ideia  [ ] protótipo  [ ] MVP  [ ] em produção

## 5. Canais de Aquisição (*)

> Marque [x] nos canais que serão usados. Cada [x] infere contas necessárias.

- [ ] **Meta Ads** (Instagram/Facebook)  → *infere: Meta Business, Ad Account, Pixel*
- [ ] **Google Ads**                      → *infere: Google Ads, conta de faturamento*
- [ ] **Google orgânico / SEO**           → *infere: Google Search Console, GA4*
- [ ] **WhatsApp Business**               → *infere: WhatsApp Business API, número dedicado*
- [ ] **Email marketing**                 → *infere: SendGrid ou equivalente*
- [ ] **Conteúdo / Blog**                 → *infere: CMS ou gerador estático*
- [ ] **Redes sociais orgânico**          → *infere: perfis comerciais*
- [ ] **Indicação / referral**            → *infere: sistema de referral*
- [ ] **Parcerias / B2B**
- [ ] **Outro:** ___

## 6. Pagamentos e Financeiro (*)

- **Processador:** [ ] Stripe  [ ] PagSeguro  [ ] Mercado Pago  [ ] Outro: ___
- **Stripe Connect (marketplace)?** [ ] sim  [ ] não
- **Moeda principal:** BRL
- **Nota fiscal:** [ ] sim  [ ] não  — Provedor: ___
- **Orçamento mensal de marketing:** [não definido — ajustar depois]
- **Budget diário máx. ads:** [não definido — ajustar depois]

## 7. Stack Técnico (*)

> Cada item marcado infere credenciais no secrets.yaml.

- **Hospedagem:** [ ] Vercel  [ ] Netlify  [ ] AWS  [ ] Cloudflare Pages  [ ] Outro: ___
- **Backend/API:** [ ] Supabase  [ ] Firebase  [ ] API própria  [ ] Outro: ___
- **Banco de dados:** [ ] Supabase (Postgres)  [ ] PlanetScale  [ ] MongoDB  [ ] Outro: ___
- **Auth:** [ ] Supabase Auth  [ ] Auth0  [ ] Clerk  [ ] Outro: ___
- **Email transacional:** [ ] SendGrid  [ ] Resend  [ ] SES  [ ] Outro: ___
- **Analytics:** [ ] Google Analytics 4  [ ] PostHog  [ ] Mixpanel  [ ] Outro: ___
- **Domínio:** [não definido — ajustar depois]
- **DNS/CDN:** [ ] Cloudflare  [ ] Route53  [ ] Outro: ___

## 8. Equipe e Operação

- **Fundador(es):** [NÃO ENCONTRADO — preencher]
- **Tamanho da equipe:** [não definido — ajustar depois]
- **Papel do agente IA:** [NÃO ENCONTRADO — preencher]
  <!-- Ex: pesquisa de mercado, criação de copy, gestão de ads,
       monitoramento de métricas, geração de relatórios -->

## 9. Cronograma

- **Prazo para primeiros clientes pagantes:** [NÃO ENCONTRADO — preencher]
- **Marcos próximos:**
  1. [não definido — ajustar depois]
  2. [não definido — ajustar depois]
  3. [não definido — ajustar depois]

## 10. Notas e Contexto Adicional

<!-- Qualquer informação relevante que não se encaixe nas seções acima.
     Links para documentos, apresentações, referências de mercado, etc. -->

[não definido — ajustar depois]
