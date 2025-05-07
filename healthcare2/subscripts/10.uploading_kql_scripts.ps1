function RefreshTokens() {
    #Copy external blob content
    $global:powerbitoken = ((az account get-access-token --resource https://analysis.windows.net/powerbi/api) | ConvertFrom-Json).accessToken
    $global:synapseToken = ((az account get-access-token --resource https://dev.azuresynapse.net) | ConvertFrom-Json).accessToken
    $global:graphToken = ((az account get-access-token --resource https://graph.microsoft.com) | ConvertFrom-Json).accessToken
    $global:managementToken = ((az account get-access-token --resource https://management.azure.com) | ConvertFrom-Json).accessToken
    $global:purviewToken = ((az account get-access-token --resource https://purview.azure.net) | ConvertFrom-Json).accessToken
}

az login

#for powershell...
$subscriptionId = (az account show --query id --output tsv)
Connect-AzAccount -UseDeviceAuthentication -Subscription $subscriptionId 


$rgName = read-host "Enter the resource Group Name";
$init =  (Get-AzResourceGroup -Name $rgName).Tags["DeploymentId"]
$random =  (Get-AzResourceGroup -Name $rgName).Tags["UniqueId"] 
$concatString = "$init$random"
$synapseWorkspaceName = "synhealthcare2$concatString"

#uploading Sql Scripts
Add-Content log.txt "-----------uploading KQL Scripts-----------------"
Write-Host "----KQL Scripts------"
RefreshTokens
$scripts = Get-ChildItem "../artifacts/kqlscripts" | Select BaseName

foreach ($name in $scripts) {
    $ScriptFileName = "../artifacts/kqlscripts/" + $name.BaseName + ".kql"
    Write-Host "Uploading Kql Script : $($name.BaseName)"
    New-AzSynapseKqlScript -WorkspaceName $synapseWorkspaceName -DefinitionFile $ScriptFileName
}
