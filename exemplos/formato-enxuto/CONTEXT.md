# Sistema interno da TFTEC

Sistema interno de operação da TFTEC. Consolida alunos, vendas, cobranças e comunicação de várias plataformas numa identidade única por pessoa e é operado por chat com IA em vez de telas de CRUD.

<!-- Cópia sanitizada: trecho com 8 termos do glossário original, nos mesmos grupos e no mesmo formato. -->

## Language

### Pessoas

**Customer**:
A pessoa ou empresa real, única, consolidada a partir de todas as plataformas. Para saber quem é a pessoa vale, nesta ordem: CPF, e-mail (principal ou alternativo) e telefone, este só quando um único Customer o tem. Todo "quem" do sistema é um Customer.
_Avoid_: Person, Aluno, Account, Client, Contact, StudentProfile

**CPF**:
O documento que identifica a pessoa: dois Customers com o mesmo CPF são a mesma pessoa, mesmo com e-mails, telefones ou nomes diferentes.
_Avoid_: Documento (quando for CPF), DocumentNumber (fora do código)

**E-mail principal / E-mail alternativo**:
Um Customer tem um e-mail principal e pode ter vários alternativos: outros e-mails com que comprou ou se cadastrou. Qualquer um deles identifica a pessoa quando ela não informou CPF.
_Avoid_: E-mail secundário, e-mail antigo

**Merge**:
Junção de dois Customers que são a mesma pessoa. Sobrevive o que tem CPF; o outro deixa de existir e tudo o que era dele passa ao sobrevivente, sem sobrescrever o que o sobrevivente já tem.
_Avoid_: Dedup, Unificação, Fusão

**Kind**:
O papel de um Customer: `lead`, `b2b_company` (empresa cliente) ou `b2b_contact` (pessoa ligada a uma empresa cliente).
_Avoid_: Type, accountType

**Lead**:
Customer que demonstrou interesse e nunca comprou. É um Customer de Kind `lead`, não uma entidade à parte.
_Avoid_: CrmLead, Prospect (é um estágio do funil, não um tipo)

### Plataformas

**Connector**:
Componente que conversa com uma plataforma externa: recebe webhook, puxa por API, importa planilha ou envia dados.
_Avoid_: Integration, Sync, Importer (reserve para importação de planilha)

### Command Center

**Action**:
Operação com efeito externo proposta pela IA e que aguarda confirmação humana.
_Avoid_: Task, Pending

## Termos em aberto

Definições de negócio que o dono ainda não cravou; até lá vale o que o código faz hoje.

- Aluno ativo: turma ativa e pagamento em dia, ou só turma ativa.
- Plano vigente: qual assinatura vale quando o Customer tem várias.
