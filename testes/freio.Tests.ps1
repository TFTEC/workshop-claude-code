#requires -Version 7.0
<#
Testes do hook-freio (seam 2 da spec): o script do hook roda de verdade, recebe pelo stdin
o JSON de PreToolUse que o Claude Code envia, e o teste confere só o comportamento externo:
o exit code (2 bloqueia, 0 deixa passar) e a mensagem em português no stderr.

Nenhum comando do Azure é executado: os testes só entregam strings ao hook.

Rodar: pwsh -NoProfile -Command "Invoke-Pester -Path testes/freio.Tests.ps1 -Output Detailed"
#>

BeforeAll {
    $script:Freio = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../.claude/hooks/freio.ps1'))

    function New-EntradaPreToolUse {
        param([string]$Comando, [string]$Ferramenta = 'Bash')
        [ordered]@{
            session_id      = 'teste'
            transcript_path = 'C:/tmp/transcript.jsonl'
            cwd             = 'C:/Projetos/aluno'
            permission_mode = 'default'
            hook_event_name = 'PreToolUse'
            tool_name       = $Ferramenta
            tool_input      = [ordered]@{ command = $Comando; description = 'teste do freio' }
            tool_use_id     = 'toolu_teste'
        } | ConvertTo-Json -Depth 5 -Compress
    }

    function Invoke-Freio {
        param(
            [string]$Entrada,
            [string]$Executavel = 'pwsh',
            [string[]]$Argumentos = @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $script:Freio)
        )
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        $info = [System.Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $Executavel
        foreach ($arg in $Argumentos) { $info.ArgumentList.Add($arg) }
        $info.UseShellExecute = $false
        $info.RedirectStandardInput = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $info.StandardOutputEncoding = $utf8
        $info.StandardErrorEncoding = $utf8

        $processo = [System.Diagnostics.Process]::Start($info)
        $saida = $processo.StandardOutput.ReadToEndAsync()
        $erro = $processo.StandardError.ReadToEndAsync()
        $bytes = $utf8.GetBytes($Entrada)
        $processo.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
        $processo.StandardInput.Close()
        # Folga para a primeira partida a frio do powershell.exe; o normal é menos de 1 s.
        if (-not $processo.WaitForExit(90000)) {
            $processo.Kill()
            throw "O hook não terminou em 90 s."
        }
        [pscustomobject]@{
            ExitCode = $processo.ExitCode
            Stdout   = $saida.Result
            Stderr   = $erro.Result
        }
    }
}

