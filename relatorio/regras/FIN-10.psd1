# Regra FinOps FIN-10 (bônus): NIC sem VM.
# Interface de rede que não está ligada a nenhuma VM: quase sempre é sobra de uma VM apagada.
# A NIC em si não é cobrada, mas ela ocupa um IP da sub-rede e pode segurar um IP público, que cobra.
@{
    Id         = 'FIN-10'
    Titulo     = 'Interface de rede (NIC) que não está ligada a nenhuma VM'
    Severidade = 'Baixa'  # Alta, Média ou Baixa

    # Prefixo do nome do recurso no modo anonimizado: nic-01, nic-02...
    Rotulo     = 'nic'

    # Fora as NICs sem VM que estão em uso por outro serviço, segundo a referência da API de
    # Network Interfaces: a de Private Endpoint (privateEndpoint), a de Private Link Service
    # (privateLinkService) e a de BareMetal (hostedWorkloads e workloadType). Também fica de fora a
    # NIC que outro recurso gerencia (managedBy). Validar no ensaio.
    # temIpPublico: alguma configuração de IP da NIC aponta para um IP público. Esse IP não aparece
    # em FIN-02, porque está associado (à NIC), e só fica livre quando a NIC sai.
    Kql        = @'
resources
| where type =~ 'microsoft.network/networkinterfaces'
| where isnull(properties.virtualMachine)
| where isnull(properties.privateEndpoint) and isnull(properties.privateLinkService)
| where coalesce(array_length(properties.hostedWorkloads), 0) == 0 and isempty(tostring(properties.workloadType))
| where isempty(managedBy)
| project id, name, resourceGroup, subscriptionId, location,
          ipPrivado = tostring(properties.ipConfigurations[0].properties.privateIPAddress),
          temIpPublico = tobool(tostring(properties.ipConfigurations) contains '/publicIPAddresses/')
| order by name asc
'@

    # Como estimar a economia: não há o que estimar, porque a NIC não é cobrada. O achado fica com
    # "não sei" e o motivo diz isso: mostrar 0 daria a entender que o relatório calculou algo.
    Economia   = @{
        Forma  = 'nao-sei'
        Motivo = 'A NIC sozinha não é cobrada: este achado é de arrumação, e não de economia. Se ela segura um IP público (temIpPublico), o IP cobra à parte e só fica livre quando a NIC sai.'
    }
}
