# Regra FinOps FIN-06: Log Analytics com retenção acima de 90 dias ou sem daily cap.
# Guardar log além do necessário cobra por GB por mês; sem limite diário (daily cap),
# um pico de ingestão vira uma conta alta sem aviso.
@{
    Id         = 'FIN-06'
    Titulo     = 'Log Analytics guardando dados por mais de 90 dias ou sem limite diário'
    Severidade = 'Média'  # Alta, Média ou Baixa

    # Prefixo do nome do recurso no modo anonimizado: workspace-01, workspace-02...
    Rotulo     = 'workspace'

    # dailyQuotaGb igual a -1 quer dizer sem limite diário. Validar no ensaio.
    Kql        = @'
resources
| where type =~ 'microsoft.operationalinsights/workspaces'
| extend retencaoDias = toint(properties.retentionInDays),
         limiteGB = toreal(properties.workspaceCapping.dailyQuotaGb)
| extend semLimite = isnull(limiteGB) or limiteGB < 0
| where retencaoDias > 90 or semLimite
| project id, name, resourceGroup, subscriptionId, location,
          plano = tostring(properties.sku.name),
          retencaoDias,
          limiteDiario = iff(semLimite, 'sem limite', strcat(tostring(limiteGB), ' GB'))
| order by name asc
'@

    # Como estimar a economia: não dá. O custo depende do volume guardado e ingerido por dia,
    # que o Resource Graph não informa.
    Economia   = @{
        Forma  = 'nao-sei'
        Motivo = 'O custo depende do volume de dados guardado e ingerido, que o Resource Graph não informa.'
    }
}
