---
name: domain-registration
description: Pesquisa e registro de domínios no registro.br usando Playwright. Use quando o negócio precisa de um domínio, quando o playbook indica que o domínio ainda não foi registrado, ou quando o usuário pede para registrar um domínio. Cobre busca de nomes disponíveis (preferência .ia.br), validação com o fundador via Telegram, e o processo de registro. Requer Playwright configurado.
metadata:
  version: 1.0.0
---

# Registro de Domínio — registro.br via Playwright

Você é responsável por pesquisar e registrar domínios para o negócio no registro.br.
A preferência é pelo TLD **.ia.br** (inteligência artificial). Se não houver boas opções em .ia.br, considere .com.br e .ai como alternativas.

## Pré-requisitos

- Playwright instalado e funcional (MCP server `playwright` disponível)
- Acesso ao registro.br (credenciais em `secrets/keys.env` se disponível)

## Processo

### Passo 1 — Gerar candidatos de nome

Antes de abrir o navegador, gere uma lista de **10-15 nomes candidatos** baseados em:

1. **Nome do negócio** (codename, variações, abreviações)
2. **Domínio de atuação** (palavras-chave do setor)
3. **Proposta de valor** (o que o negócio faz, em 1 palavra)
4. **Combinações criativas** (verbo+substantivo, prefixo+keyword)

Critérios para bons nomes:
- Curto (idealmente ≤ 12 caracteres antes do TLD)
- Fácil de soletrar e pronunciar em português
- Memorável e relacionado ao negócio
- Sem hífens se possível
- Sem ambiguidade fonética

### Passo 2 — Verificar disponibilidade no registro.br

Use Playwright para verificar cada candidato:

```
1. Navegar para https://registro.br
2. No campo de busca principal, digitar o nome candidato (ex: "meunegocio.ia.br")
3. Submeter a busca
4. Ler o resultado — disponível ou não
5. Se disponível, anotar o nome e o preço
6. Repetir para cada candidato
```

**Dicas de navegação:**
- O registro.br tem um campo de busca na página inicial
- Resultados aparecem na mesma página ou em página de resultado
- Se o domínio não está disponível, o site sugere alternativas — capture essas sugestões também
- Verifique variações com e sem hífen
- Teste nos TLDs: .ia.br (prioridade), .com.br, .ai

### Passo 3 — Montar shortlist e validar via Telegram

Monte uma shortlist dos **3-5 melhores nomes disponíveis** com:
- Nome completo do domínio
- TLD
- Preço anual
- Justificativa (por que é um bom nome para o negócio)

**OBRIGATÓRIO: Envie a shortlist para o fundador via Telegram usando o notify.sh antes de prosseguir.**

Formato da mensagem:

```
🌐 Domínios disponíveis para {{ CODENAME }}

1. nome1.ia.br — R$ XX/ano
   → [justificativa curta]

2. nome2.ia.br — R$ XX/ano
   → [justificativa curta]

3. nome3.com.br — R$ XX/ano
   → [justificativa curta]

Qual você prefere? Responda com o número ou sugira outro nome.
```

**Aguarde a resposta do fundador antes de prosseguir para o registro.**
Se o fundador sugerir um nome diferente, volte ao Passo 2 para verificar disponibilidade.

### Passo 4 — Registrar o domínio escolhido

Após confirmação do fundador:

```
1. Navegar para https://registro.br
2. Fazer login (se credenciais disponíveis em secrets/)
3. Buscar o domínio aprovado
4. Iniciar processo de registro
5. Preencher dados conforme necessário
6. Confirmar registro
```

**IMPORTANTE:** Se o processo de registro exigir pagamento ou dados sensíveis que você não tem, pare e notifique o fundador via Telegram com as instruções do que falta para completar o registro manualmente.

### Passo 5 — Registrar resultado

Após o registro (ou tentativa):
- Atualize `business.md` seção de domínio com o domínio registrado
- Marque o item "Domínio registrado" no playbook como concluído
- Registre em `experiments.log`:

```json
{"type": "domain-registration", "domain": "nome.ia.br", "status": "registered|pending-payment|failed", "date": "YYYY-MM-DD", "notes": "..."}
```

## Guardrails

- **Nunca registre um domínio sem aprovação explícita do fundador via Telegram**
- Se houver dúvida sobre o nome, envie mais opções — não decida sozinho
- Gasto máximo: dentro do limite de R$ 40/ano (domínios .ia.br e .com.br custam ~R$ 40/ano)
- Se o registro.br exigir CAPTCHA ou verificação que Playwright não consegue resolver, notifique o fundador com screenshot e instruções
- Prefira .ia.br > .com.br > .ai (nesta ordem de prioridade)
