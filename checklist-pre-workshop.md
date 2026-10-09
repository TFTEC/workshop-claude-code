# Checklist pré-workshop: Claude Code na prática

**TFTEC Masters**: sábado, 10/10, das 9h às 12h e das 13h30 às 17h (horário de Brasília), online e ao vivo.

**Prazo: até sexta, 09/10, às 22h.** O checklist leva uns 20 minutos. Os primeiros 15 minutos do sábado ficam reservados para destravar quem tiver problema, mas quem chegar com tudo pronto aproveita muito mais.

> 💼 **Notebook da empresa?** Muitas empresas bloqueiam instalação de programas ou colocam proxy na rede. Teste hoje. Se der bloqueio, fale com o seu TI ou use uma máquina pessoal.

## 1. Plano do Claude

O Claude Code exige um plano pago: **Pro, Max, Team ou Enterprise**, ou uma conta Console com créditos. **O plano Free não dá acesso.** Sem plano pago, você acompanha as demos, mas não consegue fazer os exercícios.

## 2. Ferramentas

Os comandos para Windows rodam no PowerShell. No macOS, use o Terminal com o [Homebrew](https://brew.sh) instalado.

| Ferramenta | Windows | macOS | Para conferir |
|---|---|---|---|
| Git | `winget install --id Git.Git -e` | `brew install git` | `git --version` |
| PowerShell 7 | `winget install --id Microsoft.PowerShell -e` | `brew install powershell` | `pwsh --version` (precisa ser 7.x) |
| Azure CLI | `winget install --id Microsoft.AzureCLI -e` | `brew install azure-cli` | `az --version` |
| VS Code (recomendado) | `winget install --id Microsoft.VisualStudioCode -e` | `brew install --cask visual-studio-code` | abrir o VS Code |

Feche e abra o terminal de novo depois de instalar, para que os comandos novos sejam reconhecidos.

**Pester 5**, o framework de testes do PowerShell, que o relatório FinOps da tarde usa. Abra o PowerShell 7 (`pwsh`) e rode:

```powershell
Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion 5.5 -MaximumVersion 5.99
(Get-Module Pester -ListAvailable | Sort-Object Version -Descending)[0].Version
```

O segundo comando precisa mostrar uma versão 5.x. O `-MaximumVersion` evita que venha o Pester 6. No Windows, o Pester 3 que já vem instalado com o sistema não serve.

- **Windows:** instale o Git antes do Claude Code. Ele traz o Git Bash, que o Claude Code usa para rodar comandos.
- **macOS:** se preferir não usar o Homebrew para o PowerShell, a Microsoft tem um instalador `.pkg` em https://aka.ms/powershell-release?tag=stable.

## 3. Claude Code

- **Windows** (PowerShell): `irm https://claude.ai/install.ps1 | iex`
- **macOS, Linux ou WSL**: `curl -fsSL https://claude.ai/install.sh | bash`

O instalador não mostra progresso enquanto baixa. Espere ele terminar, abra um terminal novo e rode `claude --version`: tem que aparecer um número de versão. Se algo der errado, rode `claude doctor` e mande a saída para o grupo.

## 4. Acesso de leitura ao Azure

No sábado, vamos construir um **relatório FinOps** que lê uma subscription sua. O workshop **só lê**: nada é criado, alterado ou apagado.

1. Peça ou confirme o papel **Reader** numa subscription em que você possa praticar. Isso é obrigatório.
2. O papel **Cost Management Reader** na mesma subscription é opcional. Ele serve para o exercício bônus de custo real.
3. Rode estes comandos:

```powershell
az login
az account list --output table
az extension add --name resource-graph
az graph query -q "resources | summarize total=count()" --subscriptions <ID-da-sua-subscription>
```

O `az login` abre a tela de login da Microsoft. O `az account list` mostra as suas subscriptions com o ID de cada uma. No último comando, troque `<ID-da-sua-subscription>` pelo ID, sem os sinais `< >`.

Se a saída do último comando mostrar `"total":` seguido de um número (por exemplo, `"total": 42`), está tudo certo. Se o papel acabou de ser atribuído e der erro de permissão, espere uns 10 minutos, rode `az logout`, depois `az login`, e tente de novo.

## 5. Teste final (1 minuto)

```powershell
mkdir teste-claude
cd teste-claude
claude
```

1. Na primeira vez, siga as perguntas da tela: o navegador abre para você fazer login com a sua conta do Claude. Se ele perguntar se você confia na pasta, confirme.
2. Depois do login, digite: `diga olá e me diga qual modelo você está usando`
3. Se o Claude respondeu, digite `/exit` para sair.

**Pronto.** Nos vemos no sábado às 9h. ✅
