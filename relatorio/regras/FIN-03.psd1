# Regra FinOps FIN-03: VM desligada que continua cobrando disco.
# VM desalocada não cobra a computação, mas os discos dela continuam cobrando todo mês.
# VM só parada (PowerState/stopped, desligada por dentro do sistema) cobra até a computação.
@{
    Id         = 'FIN-03'
    Titulo     = 'VM desligada que continua pagando pelos discos'
    Severidade = 'Média'  # Alta, Média ou Baixa

    # Prefixo do nome do recurso no modo anonimizado: vm-01, vm-02...
    Rotulo     = 'vm'

    # O join com os discos conta quantos discos gerenciados cada VM desligada tem e quantos GB somam.
    # Um disco anexado tem managedBy igual ao id da VM.
    Kql        = @'
resources
| where type =~ 'microsoft.compute/virtualmachines'
| extend estado = tostring(properties.extended.instanceView.powerState.code)
| where estado in~ ('PowerState/deallocated', 'PowerState/stopped')
| extend vmId = tolower(id)
| join kind=leftouter (
    resources
    | where type =~ 'microsoft.compute/disks'
    | extend vmId = tolower(tostring(managedBy))
    | summarize discos = count(), discosGB = sum(toint(properties.diskSizeGB)) by vmId
  ) on vmId
| project id, name, resourceGroup, subscriptionId, location,
          tamanhoVm = tostring(properties.hardwareProfile.vmSize),
          estado, discos, discosGB
| order by name asc
'@

    # Como estimar a economia: não dá. A KQL soma os GB dos discos, mas o preço depende do tier de
    # cada disco (P10, E15...), que ela não traz; e a VM só parada (stopped) ainda cobra a computação.
    Economia   = @{
        Forma  = 'nao-sei'
        Motivo = 'O custo depende do tier de cada disco da VM, que a KQL não traz, e a VM só parada (stopped) ainda cobra a computação.'
    }
}
