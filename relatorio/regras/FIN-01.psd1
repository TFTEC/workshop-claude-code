# Regra FinOps FIN-01: disco não anexado.
# Um disco gerenciado sem VM continua cobrando o tamanho cheio todo mês, sem uso nenhum.
#
# Para criar uma regra nova, copie este arquivo como FIN-xx.psd1, troque os campos e
# coloque o JSON fictício com a resposta da KQL em testes/dados/FIN-xx.json.
@{
    Id         = 'FIN-01'
    Titulo     = 'Disco que não está ligado a nenhuma VM'
    Severidade = 'Alta'   # Alta, Média ou Baixa
    Rotulo     = 'disco'  # No modo anonimizado, os recursos viram disco-01, disco-02...

    # A KQL roda no Azure Resource Graph e já devolve só o que dispara a regra.
    # Projete sempre name, resourceGroup, subscriptionId e, se existir, location;
    # as outras colunas aparecem como detalhes do achado.
    # nuncaAnexado: disco criado vazio que nunca foi ligado a uma VM. O Azure só começa a cobrar
    # esse disco quando ele é anexado pela primeira vez, então ele não tem economia a estimar.
    # O tobool() deixa claro que a coluna é booleana. Mesmo assim, o Resource Graph pode devolver
    # a expressão como 1 ou 0 (visto no ensaio), e o script lê os dois jeitos.
    Kql        = @'
resources
| where type =~ 'microsoft.compute/disks'
| where tostring(properties.diskState) =~ 'Unattached'
| project id, name, resourceGroup, subscriptionId, location,
          sku = tostring(sku.name),
          tamanhoGB = toint(properties.diskSizeGB),
          criadoEm = todatetime(properties.timeCreated),
          nuncaAnexado = tobool(tostring(properties.creationData.createOption) =~ 'Empty' and isnull(properties.LastOwnershipUpdateTime))
| order by name asc
'@

    # Como estimar a economia: o preço de tabela do disco na Retail Prices API, por mês.
    # O Azure cobra o disco pelo menor tier que comporta o tamanho dele: 200 GB de Premium SSD é P15.
    # Fora das famílias da tabela abaixo (Premium SSD v2, Ultra), o achado fica com "não sei".
    Economia   = @{
        Forma    = 'preco-de-tabela'
        # Com -CustoReal, o custo real dos últimos 30 dias troca esta estimativa: o disco solto custa o que o Cost Management diz.
        CustoReal = $true

        # Só estima o disco que o Azure está cobrando. A coluna pode vir como true/false ou como 1/0.
        SoQuando = @{ nuncaAnexado = $false }
        # Por que o achado fica com "não sei" quando a coluna do SoQuando tem outro valor. Coluna
        # vazia ou com um valor que não é booleano continua "Medidor ambíguo".
        MotivoSeNao = @{
            nuncaAnexado = 'O disco foi criado vazio e nunca foi anexado a uma VM: o Azure só começa a cobrar quando ele é anexado pela primeira vez, então ele ainda não cobra e não há economia a estimar.'
        }

        # De-para: o valor de uma coluna da KQL vira um pedaço do nome do medidor.
        DePara   = @{
            produto     = @{ Coluna = 'sku'; Valores = @{
                    Premium_LRS = 'Premium SSD Managed Disks'; Premium_ZRS = 'Premium SSD Managed Disks'
                    StandardSSD_LRS = 'Standard SSD Managed Disks'; StandardSSD_ZRS = 'Standard SSD Managed Disks'
                    Standard_LRS = 'Standard HDD Managed Disks'
                } }
            letra       = @{ Coluna = 'sku'; Valores = @{
                    Premium_LRS = 'P'; Premium_ZRS = 'P'; StandardSSD_LRS = 'E'; StandardSSD_ZRS = 'E'; Standard_LRS = 'S'
                } }
            redundancia = @{ Coluna = 'sku'; Valores = @{
                    Premium_LRS = 'LRS'; Premium_ZRS = 'ZRS'; StandardSSD_LRS = 'LRS'; StandardSSD_ZRS = 'ZRS'; Standard_LRS = 'LRS'
                } }
            # O número do tier pelo tamanho em GB: até 4 GB é o 1 (P1, E1), até 8 é o 2, e assim por diante.
            # O HDD começa no S4 (32 GB): um HDD menor que 17 GB cairia em S1 a S3, que não existem, e fica "não sei".
            numero      = @{ Coluna = 'tamanhoGB'; Faixas = @(
                    @{ Ate = 4; Valor = '1' }, @{ Ate = 8; Valor = '2' }, @{ Ate = 16; Valor = '3' }
                    @{ Ate = 32; Valor = '4' }, @{ Ate = 64; Valor = '6' }, @{ Ate = 128; Valor = '10' }
                    @{ Ate = 256; Valor = '15' }, @{ Ate = 512; Valor = '20' }, @{ Ate = 1024; Valor = '30' }
                    @{ Ate = 2048; Valor = '40' }, @{ Ate = 4096; Valor = '50' }, @{ Ate = 8192; Valor = '60' }
                    @{ Ate = 16384; Valor = '70' }, @{ Ate = 32767; Valor = '80' }
                ) }
        }

        # O medidor na Retail Prices API: cada campo vira um filtro. {nome} vira o valor da coluna
        # da KQL ou do de-para com esse nome. Exemplo: P15 LRS Disk, em Premium SSD Managed Disks.
        Medidor  = @{
            serviceName   = 'Storage'
            productName   = '{produto}'
            skuName       = '{letra}{numero} {redundancia}'
            meterName     = '{letra}{numero} {redundancia} Disk'
            armRegionName = '{location}'
        }
    }
}
