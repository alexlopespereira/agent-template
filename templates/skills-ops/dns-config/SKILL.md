---
name: dns-config
description: Configuração de DNS no registro.br via Playwright. Use quando o negócio tem um domínio registrado e precisa configurar registros DNS para apontar para Netlify, email, ou outros serviços. Cobre login no registro.br, criação/edição de registros DNS (A, CNAME, MX, TXT), e verificação de propagação. Requer Playwright configurado.
metadata:
  version: 1.0.0
---

# Configuração DNS — registro.br via Playwright

Você é responsável por configurar os registros DNS dos domínios do negócio no registro.br usando Playwright.

## Pré-requisitos

- Playwright instalado e funcional (MCP server `playwright` disponível)
- Domínio já registrado no registro.br
- Registros DNS necessários (obtidos da Netlify via `/netlify-deploy`, ou de outro serviço)
- Credenciais do registro.br (em `secrets/keys.env` se disponível)

## Processo

### Passo 1 — Identificar registros DNS necessários

Antes de abrir o navegador, confirme que você tem todos os registros necessários.

**Para apontar para Netlify (caso típico LP):**
- `A` record: `@` → IP da Netlify (geralmente `75.2.60.5`)
- `CNAME` record: `www` → `<site-name>.netlify.app`

**Para email profissional (se aplicável):**
- `MX` records conforme o provedor de email
- `TXT` record para SPF
- `TXT` record para DKIM (se disponível)

**Anote todos os registros antes de começar.** Se não tem os registros, execute `/netlify-deploy` primeiro para obtê-los.

### Passo 2 — Login no registro.br

```
1. Navegar para https://registro.br
2. Clicar em "Acesse sua conta" ou "Login"
3. Inserir CPF/CNPJ e senha
4. Completar autenticação (pode ter 2FA)
5. Aguardar o painel carregar
```

**Se o login exigir 2FA, token, ou CAPTCHA que Playwright não consegue resolver:**
- Tire screenshot da tela
- Notifique o fundador via Telegram com o screenshot
- Aguarde resolução manual antes de prosseguir

### Passo 3 — Navegar até o painel DNS do domínio

```
1. No painel, localizar a lista de domínios registrados
2. Clicar no domínio que precisa ser configurado (ex: devolver.ia.br)
3. Procurar a opção "DNS" ou "Configurar zona DNS" ou "Editar zona"
4. Se o DNS ainda não estiver ativo, pode ser necessário "Ativar DNS" primeiro
```

**Dicas de navegação registro.br:**
- O painel pode estar em https://registro.br/painel/
- A interface do registro.br pode variar — procure por "DNS", "Zona DNS", ou "Servidores DNS"
- Se o domínio usa DNS do próprio registro.br, você edita os registros diretamente
- Se usa DNS externo, pode ser necessário alterar os nameservers primeiro

### Passo 4 — Configurar registros DNS

Para cada registro necessário:

```
1. Na zona DNS, clicar em "Adicionar registro" ou "Novo registro"
2. Selecionar o tipo (A, CNAME, MX, TXT)
3. Preencher:
   - Nome/Host (ex: "@" para raiz, "www" para subdomínio)
   - Valor/Destino (ex: IP da Netlify, CNAME do Netlify)
   - TTL (usar padrão ou 3600 se disponível)
4. Salvar o registro
5. Repetir para cada registro necessário
```

**Registros típicos para LP na Netlify:**

| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| A | @ | 75.2.60.5 | 3600 |
| CNAME | www | <site>.netlify.app | 3600 |

**ATENÇÃO:** O IP da Netlify (`75.2.60.5`) é o endereço do load balancer. Confirme o IP atual na documentação da Netlify ou no painel ao configurar o domínio customizado. A Netlify pode recomendar usar ALIAS/ANAME record em vez de A — use o que o registro.br suportar.

### Passo 5 — Verificar configuração

```
1. Após salvar todos os registros, revisar a lista completa de registros DNS
2. Tirar screenshot da zona DNS configurada para registro
3. Aguardar propagação (pode levar de minutos a 48h, tipicamente 15-60min)
```

**Verificação via terminal (se disponível):**
```bash
# Verificar A record
dig +short nome.ia.br A

# Verificar CNAME
dig +short www.nome.ia.br CNAME

# Verificar propagação global
dig @8.8.8.8 +short nome.ia.br A
```

### Passo 6 — Validar conectividade end-to-end

Após DNS propagar:

```
1. Acessar https://nome.ia.br no navegador via Playwright
2. Verificar que a LP carrega corretamente
3. Verificar que HTTPS funciona (certificado válido)
4. Testar https://www.nome.ia.br (redirect ou acesso direto)
```

### Passo 7 — Registrar resultado

Após configuração:
- Atualize `business.md` com status do DNS
- Registre em `experiments.log`:

```json
{"type": "dns-config", "domain": "nome.ia.br", "provider": "registro.br", "records": ["A @→75.2.60.5", "CNAME www→site.netlify.app"], "status": "configured|propagating|verified", "date": "YYYY-MM-DD", "notes": "..."}
```

- Notifique o fundador via Telegram:

```
🔧 DNS configurado: nome.ia.br
Registros: A @ → 75.2.60.5 | CNAME www → site.netlify.app
Status: propagando (verificar em ~30min)
```

## Guardrails

- **Nunca delete registros DNS existentes sem confirmar** — pode derrubar email ou outros serviços
- Se já existem registros DNS, liste-os e avalie conflitos antes de modificar
- Se o registro.br exigir CAPTCHA ou verificação manual, notifique via Telegram com screenshot
- Após configurar, verifique com `dig` antes de declarar sucesso
- Se a propagação demorar mais de 2h, notifique o fundador — pode haver erro de configuração
- Sempre tire screenshot da zona DNS final como registro
