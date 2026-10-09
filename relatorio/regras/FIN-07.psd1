# Regra FinOps FIN-07: recomendações de custo do Azure Advisor.
# O Advisor já analisa o uso dos recursos e diz quanto daria para economizar, na moeda da conta.
@{
    Id         = 'FIN-07'
    Titulo     = 'Economia que o Azure Advisor já recomenda'
    Severidade = 'Média'  # Alta, Média ou Baixa

    # Prefixo do nome do recurso no modo anonimizado: recomendacao-01, recomendacao-02...
    Rotulo     = 'recomendacao'

    # Aqui a tabela é advisorresources. O name da recomendação é um GUID, por isso a KQL
    # troca name pelo recurso afetado (impactedValue). Recomendação de nível de subscription,
    # como a de reserva, vem sem resourceGroup.
    # economiaAdvisor e moeda ficam como colunas: é a economia que o próprio Advisor informa
    # (savingsAmount). Validar no ensaio se o valor é mensal.
    Kql        = @'
advisorresources
| where type =~ 'microsoft.advisor/recommendations'
| where tostring(properties.category) =~ 'Cost'
| project id = tostring(properties.resourceMetadata.resourceId),
          name = tostring(properties.impactedValue),
          resourceGroup, subscriptionId,
          tipoDoRecurso = tostring(properties.impactedField),
          problema = tostring(properties.shortDescription.problem),
          impacto = tostring(properties.impact),
          economiaAdvisor = toreal(properties.extendedProperties.savingsAmount),
          moeda = tostring(properties.extendedProperties.savingsCurrency)
| order by economiaAdvisor desc
'@

    # Como estimar a economia: usa o valor que o próprio Advisor informa, na coluna economiaAdvisor.
    # Só vale em reais: se a coluna moeda não for BRL, o achado fica com "não sei" (não convertemos moeda).
    Economia   = @{
        Forma         = 'advisor'
        Coluna        = 'economiaAdvisor'
        ColunaDaMoeda = 'moeda'
    }
}
