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

#Creating Datasets
    Add-Content log.txt "------datasets------"
    Write-Host "--------Datasets--------"
    RefreshTokens
    $DatasetsPath = "../artifacts/dataset";	
    $datasets = Get-ChildItem "../artifacts/dataset" | Select BaseName
    foreach ($dataset in $datasets) {
        Write-Host "Creating dataset : $($dataset.BaseName)"
        $itemTemplate = Get-Content -Path "$($DatasetsPath)/$($dataset.BaseName).json"
        $item = $itemTemplate
        $uri = "https://$($synapseWorkspaceName).dev.azuresynapse.net/datasets/$($dataset.BaseName)?api-version=2019-06-01-preview"
        $result = Invoke-RestMethod  -Uri $uri -Method PUT -Body $item -Headers @{ Authorization = "Bearer $synapseToken" } -ContentType "application/json"
        Add-Content log.txt $result
    }
 