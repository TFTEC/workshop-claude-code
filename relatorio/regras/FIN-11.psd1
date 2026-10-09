# Regra FinOps FIN-11 (bônus): recursos sem as tags de custo (CostCenter, Owner, Environment).
# Sem essas tags, o custo do recurso não chega a quem paga a conta: ninguém sabe de quem ele é.
@{
    Id         = 'FIN-11'
    Titulo     = 'Recursos sem as tags de custo (CostCenter, Owner, Environment), por tipo'
    Severidade = 'Baixa'  # Alta, Média ou Baixa

    # Prefixo do "recurso" no modo anonimizado: aqui o recurso do achado é o tipo, então tipo-01, tipo-02...
    Rotulo     = 'tipo'

    # Decisão 1: um achado por TIPO de recurso, e não por recurso. Num ambiente grande, quase todo
    # recurso fica sem alguma tag, e um achado por recurso inundaria o relatório. Cada linha traz o
    # tipo (em name), quantos recursos dele têm problema (recursos), quantos estão sem cada tag e
    # quais tags faltam em pelo menos um deles (tagsQueFaltam).
    #
    # Decisão 2: maiúsculas e minúsculas na chave da tag. Para as operações do Azure, a chave não
    # diferencia maiúsculas ("costcenter" é a mesma tag que "CostCenter"), mas o Azure guarda a
    # grafia de cada recurso, e é essa grafia que aparece no relatório de custo. Na KQL, a busca
    # tags['CostCenter'] diferencia maiúsculas, e por isso a regra não usa essa busca: ela junta
    # as chaves do recurso num texto (chaves) e compara de dois jeitos. contains, que não diferencia
    # maiúsculas, diz se a tag existe com qualquer grafia; sem ela, o recurso conta como sem a tag.
    # contains_cs, que diferencia, separa a tag que existe com outra grafia (outraGrafia): ela não
    # conta como falta, mas aparece à parte, porque divide o relatório de custo em duas tags.
    # Validar no ensaio.
    Kql        = @'
resources
| extend chaves = strcat('|', strcat_array(bag_keys(coalesce(tags, dynamic({}))), '|'), '|')
| extend faltaCostCenter = chaves !contains '|CostCenter|',
         faltaOwner = chaves !contains '|Owner|',
         faltaEnvironment = chaves !contains '|Environment|',
         grafiaDiferente = (chaves contains '|CostCenter|' and chaves !contains_cs '|CostCenter|')
                        or (chaves contains '|Owner|' and chaves !contains_cs '|Owner|')
                        or (chaves contains '|Environment|' and chaves !contains_cs '|Environment|')
| where faltaCostCenter or faltaOwner or faltaEnvironment or grafiaDiferente
| summarize recursos = count(),
            semCostCenter = countif(faltaCostCenter),
            semOwner = countif(faltaOwner),
            semEnvironment = countif(faltaEnvironment),
            outraGrafia = countif(grafiaDiferente)
            by name = tolower(type), subscriptionId
| extend tagsQueFaltam = trim_end(', ', strcat(iff(semCostCenter > 0, 'CostCenter, ', ''), iff(semOwner > 0, 'Owner, ', ''), iff(semEnvironment > 0, 'Environment', '')))
| extend tagsQueFaltam = iff(isempty(tagsQueFaltam), 'nenhuma', tagsQueFaltam)
| order by recursos desc, name asc
'@

    # Como estimar a economia: não há economia a estimar. A regra é informativa.
    Economia   = @{
        Forma  = 'nao-sei'
        Motivo = 'Recurso sem as tags de custo não é desperdício por si só: sem elas, o custo não chega a quem paga a conta, mas o recurso pode estar em uso.'
    }
}
