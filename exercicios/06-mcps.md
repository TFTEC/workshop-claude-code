# Exercício 6: MCPs

> **Prática opcional, para depois do workshop:** na manhã do workshop o instrutor demonstra estas funcionalidades ao vivo; use esta ficha para repetir no seu ritmo.

**Horário:** 11h40 · **Tempo:** 20 minutos

**Objetivo:** conectar um servidor MCP ao Claude Code, conferir o status e usar a documentação oficial da Microsoft nas respostas. O instrutor mostra o Azure MCP só para leitura numa demo; quem tem Node.js pode repetir como desafio extra.

**Feature:** `claude mcp add`, `claude mcp list`, `claude mcp get`, `/mcp`, o MCP do Microsoft Learn e o Azure MCP com `--read-only`.

## Antes de começar

Um **servidor MCP** dá ao Claude ferramentas novas, que falam com um sistema de fora: uma documentação, um banco, uma nuvem. Neste exercício você usa dois:

| Servidor | Onde roda | Precisa de login? | O que faz |
|---|---|---|---|
| **Microsoft Learn** | Na Microsoft, pela internet (`https://learn.microsoft.com/api/mcp`) | Não | Busca e lê a documentação oficial da Microsoft |
| **Azure MCP** (opcional) | Na sua máquina, pelo Node.js | Usa o seu `az login` | Consulta os recursos da sua subscription |

Os comandos `claude mcp ...` rodam no **PowerShell**, fora do Claude. Deixe um terminal PowerShell aberto na pasta do repositório. Se preferir não sair do Claude, ponha um `!` na frente, como `!claude mcp list`.

## Passos

1. **Conecte o MCP do Microsoft Learn.** No PowerShell, na pasta do repositório:

   ```powershell
   claude mcp add --transport http microsoft-learn https://learn.microsoft.com/api/mcp
   ```

   A resposta começa com `Added HTTP MCP server microsoft-learn` e termina com `to local config`. **Local** quer dizer: só para você, só neste projeto.

2. **Confira o status.**

   ```powershell
   claude mcp list
   ```

   A linha do `microsoft-learn` mostra `✔ Connected`. Em consoles antigos do Windows, o `✔` aparece como `√`.

3. **Veja o servidor dentro do Claude.** Abra o Claude com `claude`. Se ele já estava aberto, saia com `/exit` e abra de novo, para a sessão enxergar o servidor novo. Rode:

   ```text
   /mcp
   ```

   O `microsoft-learn` aparece conectado, com o número de ferramentas. Escolha o servidor e veja a lista: `microsoft_docs_search`, `microsoft_docs_fetch` e `microsoft_code_sample_search`. Feche com **Esc**.

4. **Pergunte com fonte oficial.** Mande:

   ```text
   Usando o MCP microsoft-learn, explique como encontrar discos gerenciados não anexados no Azure com o Azure CLI. Cite os links da documentação oficial que você usou.
   ```

   Se o Claude pedir permissão para usar uma ferramenta do `microsoft-learn`, escolha **Yes**. A resposta traz links de `learn.microsoft.com`. Disco não anexado é a primeira regra FinOps do relatório da tarde.

5. **Veja quanto o MCP pesa.** Rode `/context` e procure a categoria **MCP tools**. O Claude Code só carrega a definição completa de uma ferramenta MCP quando precisa dela, por isso o peso é pequeno.

**Pronto quando:** o `claude mcp list` e o `/mcp` mostram o `microsoft-learn` conectado, e a resposta do passo 4 trouxe links de `learn.microsoft.com`.

**Desafio extra** (para quem terminou antes)

- Junte o MCP com a skill do exercício 5:

  ```text
  /gerar-runbook Azure Key Vault. Confira cada comando no MCP microsoft-learn e cite os links.
  ```

- **Demo do instrutor, e opcional para quem já tem Node.js: o Azure MCP em somente leitura.** O hook-freio só existe à tarde. Por isso, de manhã, o Azure MCP **só pode** rodar com a opção `--read-only`: com ela, o servidor nem oferece as ferramentas que criam, alteram ou apagam recursos.
  1. Confira o Node.js no PowerShell:

     ```powershell
     node --version
     ```

     Precisa aparecer `v22` ou mais novo. Se der erro, pule este desafio: o Node.js não está no checklist pré-workshop, e o relatório FinOps da tarde lê o Azure pelo `az`, sem o Azure MCP.
  2. Baixe o pacote antes, porque o primeiro download leva um ou dois minutos:

     ```powershell
     npx -y @azure/mcp@latest --version
     ```

  3. Adicione o servidor **com** `--read-only` no fim:

     ```powershell
     claude mcp add --transport stdio azure-mcp -- npx -y @azure/mcp@latest server start --read-only
     ```

     O `--` separa as opções do Claude Code do comando que liga o servidor.
  4. Confira se o modo somente leitura entrou:

     ```powershell
     claude mcp get azure-mcp
     ```

     A linha `Args:` precisa terminar com `--read-only`. Se não terminar, remova com `claude mcp remove azure-mcp -s local` e repita o passo 3.
  5. Se o Claude estiver aberto, saia com `/exit`. Abra de novo no modo que pergunta antes de agir:

     ```powershell
     claude --permission-mode default
     ```

     A linha embaixo do campo de digitar mostra `⏸ manual mode on`. Rode `/mcp` e confira o `azure-mcp` conectado.
  6. Pergunte:

     ```text
     Usando só o azure-mcp, liste os resource groups da minha subscription padrão e quantos recursos cada um tem. Não rode comandos no terminal.
     ```

     Aprove as ferramentas do `azure-mcp`. Se o Claude pedir para rodar qualquer comando `az` no terminal, responda **No**.

  O Azure MCP usa o login do `az login` e a subscription padrão que aparece em `az account show`. Não instale o plugin `azure@claude-plugins-official` de manhã: ele liga o mesmo servidor **sem** `--read-only`.

**Travou?**

- **O `claude mcp add` deu erro:** rode no PowerShell, fora do Claude, ou com `!` na frente dentro do Claude. Copie o comando inteiro, numa linha só.
- **O nome ou a URL saíram errados:** remova com `claude mcp remove microsoft-learn -s local` e adicione de novo.
- **O `microsoft-learn` mostra `✘ Failed to connect`:** pode ser o proxy ou o firewall da empresa. Teste com `curl.exe -I https://learn.microsoft.com/api/mcp`. Uma resposta `HTTP/1.1 405 Method Not Allowed` é normal e prova que a rede chega lá. Se não voltar nenhuma resposta HTTP, a rede bloqueia o acesso: acompanhe a demo do instrutor ou use outra rede.
- **O Claude respondeu sem usar o MCP:** peça de forma explícita: `use a ferramenta microsoft_docs_search do microsoft-learn`.
- **O `azure-mcp` mostra `✘ Failed to connect` na primeira vez:** o `npx` ainda estava baixando o pacote. Rode o passo 2 do desafio e depois, no `/mcp`, escolha o `azure-mcp` e **Reconnect**. Se continuar, aumente o tempo de espera e abra de novo:

  ```powershell
  $env:MCP_TIMEOUT = "120000"
  claude --permission-mode default
  ```

- **O `azure-mcp` dá erro de autenticação:** rode `az login` de novo e confira a subscription com `az account show`.
- **Ficou sem tempo:** faça só os passos 1, 3 e 4.
