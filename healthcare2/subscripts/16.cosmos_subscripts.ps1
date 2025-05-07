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
$dataLakeAccountName = "sthealthcare2$concatString"
if($dataLakeAccountName.length -gt 24)
{
$dataLakeAccountName = $dataLakeAccountName.substring(0,24)
}
$cosmos_healthcare2_name = "cosmos-healthcare2-$random$init"
if ($cosmos_healthcare2_name.length -gt 43) {
    $cosmos_healthcare2_name = $cosmos_healthcare2_name.substring(0, 43)
}
$cosmosDatabaseName = "healthcare"

#Cosmos keys
$cosmos_account_key = az cosmosdb keys list -n $cosmos_healthcare2_name -g $rgName | ConvertFrom-Json
$cosmos_account_key = $cosmos_account_key.primarymasterkey


Write-Host  "-----------------Uploading Cosmos Data Started--------------"
#uploading Cosmos data
Add-Content log.txt "-----------------uploading Cosmos data--------------"
RefreshTokens
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-Module -Name PowerShellGet -Force
Install-Module -Name CosmosDB -Force
$cosmosDbAccountName = $cosmos_healthcare2_name
$databaseName = $cosmosDatabaseName
$cosmos = Get-ChildItem "../artifacts/cosmos" | Select BaseName 

foreach($name in $cosmos)
{
    $collection = $name.BaseName 
    $cosmosDbContext = New-CosmosDbContext -Account $cosmosDbAccountName -Database $databaseName -ResourceGroup $rgName
    $path="../artifacts/cosmos/"+$name.BaseName+".json"
    $document=Get-Content -Raw -Path $path
    $document=ConvertFrom-Json $document
    #$newRU=4000
    #az cosmosdb sql container throughput update -a $cosmosDbAccountName -g $rgName -d $databaseName -n $collection --throughput $newRU
    
    foreach($json in $document)
    {
        $key=$json.SyntheticPartitionKey
        $id = New-Guid
        if(![bool]($json.PSobject.Properties.name -eq "id"))
        {$json | Add-Member -MemberType NoteProperty -Name 'id' -Value $id}
        if(![bool]($json.PSobject.Properties.name -eq "SyntheticPartitionKey"))
        {$json | Add-Member -MemberType NoteProperty -Name 'SyntheticPartitionKey' -Value $id}
        $body=ConvertTo-Json $json
        New-CosmosDbDocument -Context $cosmosDbContext -CollectionId $collection -DocumentBody $body -PartitionKey $key
    }
} 
