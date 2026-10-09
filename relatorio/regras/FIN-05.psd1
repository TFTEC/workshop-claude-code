# Regra FinOps FIN-05: snapshot antigo.
# Snapshot cobra pelo espaço guardado. Passado o prazo, quase sempre ninguém lembra para que ele serve.
@{
    Id         = 'FIN-05'
    # {{DiasSnapshot}} é o parâmetro -DiasSnapshot do script (padrão: 30). O motor troca o
    # marcador pelo número antes de rodar a KQL e de mostrar o título.
    Titulo     = 'Snapshot com mais de {{DiasSnapshot}} dias'
    Severidade = 'Baixa'  # Alta, Média ou Baixa

    # Prefixo do nome do recurso no modo anonimizado: snapshot-01, snapshot-02...
    Rotulo     = 'snapshot'

    Kql        = @'
resources
| where type =~ 'microsoft.compute/snapshots'
| extend criadoEm = todatetime(properties.timeCreated)
| where criadoEm < ago({{DiasSnapshot}}d)
| project id, name, resourceGroup, subscriptionId, location,
          tamanhoGB = toint(properties.diskSizeGB),
          incremental = tobool(properties.incremental),
          criadoEm,
          idadeDias = toint((now() - criadoEm) / 1d)
| order by criadoEm asc
'@

    # Como estimar a economia: não dá, nem para o snapshot completo. O Azure cobra o snapshot pelo
    # espaço usado (o incremental, só pelo que mudou), e o Resource Graph não informa esse espaço:
    # o tamanhoGB é o tamanho do disco de origem, e multiplicar por ele inflaria a economia.
    # Se um dia a KQL trouxer o espaço usado, troque por 'preco-de-tabela' com Quantidade.
    Economia   = @{
        Forma  = 'nao-sei'
        # Com -CustoReal, o custo real dos últimos 30 dias troca esta estimativa: o snapshot custa o que o Cost Management diz, e esse custo já é o do espaço usado.
        CustoReal = $true
        Motivo = 'O snapshot é cobrado pelo espaço usado, que o Resource Graph não informa; o tamanhoGB é o do disco de origem e inflaria a conta.'
    }
}
