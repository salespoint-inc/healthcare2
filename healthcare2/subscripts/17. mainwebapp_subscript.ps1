function RefreshTokens() {
        #Copy external blob content
        $global:powerbitoken = ((az account get-access-token --resource https://analysis.windows.net/powerbi/api) | ConvertFrom-Json).accessToken
        $global:synapseToken = ((az account get-access-token --resource https://dev.azuresynapse.net) | ConvertFrom-Json).accessToken
        $global:graphToken = ((az account get-access-token --resource https://graph.microsoft.com) | ConvertFrom-Json).accessToken
        $global:managementToken = ((az account get-access-token --resource https://management.azure.com) | ConvertFrom-Json).accessToken
        $global:purviewToken = ((az account get-access-token --resource https://purview.azure.net) | ConvertFrom-Json).accessToken
    }

    function Check-HttpRedirect($uri) {
        $httpReq = [system.net.HttpWebRequest]::Create($uri)
        $httpReq.Accept = "text/html, application/xhtml+xml, */*"
        $httpReq.method = "GET"   
        $httpReq.AllowAutoRedirect = $false;
    
        #use them all...
        #[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Ssl3 -bor [System.Net.SecurityProtocolType]::Tls;

        $global:httpCode = -1;
    
        $response = "";            

        try {
            $res = $httpReq.GetResponse();

            $statusCode = $res.StatusCode.ToString();
            $global:httpCode = [int]$res.StatusCode;
            $cookieC = $res.Cookies;
            $resHeaders = $res.Headers;  
            $global:rescontentLength = $res.ContentLength;
            $global:location = $null;
                                
            try {
                $global:location = $res.Headers["Location"].ToString();
                return $global:location;
            }
            catch {
            }

            return $null;

        }
        catch {
            $res2 = $_.Exception.InnerException.Response;
            $global:httpCode = $_.Exception.InnerException.HResult;
            $global:httperror = $_.exception.message;

            try {
                $global:location = $res2.Headers["Location"].ToString();
                return $global:location;
            }
            catch {
            }
        } 

        return $null;
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
    $cpuShell = "healthcare-compute"
    $forms_healthcare2_name = "form-healthcare2-$suffix"
    $synapseWorkspaceName = "synhealthcare2$concatString"
    $sqlPoolName = "HealthcareDW"
    $dataLakeAccountName = "sthealthcare2$concatString"
    if($dataLakeAccountName.length -gt 24)
    {
    $dataLakeAccountName = $dataLakeAccountName.substring(0,24)
    }
    $amlworkspacename = "aml-hc2-$suffix"
    $databricks_workspace_name = "databricks-hc2-$suffix"
    $sqlUser = "labsqladmin"
    $mssql_server_name = "mssqlhc2-$suffix"
    $sqlDatabaseName = "InventoryDB"
    $accounts_purviewhealthcare2_name = "purviewhc2$suffix"
    $purviewCollectionName1 = "ADLS"
    $purviewCollectionName2 = "AzureSynapseAnalytics"
    $purviewCollectionName3 = "AzureCosmosDB"
    $purviewCollectionName4 = "PowerBI"
    $namespaces_evh_patient_monitoring_name = "evh-patient-monitoring-hc2-$suffix"
    $sites_patient_data_simulator_name = "app-patient-data-simulator-$suffix"
    $serverfarm_patient_data_simulator_name = "asp-patient-data-simulator-$suffix"
    $sites_clinical_notes_name = "app-clinical-notes-$suffix"
    $sites_doc_search_name = "app-health-search-$suffix"
    $sites_open_ai_name = "app-open-ai-$suffix"
    $app_healthcare2_name = "app-healthcare2-$suffix"
    $streamingjobs_deltadata_asa_name = "asa-hc2-deltadata-$suffix"
    $cosmos_healthcare2_name = "cosmos-healthcare2-$random$init"
    if ($cosmos_healthcare2_name.length -gt 43) {
        $cosmos_healthcare2_name = $cosmos_healthcare2_name.substring(0, 43)
    }
    $cosmosDatabaseName = "healthcare"
    $searchName = "srch-healthcare2-$suffix"
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
    $subscriptionId = (Get-AzContext).Subscription.Id
    $tenantId = (Get-AzContext).Tenant.Id
    $usercred = ((az ad signed-in-user show) | ConvertFrom-JSON).UserPrincipalName
    $kustoPoolName = "hc2kustopool$init"
    $kustoDatabaseName = "HC2KustoDB$init"
    $openAIResource = "openAIservicehc2$concatString"
    if($openAIResource.length -gt 24)
    {
    $openAIResource = $openAIResource.substring(0,24)
    }
    $funstorageAccountName = "stfunchc2"
    $func_copilot = "func-copilot-hc2-$suffix"

    $storage_account_key = (Get-AzStorageAccountKey -ResourceGroupName $rgName -AccountName $dataLakeAccountName)[0].Value

    $forms_hc2_keys = Get-AzCognitiveServicesAccountKey -ResourceGroupName $rgName -name $forms_healthcare2_name
    
    #Cosmos keys
    $cosmos_account_key = az cosmosdb keys list -n $cosmos_healthcare2_name -g $rgName | ConvertFrom-Json
    $cosmos_account_key = $cosmos_account_key.primarymasterkey

    #retrieving openai endpoint
    $openAIEndpoint = az cognitiveservices account show -n $openAIResource -g $rgName | jq -r .properties.endpoint

    #retirieving primary key
    $openAIPrimaryKey = az cognitiveservices account keys list -n $openAIResource -g $rgName | jq -r .key1

    Install-Module -Name Az.Search -RequiredVersion 0.7.4 -f
    $adminKeyPair = Get-AzSearchAdminKeyPair -ResourceGroupName $rgName -ServiceName $searchName
    $primaryAdminKey = $adminKeyPair.Primary

    Add-Content log.txt "------unzipping poc web app------"
    Write-Host  "--------------Unzipping web app---------------"
    $zips = @("func-realtime-payor-generator-hc2", "healthcare2-demo-app", "app-clinical-notes", "app-open-ai")
    foreach ($zip in $zips) {
        expand-archive -path "./artifacts/binaries/$($zip).zip" -destinationpath "./$($zip)" -force
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

(Get-Content -path healthcare2-demo-app/appsettings.json -Raw) | Foreach-Object { $_ `
            -replace '#WORKSPACE_ID#', $wsId`
            -replace '#APP_ID#', $appId`
            -replace '#APP_SECRET#', $clientsecpwd`
            -replace '#TENANT_ID#', $tenantId`
            -replace '#REGION#', $Region`
            -replace '#COGNITIVE_SERVICE_ENDPOINT#', $cognitiveEndpoint`
            -replace '#COGNITIVE_KEY#', $cognitivePrimaryKey`
    } | Set-Content -Path healthcare2-demo-app/appsettings.json

    $filepath = "./healthcare2-demo-app/wwwroot/config-poc.js"
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
    
    $filePath = "./healthcare2-demo-app/wwwroot/config-poc.js";
    Set-Content $filePath $(ReplaceTokensInFile $ht $filePath)

    Compress-Archive -Path "./healthcare2-demo-app/*" -DestinationPath "./healthcare2-demo-app.zip" -Update

    # az webapp stop --name $app_healthcare2_name --resource-group $rgName
    # try {
    #     az webapp deployment source config-zip --resource-group $rgName --name $app_healthcare2_name --src "./healthcare2-demo-app.zip"
    # }
    # catch {
    # }

    $TOKEN_1 = az account get-access-token --query accessToken | tr -d '"'

    $deployment = curl -X POST -H "Authorization: Bearer $TOKEN_1" -T "./healthcare2-demo-app.zip" "https://$app_healthcare2_name.scm.azurewebsites.net/api/publish?type=zip"
    
    az webapp start --name $app_healthcare2_name --resource-group $rgName
