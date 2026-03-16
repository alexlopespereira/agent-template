# business.md — Schema Canônico
# ─────────────────────────────────────────────────────────────────
# Template de referência para o arquivo business.md de cada experimento.
# Commitado em: docs/business.template.md
# Instância em: experiments/<slug>/business.md
#
# INSTRUÇÕES PARA PREENCHIMENTO:
#   - Campos com (*) são usados pelo Prompt D para inferir contas necessárias
#   - Preencha com o máximo de detalhe disponível
#   - O agente lerá este arquivo em todo heartbeat para manter contexto
# ─────────────────────────────────────────────────────────────────

---
# METADADOS (parseados automaticamente — não remover)
slug: ""                  # snake_case — preenchido pelo secrets_setup.sh
name: ""                  # nome legível do negócio
version: "1.0"
created_at: ""
last_updated: ""
owner: ""
---

## 1. Identidade do Negócio

**Nome:** [Nome comercial completo]
**Tagline:** [Uma frase que resume o valor]
**Categoria:** [SaaS | Marketplace | E-commerce | Serviço | Infoproduto | Agência | Outro]
**Estágio:** [Ideia | MVP | Validação | Crescimento | Escala]
**CNPJ/CPF:** [se já constituído — ou: "PF por ora"]

## 2. Problema e Solução

### Problema
[Descreva o problema que o negócio resolve. Seja específico: quem sofre, com que frequência, qual o custo da dor.]

### Solução
[Como o produto/serviço resolve o problema. O que o diferencia.]

### Por que agora?
[Por que este momento é o momento certo para este negócio.]

## 3. Público-Alvo (ICP)

### Perfil primário
- **Quem:** [idade, profissão, renda, região]
- **Dor principal:** [em palavras do próprio cliente]
- **Onde está:** [Instagram, LinkedIn, Google, WhatsApp, etc.] *
- **Como decide:** [impulso | pesquisa | indicação | autoridade]
- **Ticket que pagaria:** [faixa de preço aceitável]

### Perfil secundário (se houver)
[Mesmo formato acima]

## 4. Produto / Serviço

### Oferta principal
[Descreva o que é vendido, o formato de entrega, e o que o cliente recebe.]

### Modelo de precificação (*)
- Tipo: [assinatura mensal | assinatura anual | avulso | por uso | freemium | comissão]
- Preço: [R$ X/mês | R$ X único | X% de comissão]
- Trial: [sim — N dias | não]
- Parcelamento: [sim — Xx sem juros | não]

### Jornada do cliente
[Descreva o caminho: descoberta → interesse → decisão → compra → uso → retenção → indicação]

## 5. Canais de Aquisição (*)

> Esta seção é usada pelo instalador para inferir quais plataformas de ads configurar.

- [ ] **Meta Ads** (Facebook / Instagram) — [sim | não | planejado]
- [ ] **Google Ads** (Search / Display / YouTube) — [sim | não | planejado]
- [ ] **WhatsApp** (atendimento / campanha ativa) — [sim | não | planejado]
- [ ] **Email marketing** (lista própria / newsletter) — [sim | não | planejado]
- [ ] **SEO / Conteúdo orgânico** — [sim | não | planejado]
- [ ] **Indicação / Afiliados** — [sim | não | planejado]
- [ ] **Comunidades / Grupos** — [sim | não | planejado]
- [ ] **Influenciadores** — [sim | não | planejado]
- [ ] **Outbound / SDR** — [sim | não | planejado]
- [ ] **Outro:** ___

## 6. Pagamentos (*)

> Esta seção determina a configuração do Stripe.

- **Processador:** [Stripe | PagSeguro | Mercado Pago | Outro]
- **Moeda principal:** [BRL | USD | outro]
- **Tipo de cobrança:** [único | recorrente | ambos]
- **Marketplace/repasse:** [sim — percentual: X% | não] *
- **Checkout:** [próprio | plataforma terceira (Hotmart, Kiwify, etc.)]
- **NF eletrônica:** [necessária | não por ora]

## 7. Stack de Produto (*)