BeforeDiscovery {
    # Azure CLI: verbos de escrita (e equivalentes óbvios) são bloqueados.
    $script:EscritaAzureCli = @(
        @{ Comando = 'az group create --name rg-novo --location brazilsouth' }
        @{ Comando = 'az vm deallocate --resource-group rg-app --name vm-app-01' }
        @{ Comando = 'az vm stop -g rg-app -n vm-app-01' }
        @{ Comando = 'az vm start -g rg-app -n vm-app-01' }
        @{ Comando = 'az vm restart -g rg-app -n vm-app-01' }
        @{ Comando = 'az vm update -g rg-app -n vm-app-01 --set tags.dono=infra' }
        @{ Comando = 'az role assignment create --assignee fulano@empresa.com --role Reader' }
        @{ Comando = 'az keyvault secret set --vault-name kv-app --name senha --value 123' }
        @{ Comando = 'az keyvault purge --name kv-antigo' }
        @{ Comando = 'az storage blob upload --container-name dados --file a.csv --name a.csv' }
        @{ Comando = 'az storage blob upload-batch --destination dados --source ./saida' }
        @{ Comando = 'az resource tag --tags centro-de-custo=ti --ids /subscriptions/x/resourceGroups/rg-app' }
        @{ Comando = 'az acr import --name acrapp --source docker.io/library/nginx:latest' }
        @{ Comando = 'az webapp deploy --resource-group rg-app --name app-web --src-path app.zip' }
        @{ Comando = 'az vm identity assign -g rg-app -n vm-app-01' }
        @{ Comando = 'az network nsg rule add --nsg-name nsg-app -g rg-app --name libera-rdp' }
        @{ Comando = 'az ad group member remove --group infra --member-id 123' }
        @{ Comando = 'az aks scale -g rg-aks -n aks-app --node-count 5' }
        @{ Comando = 'az resource move --destination-group rg-destino --ids /subscriptions/x/y' }
        @{ Comando = 'az resource invoke-action --action restart --ids /subscriptions/x/y' }
        @{ Comando = 'az vm run-command invoke -g rg-app -n vm-app-01 --command-id RunPowerShellScript --scripts hostname' }
        @{ Comando = 'az vm run-command create -g rg-app --vm-name vm-app-01 --name script' }
        @{ Comando = 'az storage account keys renew -g rg-app -n stapp --key primary' }
        @{ Comando = 'az ad sp create-for-rbac --name sp-automacao' }
        @{ Comando = 'az provider register --namespace Microsoft.Insights' }
        @{ Comando = 'az reservations reservation-order purchase --reservation-order-id 123' }
        @{ Comando = 'az vm open-port -g rg-app -n vm-app-01 --port 3389' }
        @{ Comando = 'az webapp up --name app-web --sku F1' }
        @{ Comando = 'az webapp config appsettings set -g rg-app -n app-web --settings A=1' }
        @{ Comando = 'az webapp log config -g rg-app -n app-web --web-server-logging filesystem' }
        @{ Comando = 'az acr build . --registry acrapp --image app:v1' }
        @{ Comando = 'az disk revoke-access -g rg-app -n disco-01' }
        # As exceções de configuração local são estreitas: estes continuam bloqueados.
        @{ Comando = 'az account alias create --name assinatura-nova --billing-scope /providers/x' }
        @{ Comando = 'az account management-group create --name mg-teste' }
        @{ Comando = 'az account lock create --name trava --lock-type CanNotDelete' }
        @{ Comando = 'az bicep publish --file main.bicep --target br:acrapp.azurecr.io/modulos/rede:v1' }
    )

    # Comandos que só mexem na configuração local do Azure CLI passam (ver README).
    $script:ConfiguracaoLocal = @(
        @{ Comando = 'az account set --subscription 00000000-0000-0000-0000-000000000000' }
        @{ Comando = 'az account clear' }
        @{ Comando = 'az extension add --name resource-graph' }
        @{ Comando = 'az extension list -o table' }
        @{ Comando = 'az extension show --name resource-graph' }
        @{ Comando = 'az extension update --name resource-graph' }
        @{ Comando = 'az extension remove --name costmanagement' }
        @{ Comando = 'az config set core.output=table' }
        @{ Comando = 'az config unset core.output' }
        @{ Comando = 'az configure --defaults group=rg-app' }
        @{ Comando = 'az bicep build --file main.bicep' }
        @{ Comando = 'az bicep install' }
        @{ Comando = 'az bicep upgrade' }
        @{ Comando = 'az upgrade --yes' }
        @{ Comando = 'az aks install-cli' }
        @{ Comando = 'Set-AzContext -Subscription 00000000-0000-0000-0000-000000000000'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Clear-AzContext -Force'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Enable-AzContextAutosave -Scope Process'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Update-AzConfig -DisplayBreakingChangeWarning $false'; Ferramenta = 'PowerShell' }
    )

    # Módulo Az do PowerShell: verbo de escrita + substantivo começando por Az.
    $script:EscritaModuloAz = @(
        @{ Comando = 'Remove-AzResourceGroup -Name rg-app -Force' }
        @{ Comando = 'New-AzVM -ResourceGroupName rg-app -Name vm-nova -Location brazilsouth' }
        @{ Comando = 'Set-AzKeyVaultSecret -VaultName kv-app -Name senha -SecretValue $segredo' }
        @{ Comando = 'Update-AzTag -ResourceId $id -Tag @{centro=''ti''} -Operation Merge' }
        @{ Comando = 'Start-AzVM -ResourceGroupName rg-app -Name vm-app-01' }
        @{ Comando = 'Stop-AzVM -ResourceGroupName rg-app -Name vm-app-01 -Force' }
        @{ Comando = 'Restart-AzWebApp -ResourceGroupName rg-app -Name app-web' }
        @{ Comando = 'Move-AzResource -DestinationResourceGroupName rg-destino -ResourceId $id' }
        @{ Comando = 'Register-AzResourceProvider -ProviderNamespace Microsoft.Insights' }
        @{ Comando = 'Unregister-AzResourceProvider -ProviderNamespace Microsoft.Insights' }
        @{ Comando = 'Import-AzKeyVaultCertificate -VaultName kv-app -Name cert -FilePath cert.pfx' }
        @{ Comando = 'Publish-AzWebApp -ResourceGroupName rg-app -Name app-web -ArchivePath app.zip' }
        @{ Comando = 'Add-AzVhd -ResourceGroupName rg-app -Destination $url -LocalFilePath disco.vhd' }
        @{ Comando = 'Grant-AzDiskAccess -ResourceGroupName rg-app -DiskName disco-01 -Access Read -DurationInSecond 3600' }
        @{ Comando = 'Revoke-AzDiskAccess -ResourceGroupName rg-app -DiskName disco-01' }
        @{ Comando = 'Enable-AzActivityLogAlert -ResourceGroupName rg-app -Name alerta' }
        @{ Comando = 'Disable-AzActivityLogAlert -ResourceGroupName rg-app -Name alerta' }
        @{ Comando = 'Suspend-AzSynapseSqlPool -WorkspaceName ws -Name pool' }
        @{ Comando = 'Resume-AzSynapseSqlPool -WorkspaceName ws -Name pool' }
        @{ Comando = 'Invoke-AzVMRunCommand -ResourceGroupName rg-app -VMName vm-app-01 -CommandId RunPowerShellScript -ScriptPath x.ps1' }
        @{ Comando = 'Restore-AzKeyVaultSecret -VaultName kv-app -InputFile segredo.blob' }
        @{ Comando = 'New-AzRoleAssignment -SignInName fulano@empresa.com -RoleDefinitionName Reader' }
        @{ Comando = 'Az.Resources\Remove-AzResourceGroup -Name rg-app' }
        @{ Comando = 'remove-azresourcegroup -name rg-app' }
        @{ Comando = 'Remove-AzureRmResourceGroup -Name rg-app' }
        @{ Comando = '$rg = New-AzResourceGroup -Name rg-novo -Location brazilsouth' }
    )

    # Terraform: apply, destroy e import alteram o ambiente.
    $script:EscritaTerraform = @(
        @{ Comando = 'terraform apply'; Trecho = 'terraform apply' }
        @{ Comando = 'terraform apply -auto-approve plan.tfplan'; Trecho = 'terraform apply -auto-approve plan.tfplan' }
        @{ Comando = 'terraform destroy -auto-approve'; Trecho = 'terraform destroy -auto-approve' }
        @{ Comando = 'terraform import azurerm_resource_group.rg /subscriptions/x/resourceGroups/rg-app'; Trecho = 'terraform import azurerm_resource_group.rg /subscriptions/x/resourceGroups/rg-app' }
        @{ Comando = 'terraform -chdir=infra apply'; Trecho = 'terraform -chdir=infra apply' }
        @{ Comando = 'cd infra && terraform apply'; Trecho = 'terraform apply' }
        @{ Comando = 'TERRAFORM APPLY'; Trecho = 'TERRAFORM APPLY' }
        @{ Comando = 'terraform.exe destroy'; Trecho = 'terraform.exe destroy'; Ferramenta = 'PowerShell' }
    )

    # az deployment em qualquer forma, e az rest com método diferente de GET.
    $script:EscritaDeploymentERest = @(
        @{ Comando = 'az deployment group create -g rg-app --template-file main.bicep' }
        @{ Comando = 'az deployment sub what-if --location brazilsouth --template-file main.bicep' }
        @{ Comando = 'az deployment group list -g rg-app' }
        @{ Comando = 'az group deployment create -g rg-app --template-file azuredeploy.json' }
        @{ Comando = 'az webapp deployment source config-zip -g rg-app -n app-web --src app.zip' }
        @{ Comando = 'az rest --method put --url https://management.azure.com/subscriptions/x/resourceGroups/rg-app?api-version=2021-04-01 --body @rg.json' }
        @{ Comando = 'az rest -m delete -u /subscriptions/x/resourceGroups/rg-app?api-version=2021-04-01' }
        @{ Comando = 'az rest --method=patch --uri https://graph.microsoft.com/v1.0/users/x --body ''{"displayName":"y"}''' }
        @{ Comando = 'az rest --url "https://management.azure.com/subscriptions/x/resourcegroups/rg-app?api-version=2021-04-01&a=1" --method PUT' }
        @{ Comando = 'az rest --method head --url https://management.azure.com/subscriptions/x?api-version=2022-12-01' }
        @{ Comando = 'az rest --method post --url https://management.azure.com/subscriptions/x/providers/Microsoft.CostManagement/exports/e1/run?api-version=2023-03-01' }
        @{ Comando = 'az rest --method put --url https://management.azure.com/subscriptions/x/providers/Microsoft.CostManagement/query?api-version=2023-03-01' }
    )

    # Comandos compostos: cada parte é avaliada. Trecho = a parte que a mensagem deve citar.
    $script:EscritaEmComposto = @(
        @{ Comando = 'cd infra && az group delete -n rg-app --yes'; Trecho = 'az group delete -n rg-app --yes' }
        @{ Comando = 'az group show -n rg-app || az group create -n rg-app -l brazilsouth'; Trecho = 'az group create -n rg-app -l brazilsouth' }
        @{ Comando = 'echo inicio; az vm deallocate -g rg-app -n vm-app-01'; Trecho = 'az vm deallocate -g rg-app -n vm-app-01' }
        @{ Comando = 'az vm list --query "[].id" -o tsv | xargs -n1 az vm stop --ids'; Trecho = 'xargs -n1 az vm stop --ids' }
        @{ Comando = "az account show`naz group delete -n rg-app --yes"; Trecho = 'az group delete -n rg-app --yes' }
        @{ Comando = "az account show`r`naz vm stop -g rg-app -n vm-app-01"; Trecho = 'az vm stop -g rg-app -n vm-app-01' }
        @{ Comando = 'az vm deallocate --ids $(az vm list -g rg-app --query "[].id" -o tsv)'; Trecho = 'az vm deallocate --ids' }
        @{ Comando = "az vm \`n  deallocate -g rg-app -n vm-app-01"; Trecho = 'az vm deallocate -g rg-app -n vm-app-01' }
        @{ Comando = "az vm ```n  stop -g rg-app -n vm-app-01"; Trecho = 'az vm stop -g rg-app -n vm-app-01'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Get-Date; az group delete -n rg-app --yes'; Trecho = 'az group delete -n rg-app --yes'; Ferramenta = 'PowerShell' }
        @{ Comando = '& az group delete -n rg-app --yes'; Trecho = 'az group delete -n rg-app --yes'; Ferramenta = 'PowerShell' }
        @{ Comando = '$vms | ForEach-Object { az vm stop --ids $_.id }'; Trecho = 'az vm stop --ids $_.id'; Ferramenta = 'PowerShell' }
        @{ Comando = '$vms | % {az vm stop --ids $_.id}'; Trecho = 'az vm stop --ids $_.id'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Get-AzVM -Status | Where-Object PowerState -eq ''VM running'' | Stop-AzVM -Force'; Trecho = 'Stop-AzVM -Force'; Ferramenta = 'PowerShell' }
        @{ Comando = 'AZ GROUP DELETE -n rg-app --yes'; Trecho = 'AZ GROUP DELETE -n rg-app --yes' }
        @{ Comando = 'Az Vm Deallocate -g rg-app -n vm-app-01'; Trecho = 'Az Vm Deallocate -g rg-app -n vm-app-01' }
        @{ Comando = 'az group DELETE -n rg-app'; Trecho = 'az group DELETE -n rg-app' }
    )

    # Comando escondido dentro de aspas, de outro shell ou com o caminho completo do az.
    $script:EscritaEscondida = @(
        @{ Comando = 'bash -c "az group delete -n rg-app --yes"'; Trecho = 'az group delete -n rg-app --yes' }
        @{ Comando = 'pwsh -NoProfile -Command "az vm stop -g rg-app -n vm-app-01"'; Trecho = 'az vm stop -g rg-app -n vm-app-01'; Ferramenta = 'PowerShell' }
        @{ Comando = 'cmd /c "az vm deallocate -g rg-app -n vm-app-01"'; Trecho = 'az vm deallocate -g rg-app -n vm-app-01' }
        @{ Comando = 'bash -c "pwsh -c ''az group delete -n rg-app --yes''"'; Trecho = 'az group delete -n rg-app --yes' }
        @{ Comando = 'Invoke-Expression ''az group delete -n rg-app --yes'''; Trecho = 'az group delete -n rg-app --yes'; Ferramenta = 'PowerShell' }
        @{ Comando = 'echo "$(az group delete -n rg-app --yes)"'; Trecho = 'az group delete -n rg-app --yes' }
        @{ Comando = 'echo don''t; az group delete -n rg-app --yes'; Trecho = 'az group delete -n rg-app --yes' }
        @{ Comando = '& "C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd" group delete -n rg-app --yes'; Trecho = '"C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd" group delete -n rg-app --yes'; Ferramenta = 'PowerShell' }
        @{ Comando = '/usr/local/bin/az vm stop -g rg-app -n vm-app-01'; Trecho = '/usr/local/bin/az vm stop -g rg-app -n vm-app-01' }
    )

    # Leitura do Azure e comandos que não são do Azure passam.
    $script:LeituraEOutros = @(
        @{ Comando = 'az group list -o table' }
        @{ Comando = 'az vm show --resource-group rg-app --name vm-app-01' }
        @{ Comando = 'az vm list -d --query "[].{nome:name, estado:powerState}" -o table' }
        @{ Comando = 'az graph query -q "Resources | summarize count()" --subscriptions 00000000-0000-0000-0000-000000000000' }
        @{ Comando = 'az account show' }
        @{ Comando = 'az account list -o table' }
        @{ Comando = 'az disk list --query "[?diskState==''Unattached'']"' }
        @{ Comando = 'az vm run-command list --location brazilsouth' }
        @{ Comando = 'az tag list' }
        @{ Comando = 'az lock list --resource-group rg-app' }
        @{ Comando = 'az vm list-sizes --location brazilsouth' }
        @{ Comando = 'az advisor recommendation list --category Cost' }
        @{ Comando = 'az monitor log-analytics workspace show -g rg-log -n log-app' }
        @{ Comando = 'az login' }
        @{ Comando = 'az logout' }
        @{ Comando = 'az --version' }
        @{ Comando = 'az rest --method get --url https://management.azure.com/subscriptions/x/resourceGroups?api-version=2021-04-01' }
        @{ Comando = 'az rest --url /subscriptions/{subscriptionId}/resources?api-version=2021-04-01 --url-parameters $top=3' }
        @{ Comando = 'az rest -m GET -u https://graph.microsoft.com/v1.0/me' }
        @{ Comando = 'az rest --method post --url "https://management.azure.com/subscriptions/x/providers/Microsoft.CostManagement/query?api-version=2023-03-01" --body ''{"type":"ActualCost","timeframe":"MonthToDate","dataset":{"granularity":"None","aggregation":{"totalCost":{"name":"Cost","function":"Sum"}}}}''' }
        @{ Comando = 'az rest --method POST --uri /subscriptions/{subscriptionId}/resourceGroups/rg-app/providers/Microsoft.CostManagement/query?api-version=2023-03-01 --body @consulta.json' }
        @{ Comando = 'git status' }
        @{ Comando = 'git log --oneline -5' }
        @{ Comando = 'git commit -m "feat: adiciona regra de discos órfãos"' }
        @{ Comando = 'ls -la' }
        @{ Comando = 'npm test' }
        @{ Comando = 'cat README.md | grep az' }
        @{ Comando = 'Get-ChildItem -Recurse -Filter *.ps1'; Ferramenta = 'PowerShell' }
        @{ Comando = 'pwsh -NoProfile -File ./relatorio.ps1 -Fonte Arquivo -Anonimizado'; Ferramenta = 'PowerShell' }
        @{ Comando = 'az group list && az vm list -o table' }
        @{ Comando = 'az vm list && git push origin main' }
        @{ Comando = 'az account show; git tag v1.0' }
        @{ Comando = 'git status; git log --oneline -3' }
        @{ Comando = "az account show`naz graph query -q `"Resources | summarize count()`"" }
        @{ Comando = 'az graph query -q "Resources | where type =~ ''microsoft.compute/disks'' | summarize count()"' }
        @{ Comando = 'AZ ACCOUNT SHOW' }
        @{ Comando = 'Az Group List -o table'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Get-AzVM -Status'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Get-AzResource | Select-Object Name, ResourceType'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Search-AzGraph -Query ''Resources | summarize count()'''; Ferramenta = 'PowerShell' }
        @{ Comando = 'Connect-AzAccount'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Disconnect-AzAccount'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Select-AzSubscription -SubscriptionId 00000000-0000-0000-0000-000000000000'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Import-Module Az.Accounts'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Install-Module Az -Scope CurrentUser'; Ferramenta = 'PowerShell' }
        @{ Comando = 'New-Item -ItemType Directory -Path saida'; Ferramenta = 'PowerShell' }
        @{ Comando = 'Remove-Item ./saida -Recurse -Force'; Ferramenta = 'PowerShell' }
        @{ Comando = 'terraform init' }
        @{ Comando = 'terraform plan -out plan.tfplan' }
        @{ Comando = 'terraform plan -destroy' }
        @{ Comando = 'terraform validate' }
        @{ Comando = 'terraform fmt -recursive' }
        @{ Comando = 'terraform state list' }
        @{ Comando = 'terraform output -json' }
        @{ Comando = 'bash -c "az group list -o table"' }
        @{ Comando = 'pwsh -NoProfile -Command "az account show --query id -o tsv"'; Ferramenta = 'PowerShell' }
    )
}

Describe 'Hook-freio' {
    Context 'Azure CLI com verbo de escrita' {
        It 'bloqueia: <Comando>' -ForEach $EscritaAzureCli {
            $r = Invoke-Freio (New-EntradaPreToolUse $Comando)
            $r.ExitCode | Should -Be 2
            $r.Stderr | Should -BeLike 'Hook-freio: comando de escrita no Azure bloqueado: *'
            $r.Stderr | Should -Match ([regex]::Escape($Comando))
            $r.Stderr | Should -BeLike '*O workshop só lê o Azure.*'
        }
    }

    Context 'Cmdlets de escrita do módulo Az' {
        It 'bloqueia: <Comando>' -ForEach $EscritaModuloAz {
            $r = Invoke-Freio (New-EntradaPreToolUse $Comando 'PowerShell')
            $r.ExitCode | Should -Be 2
            $r.Stderr | Should -Match ('^' + [regex]::Escape("Hook-freio: comando de escrita no Azure bloqueado: $Comando. "))
        }
    }

    Context 'Terraform' {
        It 'bloqueia: <Comando>' -ForEach $EscritaTerraform {
            $ferramenta = if ($Ferramenta) { $Ferramenta } else { 'Bash' }
            $r = Invoke-Freio (New-EntradaPreToolUse $Comando $ferramenta)
            $r.ExitCode | Should -Be 2
            $r.Stderr | Should -Match ('^' + [regex]::Escape("Hook-freio: comando de escrita no Azure bloqueado: $Trecho. "))
        }
    }

    Context 'az deployment e az rest de escrita' {
        It 'bloqueia: <Comando>' -ForEach $EscritaDeploymentERest {
            $r = Invoke-Freio (New-EntradaPreToolUse $Comando)
            $r.ExitCode | Should -Be 2
            $r.Stderr | Should -Match ('^' + [regex]::Escape("Hook-freio: comando de escrita no Azure bloqueado: $Comando. "))
        }
    }

    Context 'Comando composto e maiúsculas' {
        It 'bloqueia: <Comando>' -ForEach $EscritaEmComposto {
            $ferramenta = if ($Ferramenta) { $Ferramenta } else { 'Bash' }
            $r = Invoke-Freio (New-EntradaPreToolUse $Comando $ferramenta)
            $r.ExitCode | Should -Be 2
            $r.Stderr | Should -Match ('^' + [regex]::Escape("Hook-freio: comando de escrita no Azure bloqueado: $Trecho. "))
        }
    }

    Context 'Comando escondido em aspas, em outro shell ou com caminho completo' {
        It 'bloqueia: <Comando>' -ForEach $EscritaEscondida {
            $ferramenta = if ($Ferramenta) { $Ferramenta } else { 'Bash' }
            $r = Invoke-Freio (New-EntradaPreToolUse $Comando $ferramenta)
            $r.ExitCode | Should -Be 2
            $r.Stderr | Should -Match ('^' + [regex]::Escape("Hook-freio: comando de escrita no Azure bloqueado: $Trecho. "))
        }
    }

    Context 'Configuração local do Azure CLI' {
        It 'deixa passar: <Comando>' -ForEach $ConfiguracaoLocal {
            $ferramenta = if ($Ferramenta) { $Ferramenta } else { 'Bash' }
            $r = Invoke-Freio (New-EntradaPreToolUse $Comando $ferramenta)
            $r.ExitCode | Should -Be 0
            $r.Stderr | Should -BeNullOrEmpty
        }
    }

    Context 'Ferramenta Monitor (também roda comando de shell)' {
        It 'bloqueia escrita no Azure vinda do Monitor' {
            $r = Invoke-Freio (New-EntradaPreToolUse 'az vm stop -g rg-app -n vm-app-01' 'Monitor')
            $r.ExitCode | Should -Be 2
            $r.Stderr | Should -BeLike 'Hook-freio: comando de escrita no Azure bloqueado: az vm stop -g rg-app -n vm-app-01. *'
        }
    }

    Context 'Entrada com BOM UTF-8' {
        It 'continua bloqueando quando o JSON chega com BOM' {
            $r = Invoke-Freio ([string][char]0xFEFF + (New-EntradaPreToolUse 'az group delete -n rg-app --yes'))
            $r.ExitCode | Should -Be 2
        }
    }

    Context 'Entrada inválida ou de outra ferramenta' {
        It 'deixa passar sem quebrar a sessão: <Nome>' -ForEach @(
            @{ Nome = 'JSON inválido'; Entrada = 'isto não é json' }
            @{ Nome = 'entrada vazia'; Entrada = '' }
            @{ Nome = 'JSON que não é objeto'; Entrada = '[1,2,3]' }
            @{ Nome = 'JSON null'; Entrada = 'null' }
            @{ Nome = 'sem tool_input'; Entrada = '{"hook_event_name":"PreToolUse","tool_name":"Bash"}' }
            @{ Nome = 'sem command'; Entrada = '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{}}' }
            @{ Nome = 'command nulo'; Entrada = '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":null}}' }
            @{ Nome = 'Write com texto de escrita no Azure'; Entrada = '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"C:/aluno/notas.md","content":"az group delete -n rg-app"}}' }
            @{ Nome = 'ferramenta que não é de shell, mesmo com campo command'; Entrada = '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"command":"az group delete -n rg-app"}}' }
        ) {
            $r = Invoke-Freio $Entrada
            $r.ExitCode | Should -Be 0
            $r.Stderr | Should -BeNullOrEmpty
        }
    }

    Context 'Registro em .claude/settings.json' {
        It 'a linha registrada roda o freio e bloqueia escrita no Azure' {
            $raiz = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
            $config = Get-Content (Join-Path $raiz '.claude/settings.json') -Raw | ConvertFrom-Json
            $hook = $config.hooks.PreToolUse[0].hooks[0]
            # O Claude Code troca ${CLAUDE_PROJECT_DIR} pela raiz do projeto em command e em args.
            $argumentos = @($hook.args | ForEach-Object { $_.Replace('${CLAUDE_PROJECT_DIR}', $raiz) })
            $r = Invoke-Freio (New-EntradaPreToolUse 'az group delete -n rg-app --yes' 'PowerShell') -Executavel $hook.command -Argumentos $argumentos
            $r.ExitCode | Should -Be 2
            $r.Stderr | Should -BeLike 'Hook-freio: comando de escrita no Azure bloqueado: az group delete -n rg-app --yes. *'
        }
    }

    Context 'Windows PowerShell 5.1' -Skip:(-not $IsWindows) {
        It 'bloqueia no 5.1 com a mensagem acentuada: <Comando>' -ForEach @(
            @{ Comando = 'cd infra && az group delete -n rg-app --yes'; Trecho = 'az group delete -n rg-app --yes' }
            @{ Comando = 'Get-AzVM | Stop-AzVM -Force'; Trecho = 'Stop-AzVM -Force' }
            @{ Comando = 'terraform -chdir=infra destroy'; Trecho = 'terraform -chdir=infra destroy' }
        ) {
            $r = Invoke-Freio (New-EntradaPreToolUse $Comando 'PowerShell') -Executavel 'powershell.exe'
            $r.ExitCode | Should -Be 2
            $r.Stderr | Should -Be "Hook-freio: comando de escrita no Azure bloqueado: $Trecho. O workshop só lê o Azure.`n"
        }

        It 'deixa passar no 5.1: <Nome>' -ForEach @(
            @{ Nome = 'leitura'; Entrada = '{"tool_name":"Bash","tool_input":{"command":"az graph query -q \"Resources | summarize count()\""}}' }
            @{ Nome = 'JSON inválido'; Entrada = 'isto não é json' }
        ) {
            $r = Invoke-Freio $Entrada -Executavel 'powershell.exe'
            $r.ExitCode | Should -Be 0
            $r.Stderr | Should -BeNullOrEmpty
        }
    }

    Context 'Leitura do Azure e comandos fora do Azure' {
        It 'deixa passar: <Comando>' -ForEach $LeituraEOutros {
            $ferramenta = if ($Ferramenta) { $Ferramenta } else { 'Bash' }
            $r = Invoke-Freio (New-EntradaPreToolUse $Comando $ferramenta)
            $r.ExitCode | Should -Be 0
            $r.Stderr | Should -BeNullOrEmpty
        }
    }
}
