# Regra FinOps FIN-02: IP público sem associação.
# Um IP público Standard cobra por hora mesmo sem estar ligado a nenhum recurso.
@{
    Id         = 'FIN-02'
    Titulo     = 'IP público que não está ligado a nada'
    Severidade = 'Média'  # Alta, Média ou Baixa

    # Prefixo do nome do recurso no modo anonimizado: ip-01, ip-02...
    Rotulo     = 'ip'

    # Sem ipConfiguration, o IP não está numa NIC, num Load Balancer nem num gateway.
    # O IP de um NAT Gateway também não tem ipConfiguration, mas está em uso: por isso a
    # KQL tira quem tem natGateway, para não dar falso positivo. Validar no ensaio.
    # camada (Regional ou Global) e versao (IPv4 ou IPv6) entram para escolher o medidor do preço.
    Kql        = @'
resources
| where type =~ 'microsoft.network/publicipaddresses'
| where isnull(properties.ipConfiguration)
| where isnull(properties.natGateway)
| project id, name, resourceGroup, subscriptionId, location,
          sku = tostring(sku.name),
          alocacao = tostring(properties.publicIPAllocationMethod),
          ip = tostring(properties.ipAddress),
          camada = tostring(sku.tier),
          versao = tostring(properties.publicIPAddressVersion)
| order by name asc
'@

    # Como estimar a economia: o preço de tabela do IP na Retail Prices API, por hora, x 730 horas.
    # Só o IP estático e regional: o IP Global tem outro medidor, e o IP dinâmico sem associação
    # pode nem estar cobrando. Nos dois casos, o achado fica com "não sei".
    Economia   = @{
        Forma    = 'preco-de-tabela'
        # Com -CustoReal, o custo real dos últimos 30 dias troca esta estimativa: o IP sem uso custa o que o Cost Management diz.
        CustoReal = $true
        SoQuando = @{ alocacao = 'Static'; camada = 'Regional' }
        # Exemplo: Standard IPv4 Static Public IP, em IP Addresses.
        Medidor  = @{
            serviceName   = 'Virtual Network'
            productName   = 'IP Addresses'
            skuName       = '{sku}'
            meterName     = '{sku} {versao} Static Public IP'
            armRegionName = '{location}'
        }
    }
}