> Determina quais serviços de infraestrutura configurar.

- **Frontend:** [Next.js | React | Vue | WordPress | Webflow | outro | não definido]
- **Backend:** [Node | Python | não definido]
- **Banco de dados:** [Supabase | PlanetScale | Firebase | outro | não definido] *
- **Hospedagem:** [Vercel | Netlify | Railway | AWS | outro | não definido] *
- **Auth:** [Supabase Auth | NextAuth | Clerk | outro | não definido]
- **Analytics:** [Google Analytics | PostHog | Mixpanel | outro | não definido] *
- **Email transacional:** [SendGrid | Resend | SES | outro | não definido] *
- **CRM:** [não definido | HubSpot | RD Station | outro]

## 8. Métricas de Sucesso

### Meta de validação (30-90 dias)
- **Usuários/clientes pagantes:** [N]
- **MRR alvo:** [R$ X]
- **CAC máximo aceitável:** [R$ X]
- **LTV mínimo esperado:** [R$ X]
- **Taxa de conversão alvo (landing → trial/compra):** [X%]

### North Star Metric
[A métrica que, se crescer, indica que o negócio está saudável]

## 9. Concorrentes

| Concorrente | Preço | Diferencial deles | Nossa vantagem |
|---|---|---|---|
| [Nome] | [R$ X] | [o que fazem bem] | [por que somos melhores para o ICP] |

## 10. Restrições e Compliance

- **Setor regulado:** [sim — regulador: X | não]
- **LGPD:** [dados sensíveis? quais?]
- **Restrições de ads:** [Meta política especial? Google categoria restrita?]
- **Dependências críticas:** [parceiros, APIs, fornecedores sem substituto]

## 11. Contexto Operacional

- **Time:** [só fundador | N pessoas | squad contratado]
- **Budget mensal de marketing:** [R$ X]
- **Prazo para validação:** [N semanas/meses]
- **Restrições geográficas:** [Brasil todo | região específica | global]
- **Idioma do produto:** [PT-BR | EN | outro]

## 12. Comunicação e Voz da Marca

### Tom e voz
- **Tom geral:** [formal | informal | técnico | inspiracional | direto]
- **Registro por canal:**
  - Landing page: [ex: direto e empático, sem jargão]
  - Email: [ex: pessoal, como se fosse de um humano]
  - Social media: [ex: casual, educativo]
  - WhatsApp: [ex: conversacional, breve]

### Identidade visual
- **Cores primárias:** [hex codes]
- **Cores secundárias:** [hex codes]
- **Tipografia:** [fonte títulos / fonte corpo]
- **Logo:** [disponível em assets/logo.svg | a criar]
- **Estilo visual:** [minimalista | tech | amigável | corporativo]

### Comunicação: DO vs DON'T
- **DO:** [ex: usar dados reais, falar a língua do ICP, mostrar resultado concreto]
- **DON'T:** [ex: prometer resultado garantido, usar urgência falsa, inventar depoimentos]

### Trust signals (obrigatórios antes de transação real)
- [ ] Termos de uso publicados
- [ ] Política de privacidade (LGPD)
- [ ] Página "Sobre" ou seção de credibilidade
- [ ] Email profissional (domínio próprio)
- [ ] Política de reembolso clara
- [ ] CNPJ visível (quando constituído)

### Dados de remetente
- **Nome do remetente de emails:** [Ex: "Lucas da Negocia.ai"]
- **Assinatura padrão de emails:** [texto livre]

### Valores da marca
[3-5 valores que guiam toda comunicação. Ex: transparência, eficiência, acessibilidade]

### Red lines de comunicação
[O que NUNCA fazer. Ex: fabricar prova social, prometer economia antes de entregar, dark patterns]

## 13. Infraestrutura (preenchido pelo instalador)

> Esta seção é atualizada automaticamente pelo Prompt D após a pré-instalação.

```yaml
contas_configuradas:
  - servico: ""
    ambiente: ""      # sandbox | production
    data: ""
    responsavel: ""

observacoes: ""
```
