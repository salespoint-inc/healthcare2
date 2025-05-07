function RefreshTokens() {
    #Copy external blob content
    $global:powerbitoken = ((az account get-access-token --resource https://analysis.windows.net/powerbi/api) | ConvertFrom-Json).accessToken
    $global:synapseToken = ((az account get-access-token --resource https://dev.azuresynapse.net) | ConvertFrom-Json).accessToken
    $global:graphToken = ((az account get-access-token --resource https://graph.microsoft.com) | ConvertFrom-Json).accessToken
    $global:managementToken = ((az account get-access-token --resource https://management.azure.com) | ConvertFrom-Json).accessToken
    $global:purviewToken = ((az account get-access-token --resource https://purview.azure.net) | ConvertFrom-Json).accessToken
}

function ReplaceTokensInFile($ht, $filePath) {
    $template = Get-Content -Raw -Path $filePath
    
    foreach ($paramName in $ht.Keys) {
        $template = $template.Replace($paramName, $ht[$paramName])
    }

    return $template;
}

az login

#for powershell...
$subscriptionId = (az account show --query id --output tsv)
Connect-AzAccount -UseDeviceAuthentication -Subscription $subscriptionId 


$rgName = read-host "Enter the resource Group Name";
$Region = (Get-AzResourceGroup -Name $rgName).Location
$init =  (Get-AzResourceGroup -Name $rgName).Tags["DeploymentId"]
$random =  (Get-AzResourceGroup -Name $rgName).Tags["UniqueId"] 
$wsId =  (Get-AzResourceGroup -Name $rgName).Tags["WsId"] 
$suffix = "$random-$init"
$concatString = "$init$random"
$synapseWorkspaceName = "synhealthcare2$concatString"
$dataLakeAccountName = "sthealthcare2$concatString"
if($dataLakeAccountName.length -gt 24)
{
$dataLakeAccountName = $dataLakeAccountName.substring(0,24)
}
$amlworkspacename = "aml-hc2-$suffix"
$namespaces_evh_patient_monitoring_name = "evh-patient-monitoring-hc2-$suffix"
$sites_patient_data_simulator_name = "app-patient-data-simulator-$suffix"
$sites_clinical_notes_name = "app-clinical-notes-$suffix"
$sites_doc_search_name = "app-health-search-$suffix"
$sites_open_ai_name = "app-open-ai-$suffix"
$app_healthcare2_name = "app-healthcare2-$suffix"
$streamingjobs_deltadata_asa_name = "asa-hc2-deltadata-$suffix"
$cosmos_healthcare2_name = "cosmos-healthcare2-$random$init"
if ($cosmos_healthcare2_name.length -gt 43) {
    $cosmos_healthcare2_name = $cosmos_healthcare2_name.substring(0, 43)
}
$cognitive_service_name = "cog-healthcare2-$suffix"
$keyVaultName = "kv-hc2-$concatString"
if($keyVaultName.length -gt 24)
{
$keyVaultName = $keyVaultName.substring(0,24)
}
$func_payor_storage_name = "stfuncgeneratorhc2$concatString"
if($func_payor_storage_name.length -gt 24)
{
$func_payor_storage_name = $func_payor_storage_name.substring(0,24)
}
$func_payor_generator_name = "func-payor-generator-hc2-$suffix"
4
$subscriptionId = (Get-AzContext).Subscription.Id
$tenantId = (Get-AzContext).Tenant.Id
$openAIResource = "openAIservicehc2$concatString"
if($openAIResource.length -gt 24)
{
$openAIResource = $openAIResource.substring(0,24)
}

#retrieving openai endpoint
$openAIEndpoint = az cognitiveservices account show -n $openAIResource -g $rgName | jq -r .properties.endpoint

#retirieving primary key
$openAIPrimaryKey = az cognitiveservices account keys list -n $openAIResource -g $rgName | jq -r .key1

#Web App Section
Add-Content log.txt "------unzipping poc web app------"
Write-Host  "--------------Unzipping web app---------------"
$zips = @("func-realtime-payor-generator-hc2", "healthcare2-demo-app", "app-clinical-notes", "app-open-ai")
foreach ($zip in $zips) {
    expand-archive -path "../artifacts/binaries/$($zip).zip" -destinationpath "./$($zip)" -force
}

#Web app
Add-Content log.txt "------deploy poc web app------"
Write-Host  "-----------------Deploy web app---------------"
RefreshTokens

$spname = "Healthcare2 Demo $init"

    $app = az ad app create --display-name $spname | ConvertFrom-Json
    $appId = $app.appId

    $mainAppCredential = az ad app credential reset --id $appId | ConvertFrom-Json
    $clientsecpwd = $mainAppCredential.password

    az ad sp create --id $appId | Out-Null    
    $sp = az ad sp show --id $appId --query "id" -o tsv

    #retrieving cognitive service endpoint
    $cognitiveEndpoint = az cognitiveservices account show -n $cognitive_service_name -g $rgName | jq -r .properties.endpoint

    #retirieving cognitive service key
    $cognitivePrimaryKey = az cognitiveservices account keys list -n $cognitive_service_name -g $rgName | jq -r .key1

(Get-Content -path ../healthcare2-demo-app/appsettings.json -Raw) | Foreach-Object { $_ `
            -replace '#WORKSPACE_ID#', $wsId`
            -replace '#APP_ID#', $appId`
            -replace '#APP_SECRET#', $clientsecpwd`
            -replace '#TENANT_ID#', $tenantId`
            -replace '#REGION#', $Region`
            -replace '#COGNITIVE_SERVICE_ENDPOINT#', $cognitiveEndpoint`
            -replace '#COGNITIVE_KEY#', $cognitivePrimaryKey`
    } | Set-Content -Path ../healthcare2-demo-app/appsettings.json

    $filepath = "../healthcare2-demo-app/wwwroot/config-poc.js"
    $itemTemplate = Get-Content -Path $filepath
    $item = $itemTemplate.Replace("#STORAGE_ACCOUNT#", $dataLakeAccountName).Replace("#SERVER_NAME#", $app_healthcare2_name).Replace("#APP_CRITICAL_NOTES#", $sites_clinical_notes_name).Replace("#APP_OPEN_AI#", $sites_open_ai_name).Replace("#SUBSCRIPTION_ID#", $subscriptionId).Replace("#RESOURCE_GROUP_NAME#", $rgName).Replace("#ML_WORKSPACE_NAME#", $amlworkspacename).Replace("#TENANT_ID#", $tenantId).Replace("#SYNAPSE_NAME#", $synapseWorkspaceName).Replace("#INCEDENT_CHATBOT_SERVER_NAME#", $func_copilot).Replace("#FORM_RECO_CHATBOT_SERVER_NAME#", $func_copilot).Replace("#SEARCH_API_SERVER_NAME#", $searchName).Replace("#SEARCH_API_KEY#", $primaryAdminKey)
    Set-Content -Path $filepath -Value $item

    RefreshTokens
    $url = "https://api.powerbi.com/v1.0/myorg/groups/$wsId/reports";
    $reportList = Invoke-RestMethod -Uri $url -Method GET -Headers @{ Authorization = "Bearer $powerbitoken" };
    $reportList = $reportList.Value

    #update all th report ids in the poc web app...
    $ht = new-object system.collections.hashtable   
    # $ht.add("#Bing_Map_Key#", "AhBNZSn-fKVSNUE5xYFbW_qajVAZwWYc8OoSHlH8nmchGuDI6ykzYjrtbwuNSrR8")
    $ht.add("#Healthcare Global overview tiles#", $($reportList | where { $_.name -eq "Healthcare Global overview tiles" }).id)
    $ht.add("#Healthcare - US Map#", $($reportList | where { $_.name -eq "Healthcare - US Map" }).id)
    $ht.add("#Healthcare - Patients Profile report#", $($reportList | where { $_.name -eq "Healthcare - Patients Profile report" }).id)
    $ht.add("#Healthcare - Call Center Power BI-After#", $($reportList | where { $_.name -eq "Healthcare - Call Center Power BI-After" }).id)
    $ht.add("#Healthcare - Bed Occupancy & Availability Report#", $($reportList | where { $_.name -eq "Healthcare - Bed Occupancy " }).id)
    $ht.add("#Healthcare - HTAP-Lab-Data#", $($reportList | where { $_.name -eq "Healthcare - HTAP-Lab-Data" }).id)
    $ht.add("#Healthcare Consolidated Report#", $($reportList | where { $_.name -eq "Healthcare Consolidated Report" }).id)
    $ht.add("#Healthcare FHIR#", $($reportList | where { $_.name -eq "Healthcare FHIR" }).id)
    $ht.add("#Healthcare - Call Center Power BI Before#", $($reportList | where { $_.name -eq "Healthcare - Call Center Power BI Before" }).id)
    $ht.add("#Healthcare Miami Hospital Overview#", $($reportList | where { $_.name -eq "Healthcare Miami Hospital Overview" }).id)
    $ht.add("#Healthcare Patient Overview#", $($reportList | where { $_.name -eq "Healthcare Patient Overview" }).id)
    $ht.add("#Healthcare Global Occupational Safety Report#", $($reportList | where { $_.name -eq "Healthcare Global Occupational Safety Report" }).id)
    
    $filePath = "../healthcare2-demo-app/wwwroot/config-poc.js";
    Set-Content $filePath $(ReplaceTokensInFile $ht $filePath)

    Compress-Archive -Path "../healthcare2-demo-app/*" -DestinationPath "../healthcare2-demo-app.zip" -Update

    # az webapp stop --name $app_healthcare2_name --resource-group $rgName
    # try {
    #     az webapp deployment source config-zip --resource-group $rgName --name $app_healthcare2_name --src "./healthcare2-demo-app.zip"
    # }
    # catch {
    # }

    $TOKEN_1 = az account get-access-token --query accessToken | tr -d '"'

    $deployment = curl -X POST -H "Authorization: Bearer $TOKEN_1" -T "../healthcare2-demo-app.zip" "https://$app_healthcare2_name.scm.azurewebsites.net/api/publish?type=zip"
    
    az webapp start --name $app_healthcare2_name --resource-group $rgName


Add-Content log.txt "-----Simulator apps zip deploy-------"
    Write-Host "----Simulator apps zip deploy------"

    # ADX Thermostat Realtime
    az webapp stop --name $sites_patient_data_simulator_name --resource-group $rgName

    $operational_analytics_endpoint = az eventhubs eventhub authorization-rule keys list --resource-group $rgName --namespace-name $namespaces_evh_patient_monitoring_name --eventhub-name "operational-analytics" --name "operational" | ConvertFrom-Json
    $operational_analytics_endpoint = $operational_analytics_endpoint.primaryConnectionString
    $monitoring_device_endpoint = az eventhubs eventhub authorization-rule keys list --resource-group $rgName --namespace-name $namespaces_evh_patient_monitoring_name --eventhub-name "monitoring-device" --name "device" | ConvertFrom-Json
    $monitoring_device_endpoint = $monitoring_device_endpoint.primaryConnectionString

    (Get-Content -path ../adx-config-appsetting.json -Raw) | Foreach-Object { $_ `
            -replace '#NAMESPACE_EVH_OPERATIONAL_ANALYTICS_ENDPOINT#', $operational_analytics_endpoint`
            -replace '#NAMESPACE_EVH_MONITORING_DEVICE_ENDPOINT#', $monitoring_device_endpoint`
            -replace '#STREAMING_DATASET_URL#', $streaming_dataset_url`
    } | Set-Content -Path ../adx-config-appsetting-with-replacement.json

    $config = az webapp config appsettings set -g $rgName -n $sites_patient_data_simulator_name --settings @adx-config-appsetting-with-replacement.json

    Write-Information "Deploying Patient Data Simulator App"
    # cd app-adx-thermostat-realtime
    # az webapp up --resource-group $rgName --name $sites_patient_data_simulator_name --plan $serverfarm_patient_data_simulator_name --location $Region
    # cd ..
    $TOKEN_2 = az account get-access-token --query accessToken | tr -d '"'

    $deployment = curl -X POST -H "Authorization: Bearer $TOKEN_2" -T "../artifacts/binaries/app-adx-thermostat-realtime.zip" "https://$sites_patient_data_simulator_name.scm.azurewebsites.net/api/publish?type=zip"

    Start-Sleep -s 10
    # Publish-AzWebApp -ResourceGroupName $rgName -Name $sites_patient_data_simulator_name -ArchivePath ./artifacts/binaries/app-adx-thermostat-realtime.zip -Force

    az webapp start --name $sites_patient_data_simulator_name --resource-group $rgName

    # Function App Cosmos
    $payorRealtimePrimaryKey = az eventhubs eventhub authorization-rule keys list --resource-group $rgName --namespace-name $namespaces_evh_patient_monitoring_name --eventhub-name "payor-realtime-data" --name "realtime" | ConvertFrom-Json
    $payorRealtimePrimaryKey = $payorRealtimePrimaryKey.primaryKey

   (Get-Content -path ../func-realtime-payor-generator-hc2/TimerTrigger1/run.ps1 -Raw) | Foreach-Object { $_ `
            -replace '#NAMESPACE_THERMOSTAT_OCCUPANCY#', $namespaces_evh_patient_monitoring_name`
            -replace '#EVENTHUB_ACCESS_POLICY_KEY#', $payorRealtimePrimaryKey`
    } | Set-Content -Path ../func-realtime-payor-generator-hc2/TimerTrigger1/run.ps1
    
    $func_payor_storage_key = (Get-AzStorageAccountKey -ResourceGroupName $rgName -AccountName $func_payor_storage_name)[0].Value
    $webjobs = "DefaultEndpointsProtocol=https;AccountName=" + $func_payor_storage_name + ";AccountKey=" + $func_payor_storage_key + ";EndpointSuffix=core.windows.net"

    $config = az webapp config appsettings set -g $rgName -n $func_payor_generator_name --settings AzureWebJobsStorage=$webjobs
    $config = az webapp config appsettings set -g $rgName -n $func_payor_generator_name --settings FUNCTIONS_WORKER_RUNTIME="powershell"
    
    #cd func-realtime-payor-generator-hc2
    #func azure functionapp publish $func_payor_generator_name --powershell --force
    #cd ..

    Compress-Archive -Path "../func-realtime-payor-generator-hc2/*" -DestinationPath "../func-realtime-payor-generator-hc2.zip" -Update
    $TOKEN = az account get-access-token --query accessToken | tr -d '"'  
    $deployment = curl -X POST -H "Authorization: Bearer $TOKEN" -T "../func-realtime-payor-generator-hc2.zip" "https://$func_payor_generator_name.scm.azurewebsites.net/api/zipdeploy"
    Start-Sleep -s 10

    ## Other Apps Deployment
    az webapp stop --name $sites_doc_search_name --resource-group $rgName
    az webapp stop --name $sites_clinical_notes_name --resource-group $rgName
    az webapp stop --name $sites_open_ai_name --resource-group $rgName

    #app doc search
    # az webapp deployment source config-zip --resource-group $rgName --name $sites_doc_search_name --src "./artifacts/binaries/app-health-search.zip"
    $TOKEN_3 = az account get-access-token --query accessToken | tr -d '"'

    $deployment = curl -X POST -H "Authorization: Bearer $TOKEN_3" -T "../artifacts/binaries/app-health-search.zip" "https://$sites_doc_search_name.scm.azurewebsites.net/api/publish?type=zip"
    
    # Publish-AzWebApp -ResourceGroupName $rgName -Name $sites_doc_search_name -ArchivePath ./artifacts/binaries/app-health-search.zip -Force

    #app clinical notes
    (Get-Content -path ../app-clinical-notes/wwwroot/config.js -Raw) | Foreach-Object { $_ `
                -replace '#OPEN_AI_ENDPOINT#', $openAIEndpoint`
                -replace '#MODEL_NAME#', "text-davinci-003"`
                -replace '#SUBSCRIPTION_ID#', $subscriptionId`
                -replace '#RESOURCE_GROUP_NAME#', $rgName`
                -replace '#ML_WORKSPACE_NAME#', $amlworkspacename`
                -replace '#TENANT_ID#', $tenantId`
        } | Set-Content -Path app-clinical-notes/wwwroot/config.js
    Compress-Archive -Path "../app-clinical-notes/*" -DestinationPath "../app-clinical-notes.zip" -Update
   # Publish-AzWebApp -ResourceGroupName $rgName -Name $sites_clinical_notes_name -ArchivePath ./app-clinical-notes.zip -Force
   
   $TOKEN_4 = az account get-access-token --query accessToken | tr -d '"'

   $deployment = curl -X POST -H "Authorization: Bearer $TOKEN_4" -T "../app-clinical-notes.zip" "https://$sites_clinical_notes_name.scm.azurewebsites.net/api/publish?type=zip"


    #app open ai
    (Get-Content -path ../app-open-ai/wwwroot/config.js -Raw) | Foreach-Object { $_ `
                -replace '#OPEN_AI_ENDPOINT#', $openAIEndpoint`
                -replace '#MODEL_NAME#', "text-davinci-003"`
                -replace '#OPEN_AI_KEY#', $openAIPrimaryKey`
        } | Set-Content -Path app-open-ai/wwwroot/config.js
    Compress-Archive -Path "../app-open-ai/*" -DestinationPath "../app-open-ai.zip" -Update

    $TOKEN_5 = az account get-access-token --query accessToken | tr -d '"'

    $deployment = curl -X POST -H "Authorization: Bearer $TOKEN_5" -T "../app-open-ai.zip" "https://$sites_open_ai_name.scm.azurewebsites.net/api/publish?type=zip"
    #Publish-AzWebApp -ResourceGroupName $rgName -Name $sites_open_ai_name -ArchivePath ./app-open-ai.zip -Force