# 04: Fonte Azure, a leitura da subscription de verdade

**What to build:** Com `-Fonte Azure`, o relatório FinOps lê a subscription-alvo ao vivo, só com comandos de leitura, e entrega ao motor exatamente o mesmo formato da fonte `Arquivo`. Os mesmos dados dão o mesmo `achados.json` nas duas fontes.

**Blocked by:** 01 (motor e primeira regra)

**Status:** ready-for-agent

**Tempo:** 30 min (estimado)

- [ ] Para cada regra, o script roda `az graph query` com escopo na subscription-alvo, 1.000 linhas por página e JSON. Enquanto vier skip token, ele busca a próxima página e junta as linhas.
- [ ] A KQL vai ao `az` **numa linha só**. No Windows, o `az` é um `az.cmd`, e o `cmd.exe` corta o argumento na primeira quebra de linha: a consulta chegaria ao Azure sem o escopo da subscription e leria todas as subscriptions do login.
- [ ] Antes da primeira regra, ele confere o que costuma faltar e para com uma mensagem em português que diz o que fazer: falta o Azure CLI, falta a extensão `resource-graph`, falta o login, a subscription não existe ou falta o papel Reader.
- [ ] Um erro do `az graph query` no meio da execução vira uma mensagem com o nome da regra e o motivo que o Azure deu, sem o JSON bruto.
- [ ] O script só chama `az extension show`, `az account show` e `az graph query`.
- [ ] Os testes usam um `az` falso na frente do PATH, com respostas enlatadas (uma regra com duas páginas, sem extensão, sem login). Esse `az` falso registra cada chamada, e o teste falha se aparecer qualquer comando fora da lista de leitura. Nenhum teste chama o Azure de verdade.
- [ ] Nota para quem testar `az` pela ferramenta Bash do Claude no Windows (Git Bash): um argumento que começa com `/`, como o ID de um recurso, vira caminho de arquivo. Use `MSYS_NO_PATHCONV=1`. O relatório roda no PowerShell e não tem esse problema.
- [ ] Rodado de verdade na própria subscription do aluno, no terminal dele e não pelo Claude: as regras que existem no ambiente aparecem.
