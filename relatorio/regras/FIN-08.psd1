# Regra FinOps FIN-08 (bônus): Load Balancer vazio.
# Load Balancer sem pool de back-end não tem para onde mandar o tráfego; sem nenhuma regra, não
# recebe tráfego. Nos dois casos, costuma ser sobra de um ambiente que já foi desmontado.
@{
    Id         = 'FIN-08'
    Titulo     = 'Load Balancer sem pool de back-end ou sem regras'
    Severidade = 'Média'  # Alta, Média ou Baixa

    # Prefixo do nome do recurso no modo anonimizado: lb-01, lb-02...
    Rotulo     = 'lb'

    # regras soma as regras de balanceamento, as de NAT de entrada (e os pools de NAT) e as de saída:
    # um Load Balancer só com regra de saída está em uso (dá a saída para a internet das VMs), e não
    # é falso positivo. Um pool que existe, mas ficou vazio (a VM foi apagada), não entra: contar os
    # membros de cada pool fica para validar no ensaio.
    Kql        = @'
resources
| where type =~ 'microsoft.network/loadbalancers'
| extend pools = coalesce(array_length(properties.backendAddressPools), 0),
         regras = coalesce(array_length(properties.loadBalancingRules), 0)
                + coalesce(array_length(properties.inboundNatRules), 0)
                + coalesce(array_length(properties.inboundNatPools), 0)
                + coalesce(array_length(properties.outboundRules), 0)
| where pools == 0 or regras == 0
| project id, name, resourceGroup, subscriptionId, location,
          sku = tostring(sku.name),
          pools, regras
| order by name asc
'@

    # Como estimar a economia: não dá com o preço de tabela. O Load Balancer Standard é cobrado
    # pelas regras configuradas e pelos dados processados, e não por existir: o medidor não é
    # inequívoco. Validar no ensaio.
    Economia   = @{
        Forma  = 'nao-sei'
        # Com -CustoReal, o custo real dos últimos 30 dias troca esta estimativa: o Load Balancer vazio custa o que o Cost Management diz.
        CustoReal = $true
        Motivo = 'O Load Balancer Standard é cobrado pelas regras configuradas e pelos dados processados, e não por existir: o preço de tabela não diz quanto este cobra.'
    }
}
