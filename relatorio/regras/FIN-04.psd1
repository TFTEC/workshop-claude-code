# Regra FinOps FIN-04: App Service Plan sem apps.
# O plano cobra pelas instâncias reservadas, tenha app rodando nele ou não.
@{
    Id         = 'FIN-04'
    Titulo     = 'Plano do App Service pago e sem nenhum app'
    Severidade = 'Alta'   # Alta, Média ou Baixa

    # Prefixo do nome do recurso no modo anonimizado: plano-01, plano-02...
    Rotulo     = 'plano'

    # Ficam de fora as camadas que não têm custo fixo: Free e Shared, e os planos de consumo
    # das Functions (Dynamic e FlexConsumption), que só cobram quando algo executa. Validar no ensaio.
    # so: o sistema do plano, que muda o preço. reserved = Linux; hyperV = contêiner Windows.
    Kql        = @'
resources
| where type =~ 'microsoft.web/serverfarms'
| where toint(properties.numberOfSites) == 0
| where tostring(sku.tier) !in~ ('Free', 'Shared', 'Dynamic', 'FlexConsumption')
| project id, name, resourceGroup, subscriptionId, location,
          sku = tostring(sku.name),
          camada = tostring(sku.tier),
          instancias = toint(sku.capacity),
          so = case(tobool(properties.hyperV), 'Windows Container', tobool(properties.reserved), 'Linux', 'Windows')
| order by name asc
'@

    # Como estimar a economia: o preço de tabela da instância na Retail Prices API, por hora,
    # x 730 horas x o número de instâncias. Só para as camadas, os SKUs e os sistemas da tabela
    # abaixo; o resto (Isolated, Elastic Premium, contêiner Windows...) fica com "não sei".
    Economia   = @{
        Forma      = 'preco-de-tabela'
        # Com -CustoReal, o custo real dos últimos 30 dias troca esta estimativa: o plano vazio custa o que o Cost Management diz.
        CustoReal = $true
        DePara     = @{
            # A camada do plano no nome do produto: Azure App Service Premium v3 Plan.
            plano  = @{ Coluna = 'camada'; Valores = @{
                    Basic = 'Basic'; Standard = 'Standard'; PremiumV2 = 'Premium v2'; PremiumV3 = 'Premium v3'
                } }
            # O plano Linux é outro produto: Azure App Service Premium v3 Plan - Linux.
            sufixo = @{ Coluna = 'so'; Valores = @{ Windows = ''; Linux = ' - Linux' } }
            # O SKU como a Retail Prices API escreve: P1v3 vira P1 v3, mas o P0v3 fica sem espaço
            # (conferido na API real em 09/10).
            skuApi = @{ Coluna = 'sku'; Valores = @{
                    B1 = 'B1'; B2 = 'B2'; B3 = 'B3'; S1 = 'S1'; S2 = 'S2'; S3 = 'S3'
                    P1v2 = 'P1 v2'; P2v2 = 'P2 v2'; P3v2 = 'P3 v2'
                    P0v3 = 'P0v3'; P1v3 = 'P1 v3'; P2v3 = 'P2 v3'; P3v3 = 'P3 v3'
                } }
        }
        # Sem meterName no filtro: o nome do medidor muda de um produto para outro. No plano Basic
        # Linux, ele é só o SKU ("B1"); nos outros, o SKU com " App" ("B1 App" no Basic Windows,
        # "P1 v3 App"). Conferido na API real em 09/10, em westus2 e brazilsouth: o produto, o SKU e
        # a região já apontam um preço de consumo só. Se a API trouxer mais de um, o achado fica com
        # "não sei".
        Medidor    = @{
            serviceName   = 'Azure App Service'
            productName   = 'Azure App Service {plano} Plan{sufixo}'
            skuName       = '{skuApi}'
            armRegionName = '{location}'
        }
        # O preço é por instância: multiplica pela coluna instancias.
        Quantidade = 'instancias'
    }
}
