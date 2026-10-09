# ADR-0003: O CPF identifica a pessoa; e-mail é contato

- Status: aceito
- Data: 2026-09-25
- Decisor: dono, na sessão de 25/09/2026 ("CPF igual é uma única pessoa, regra base")
- Contexto de domínio: `CONTEXT.md` › Pessoas (Customer, CPF, E-mail principal / E-mail alternativo, Merge)
- Substitui: a precedência "e-mail primeiro" de um ADR do repositório de origem ("Email: identificador primário universal"; "DocumentNumber: segundo fator")

## Contexto

Em 24/09/2026 um aluno comprou de novo usando um e-mail novo, com o qual tinha deixado lead num formulário de captação minutos antes. O sistema passou a ter dois Customers para a mesma pessoa: o aluno antigo, com o CPF, e o lead, com o e-mail da compra e sem CPF. O webhook da plataforma de vendas achava o lead pelo e-mail, tentava gravar nele o CPF que já era do aluno e perdia a venda (issues #61 e #64). A correção de #61 seguiu a regra então vigente (e-mail primeiro; o CPF de outro dono é ignorado), o que deixava a compra no lead, separada do aluno.

A regra de que o CPF é a chave canônica já existia ("1 pessoa = 1 CPF, N emails", numa regra de importação do repositório de origem) e nas instruções da base de alunos ("consolidar por CPF; e-mail é chave secundária"), mas o código de identidade (`V2SyncHelper`, o webhook da plataforma de vendas, o webhook de lead) seguia o ADR antigo: e-mail → CPF → cria. Os e-mails alternativos são gravados em `CustomerEmail` e nunca consultados na hora de decidir quem é a pessoa.

## Decisão

1. **Quem é a pessoa: CPF → e-mail → telefone único → novo Customer.** O CPF, só com dígitos, decide sozinho quando existe. Sem CPF conhecido, vale o e-mail, principal (`Customer.Email`) ou alternativo (`CustomerEmail`). Sem nenhum dos dois, vale o telefone quando um único Customer ativo o tem.
2. **O e-mail de quem já tem cadastro vira e-mail alternativo.** `Customer.Email` do cadastro existente não muda; o e-mail novo entra em `CustomerEmail`.
3. **Não sobrescrever quem já existe.** Nome, telefone, e-mail principal, CPF, data de criação e UTM de primeiro toque do cadastro existente só são preenchidos quando estão vazios. `ExternalIds` só soma. O estágio (LifecycleStage) nunca rebaixa.
4. **Mesmo CPF em dois Customers é duplicata: Merge.** Sobrevive o que tem CPF (se os dois tiverem, o mais antigo). O outro recebe soft delete (`DeletedAt`), seus filhos são reapontados para o sobrevivente, o e-mail dele vira alternativo do sobrevivente e o par fica registrado em `CustomerMergeCandidate` (`cpf_exact`, `approved`) e em `AuditLog`. Merge é decisão do dono, caso a caso, até existir um fluxo sancionado.

## Consequências

- `V2SyncHelper.UpsertCustomerAsync`, o processador de vendas da plataforma e os webhooks de lead mudam de precedência e passam a consultar `CustomerEmail`. Conflitos que antes ficavam no cadastro do e-mail passam a ir para o dono do CPF.
- Os webhooks de lead não usam o telefone para decidir quem é a pessoa: formulário não traz CPF nem confirma o número, e um dígito errado juntaria duas pessoas (outro ADR do repositório de origem). Lá valem CPF (quando vier) e e-mail, principal ou alternativo.
- A captação de lead só grava o estágio "lead" em quem ainda não tem estágio. A escada antiga do webhook de captação (lead/mql/sql/opportunity/customer/advocate) não conhecia "student" e rebaixava aluno.
- Um lead sem CPF cujo e-mail aparece numa compra com o CPF de outro Customer vira duplicata a juntar; ele não recebe mais a compra.
- Depois de um Merge, o e-mail do apagado continua encontrável (é alternativo do sobrevivente), e o sync não recria o cadastro.
- O ADR antigo do repositório de origem fica superado neste ponto; o resto dele continua valendo.

## Referências

- Issues #61 (venda perdida), #64 (Merge do comprador de 24/09 e recuperação da venda)
- A regra de importação do repositório de origem (CPF canônico; não sobrescrever)
- O slot SQL que criou os e-mails alternativos (`001_customer_email.sql`)
