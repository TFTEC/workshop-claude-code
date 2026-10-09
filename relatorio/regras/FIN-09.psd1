# Regra FinOps FIN-09 (bônus): App Gateway sem configuração.
# O Application Gateway cobra por hora enquanto está ligado. Sem listener, sem regra ou sem pool de
# back-end, ele não entrega tráfego para ninguém: costuma ser sobra de um ambiente desmontado.
@{
    Id         = 'FIN-09'
    Titulo     = 'Application Gateway sem listener, regra ou pool de back-end'
    Severidade = 'Alta'   # Alta, Média ou Baixa

    # Prefixo do nome do recurso no modo anonimizado: appgw-01, appgw-02...
    Rotulo     = 'appgw'

    # listeners soma os de HTTP(S) e os de TCP/TLS (listeners); regras, as de roteamento de
    # requisição e as de TCP/TLS (routingRules). estado mostra se o gateway está parado (Stopped),
    # caso em que ele não cobra. Um pool que existe, mas está sem alvo, não entra. Validar no ensaio.
    Kql        = @'
resources
| where type =~ 'microsoft.network/applicationgateways'
| extend listeners = coalesce(array_length(properties.httpListeners), 0) + coalesce(array_length(properties.listeners), 0),
         regras = coalesce(array_length(properties.requestRoutingRules), 0) + coalesce(array_length(properties.routingRules), 0),
         pools = coalesce(array_length(properties.backendAddressPools), 0)
| where listeners == 0 or regras == 0 or pools == 0
| project id, name, resourceGroup, subscriptionId, location,
          sku = tostring(properties.sku.name),
          camada = tostring(properties.sku.tier),
          estado = tostring(properties.operationalState),
          listeners, regras, pools
| order by name asc
'@

    # Como estimar a economia: não dá com o preço de tabela. A cobrança depende da camada (a v1,
    # pelo tamanho e pelas instâncias; a v2, por uma parte fixa mais as unidades de capacidade) e
    # do mínimo de instâncias do autoscale, e o gateway parado não cobra. Validar no ensaio.
    Economia   = @{
        Forma  = 'nao-sei'
        # Com -CustoReal, o custo real dos últimos 30 dias troca esta estimativa: o App Gateway sem configuração custa o que o Cost Management diz.
        CustoReal = $true
        Motivo = 'A cobrança do App Gateway depende da camada (v1 pelo tamanho e pelas instâncias; v2 por uma parte fixa mais as unidades de capacidade) e do mínimo de instâncias, e parado ele não cobra: o medidor não é inequívoco.'
    }
}
