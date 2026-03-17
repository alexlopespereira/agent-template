---
name: netlify-deploy
description: Deploy de landing pages na Netlify via Playwright. Use quando o negócio tem uma LP pronta (HTML/CSS) e precisa publicá-la, configurar domínio customizado, ou atualizar um deploy existente. Cobre login, criação de site, upload de arquivos, configuração de domínio customizado e verificação de SSL. Requer Playwright configurado.
metadata:
  version: 1.0.0
---

# Deploy de Landing Page — Netlify via Playwright

Você é responsável por publicar e manter landing pages do negócio na Netlify usando o navegador via Playwright.

## Pré-requisitos

- Playwright instalado e funcional (MCP server `playwright` disponível)
- Credenciais da Netlify (email/senha em `secrets/keys.env` se disponível)
- Arquivos da LP prontos (tipicamente em `lp/` ou `site/`)

## Processo

### Passo 1 — Verificar LP pronta para deploy

Antes de abrir o navegador, confirme que existe uma LP válida:

1. Verifique se existe `lp/index.html` (ou diretório equivalente)
2. Confirme que a LP não tem placeholders visíveis ("Lorem ipsum", "Coming soon", "TODO")
3. Verifique que todos os assets (CSS, imagens, JS) estão referenciados com paths relativos
4. Confirme que a LP segue a identidade visual do `business.md` Seção 12

Se a LP não está pronta, **pare e notifique via Telegram** — não faça deploy de conteúdo incompleto.

### Passo 2 — Login na Netlify

```
1. Navegar para https://app.netlify.com
2. Se não estiver logado, clicar em "Log in"
3. Usar email/senha das credenciais (ou login via GitHub se configurado)
4. Aguardar o dashboard carregar
```

**Se o login exigir 2FA ou CAPTCHA que Playwright não consegue resolver:**
- Tire screenshot da tela
- Notifique o fundador via Telegram com o screenshot e instruções
- Aguarde resolução manual antes de prosseguir

### Passo 3 — Criar site ou acessar site existente

**Novo site:**
```
1. No dashboard, clicar em "Add new site" → "Deploy manually"
2. Fazer upload da pasta da LP (drag & drop ou seleção de arquivos)
3. Aguardar o deploy completar
4. Anotar a URL temporária gerada (ex: random-name-123.netlify.app)
```

**Site existente:**
```
1. No dashboard, clicar no site do negócio
2. Ir em "Deploys"
3. Fazer upload da nova versão (drag & drop na área de deploy)
4. Aguardar o deploy completar
```

**Dicas de navegação Netlify:**
- O deploy manual aceita uma pasta inteira — faça upload do diretório `lp/`
- Após o upload, a Netlify processa e gera um preview URL automaticamente
- O site fica live imediatamente após deploy

### Passo 4 — Configurar domínio customizado

```
1. No painel do site, ir em "Domain management" ou "Site configuration" → "Domains"
2. Clicar em "Add a domain" ou "Add custom domain"
3. Digitar o domínio registrado (ex: devolver.ia.br)
4. Confirmar a adição
5. A Netlify vai mostrar os registros DNS necessários — anotar:
   - Tipo (A, CNAME, etc.)
   - Nome/Host
   - Valor/Target
   - TTL recomendado
```

**IMPORTANTE:** Anote todos os registros DNS que a Netlify solicitar — você vai precisar deles no passo de configuração DNS no registro.br (skill `/dns-config`).

### Passo 5 — Verificar SSL/HTTPS

```
1. Após configurar o domínio, ir em "HTTPS" ou "SSL/TLS"
2. A Netlify provisiona certificado Let's Encrypt automaticamente
3. Verificar se o certificado foi emitido (pode levar alguns minutos após DNS propagar)
4. Se houver erro de SSL, geralmente é porque o DNS ainda não propagou — aguardar
```

### Passo 6 — Verificar deploy

```
1. Acessar a URL do site (tanto .netlify.app quanto o domínio customizado)
2. Verificar que a LP carrega corretamente
3. Verificar que não há erros no console do navegador
4. Verificar que a LP é responsiva (testar viewport mobile)
```

### Passo 7 — Registrar resultado

Após o deploy:
- Atualize `business.md` com a URL do site
- Marque "Landing page publicada e acessível" no playbook
- Registre em `experiments.log`:

```json
{"type": "netlify-deploy", "site": "nome-do-site.netlify.app", "custom_domain": "nome.ia.br", "status": "deployed|pending-dns|failed", "date": "YYYY-MM-DD", "notes": "..."}
```

- Notifique o fundador via Telegram:

```
✅ LP publicada: https://nome.ia.br
Preview: https://nome-do-site.netlify.app
Status DNS: [propagando/ativo]
```

## Guardrails

- **Nunca faça deploy de LP com conteúdo placeholder ou incompleto** — customer-facing = production quality
- Se o login falhar ou exigir interação manual, notifique via Telegram
- Após deploy, sempre verifique o site acessando a URL final
- Se o domínio customizado não resolver após 24h, investigue configuração DNS
- Mantenha o site `.netlify.app` ativo como fallback
