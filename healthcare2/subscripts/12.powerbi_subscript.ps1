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
$init =  (Get-AzResourceGroup -Name $rgName).Tags["DeploymentId"]
$random =  (Get-AzResourceGroup -Name $rgName).Tags["UniqueId"] 
$wsId =  (Get-AzResourceGroup -Name $rgName).Tags["WsId"]
$concatString = "$init$random"
$synapseWorkspaceName = "synhealthcare2$concatString"
$sqlPoolName = "HealthcareDW"
$dataLakeAccountName = "sthealthcare2$concatString"
if($dataLakeAccountName.length -gt 24)
{
$dataLakeAccountName = $dataLakeAccountName.substring(0,24)
}

## powerbi
Add-Content log.txt "------powerbi reports upload------"
Write-Host "------------Powerbi Reports Upload------------"
#Connect-PowerBIServiceAccount
RefreshTokens
    $spname = "Healthcare2 Demo $init"

    $app = az ad app create --display-name $spname | ConvertFrom-Json
    $appId = $app.appId

    $mainAppCredential = az ad app credential reset --id $appId | ConvertFrom-Json
    $clientsecpwd = $mainAppCredential.password

    az ad sp create --id $appId | Out-Null    
    $sp = az ad sp show --id $appId --query "id" -o tsv
    start-sleep -s 20

    #https://docs.microsoft.com/en-us/power-bi/developer/embedded/embed-service-principal
    #Allow service principals to user PowerBI APIS must be enabled - https://app.powerbi.com/admin-portal/tenantSettings?language=en-U
    #add PowerBI App to workspace as an admin to group
    RefreshTokens
    $url = "https://api.powerbi.com/v1.0/myorg/groups";
    $result = Invoke-WebRequest -Uri $url -Method GET -ContentType "application/json" -Headers @{ Authorization = "Bearer $powerbitoken" } -ea SilentlyContinue;
    $homeCluster = $result.Headers["home-cluster-uri"]
    #$homeCluser = "https://wabi-west-us-redirect.analysis.windows.net";

    RefreshTokens
    $url = "$homeCluster/metadata/tenantsettings"
    $post = "{`"featureSwitches`":[{`"switchId`":306,`"switchName`":`"ServicePrincipalAccess`",`"isEnabled`":true,`"isGranular`":true,`"allowedSecurityGroups`":[],`"deniedSecurityGroups`":[]}],`"properties`":[{`"tenantSettingName`":`"ServicePrincipalAccess`",`"properties`":{`"HideServicePrincipalsNotification`":`"false`"}}]}"
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer $powerbiToken")
    $headers.Add("X-PowerBI-User-Admin", "true")
    #$result = Invoke-RestMethod -Uri $url -Method PUT -body $post -ContentType "application/json" -Headers $headers -ea SilentlyContinue;

    #add PowerBI App to workspace as an admin to group
    RefreshTokens
    $url = "https://api.powerbi.com/v1.0/myorg/groups/$wsid/users";
    $post = "{
    `"identifier`":`"$($sp)`",
    `"groupUserAccessRight`":`"Admin`",
    `"principalType`":`"App`"
    }";

    $result = Invoke-RestMethod -Uri $url -Method POST -body $post -ContentType "application/json" -Headers @{ Authorization = "Bearer $powerbitoken" } -ea SilentlyContinue;

    #get the power bi app...
    $powerBIApp = Get-AzADServicePrincipal -DisplayNameBeginsWith "Power BI Service"
    $powerBiAppId = $powerBIApp.Id;

    #setup powerBI app...
    RefreshTokens
    $url = "https://graph.microsoft.com/beta/OAuth2PermissionGrants";
    $post = "{
    `"clientId`":`"$appId`",
    `"consentType`":`"AllPrincipals`",
    `"resourceId`":`"$powerBiAppId`",
    `"scope`":`"Dataset.ReadWrite.All Dashboard.Read.All Report.Read.All Group.Read Group.Read.All Content.Create Metadata.View_Any Dataset.Read.All Data.Alter_Any`",
    `"expiryTime`":`"2021-03-29T14:35:32.4943409+03:00`",
    `"startTime`":`"2020-03-29T14:35:32.4933413+03:00`"
    }";

    $result = Invoke-RestMethod -Uri $url -Method GET -ContentType "application/json" -Headers @{ Authorization = "Bearer $graphtoken" } -ea SilentlyContinue;

    #setup powerBI app...
    RefreshTokens
    $url = "https://graph.microsoft.com/beta/OAuth2PermissionGrants";
    $post = "{
    `"clientId`":`"$appId`",
    `"consentType`":`"AllPrincipals`",
    `"resourceId`":`"$powerBiAppId`",
    `"scope`":`"User.Read Directory.AccessAsUser.All`",
    `"expiryTime`":`"2021-03-29T14:35:32.4943409+03:00`",
    `"startTime`":`"2020-03-29T14:35:32.4933413+03:00`"
    }";

    $result = Invoke-RestMethod -Uri $url -Method GET -ContentType "application/json" -Headers @{ Authorization = "Bearer $graphtoken" } -ea SilentlyContinue;
    
    $credential = New-Object PSCredential($appId, (ConvertTo-SecureString $clientsecpwd -AsPlainText -Force))

   # Connect to Power BI using the service principal
    Connect-PowerBIServiceAccount -ServicePrincipal -Credential $credential -TenantId $tenantId

    $PowerBIFiles = Get-ChildItem "../artifacts/reports" -Recurse -Filter *.pbix
    $reportList = @()

    foreach ($Pbix in $PowerBIFiles) {
    Write-Output "Uploading report: $($Pbix.FullName)"
  
    $report = New-PowerBIReport -Path $Pbix.FullName -WorkspaceId $wsId

    if ($report -ne $null) {
        Write-Output "Report uploaded successfully: $($report.Name)"

        $temp = [PSCustomObject]@{
            FileName        = $Pbix.FullName
            Name            = $Pbix.BaseName  # Using BaseName to get the file name without the extension
            PowerBIDataSetId = $null
            ReportId        = $report.Id
            SourceServer    = $null
            SourceDatabase  = $null
        }

        # Get dataset
        $url = "https://api.powerbi.com/v1.0/myorg/groups/$wsId/datasets"
        $dataSets = Invoke-RestMethod -Uri $url -Method GET -Headers @{ Authorization="Bearer $powerbitoken" }

        foreach ($res in $dataSets.value) {
            if ($res.name -eq $temp.Name) {
                $temp.PowerBIDataSetId = $res.id
                break  # Exit the loop once a match is found
            }
        }

        $reportList += $temp
    } else {
        Write-Output "Failed to upload report: $($Pbix.FullName)"
    }
    }

    Start-Sleep -s 30

##Establish powerbi reports dataset connections
    Add-Content log.txt "------pbi connections update------"
    Write-Host "---------PBI connections update---------"
    
    # TakingOver Datasets.
    foreach ($report in $reportList) {
    $datasetId = $report.PowerBIDataSetId
    $url = "https://api.powerbi.com/v1.0/myorg/groups/$wsId/datasets/$datasetId/Default.TakeOver"

    try {
        $response = Invoke-RestMethod -Uri $url -Method POST -Headers @{ Authorization = "Bearer $powerbitoken" }
        Write-Host "TakeOver action completed successfully for dataset ID: $datasetId"
    }
    catch {
        Write-Host "Error occurred while performing TakeOver action for dataset ID: $datasetId - $_"
    }
    }

    RefreshTokens
    foreach ($report in $reportList) {
        if ($report.name -eq "ER Wait Time KPIs" -or $report.name -eq "ER Wait Time KPIs 1" -or $report.name -eq "Healthcare - Before and After dashboard GIF" -or $report.name -eq "Healthcare chicklets" -or $report.name -eq "Healthcare Dashbaord Images-Final" -or $report.name -eq "Reports with Dashboard GIF" -or $report.name -eq "Healthcare - Call Center Power BI-After (with recc Script)") {
            continue;
        }
        elseif ($report.name -eq "Healthcare - Bed Occupancy ") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Server`",
									`"newValue`": `"$($synapseWorkspaceName).sql.azuresynapse.net`"
								},
								{
									`"name`": `"Database_Name`",
									`"newValue`": `"$($sqlPoolName)`"
								},
								{
									`"name`": `"Serverless`",
									`"newValue`": `"$($synapseWorkspaceName)-ondemand.sql.azuresynapse.net`"
								},
								{
									`"name`": `"Database_Serverless`",
									`"newValue`": `"SQLServerlessPool`"
								}
								]
								}"	
        }
        elseif ($report.name -eq "3 HealthCare Dynamic Data Masking (Azure Synapse)" -or $report.name -eq "4 HealthCare Column Level Security (Azure Synapse)" -or $report.name -eq "5 HealthCare Row Level Security (Azure Synapse)" -or $report.name -eq "Healthcare - HTAP-Lab-Data" -or $report.name -eq "Healthcare Miami Hospital Overview") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Server`",
									`"newValue`": `"$($synapseWorkspaceName).sql.azuresynapse.net`"
								},
								{
									`"name`": `"Database`",
									`"newValue`": `"$($sqlPoolName)`"
								}
								]
								}"	
        }
        elseif ($report.name -eq "Healthcare FHIR") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Server_Name`",
									`"newValue`": `"$($synapseWorkspaceName).sql.azuresynapse.net`"
								},
								{
									`"name`": `"DB_Name`",
									`"newValue`": `"$($sqlPoolName)`"
								}
								]
								}"	
        }
        elseif ($report.name -eq "Healthcare - Call Center Power BI Before" -or $report.name -eq "Healthcare - Call Center Power BI-After") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Server_Name`",
									`"newValue`": `"$($synapseWorkspaceName)-ondemand.sql.azuresynapse.net`"
								},
								{
									`"name`": `"DB_Name`",
									`"newValue`": `"SQLServerlessPool`"
								}
								]
								}"	
        }
        elseif ($report.name -eq "Healthcare - Patients Profile report") {
            $body = "{
			`"updateDetails`": [
                                {
                                    `"name`": `"Server`",
                                    `"newValue`": `"$($synapseWorkspaceName).sql.azuresynapse.net`"
                                },
                                {
                                    `"name`": `"Database_ChatBot`",
                                    `"newValue`": `"$($sqlPoolName)`"
                                },
                                {
                                    `"name`": `"SQL_Server`",
                                    `"newValue`": `"$($synapseWorkspaceName)-ondemand.sql.azuresynapse.net`"
                                },
                                {
                                    `"name`": `"Database`",
                                    `"newValue`": `"SQLServerlessPool`"
                                }
                                ]
                                }"	
        }
        elseif ($report.name -eq "Healthcare - US Map" -or $report.name -eq "Healthcare Global overview tiles") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Server`",
									`"newValue`": `"$($synapseWorkspaceName)-ondemand.sql.azuresynapse.net`"
								},
								{
									`"name`": `"Database`",
									`"newValue`": `"SQLServerlessPool`"
								}
								]
								}"	
        }
        elseif ($report.name -eq "Healthcare Consolidated Report") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Server_Name`",
									`"newValue`": `"$($synapseWorkspaceName).sql.azuresynapse.net`"
								},
								{
									`"name`": `"Database_Name`",
									`"newValue`": `"$($sqlPoolName)`"
								},
								{
									`"name`": `"BlobStorage`",
									`"newValue`": `"https://$($dataLakeAccountName).blob.core.windows.net/consolidated-report`"
								}
								]
								}"	
        }
        elseif ($report.name -eq "Healthcare Global Occupational Safety Report") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Blob Location`",
									`"newValue`": `"https://$($dataLakeAccountName).dfs.core.windows.net/healthcare-reports/`"
								},
								{
									`"name`": `"Server`",
									`"newValue`": `"$($synapseWorkspaceName).sql.azuresynapse.net`"
								},
								{
									`"name`": `"Database`",
									`"newValue`": `"$($sqlPoolName)`"
								}
								]
								}"	
        }
        elseif ($report.name -eq "Healthcare Patient Overview") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Blob Storage`",
									`"newValue`": `"https://$($dataLakeAccountName).blob.core.windows.net/healthcare-reports`"
								}
								]
								}"	
        }
        elseif ($report.name -eq "Static Realtime Healthcare analytics") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Server_Gen2`",
									`"newValue`": `"https://$($dataLakeAccountName).dfs.core.windows.net/healthcare-reports/`"
								}
								]
								}"	
        }
        elseif ($report.name -eq "Payor Dashboard report") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Blob Server`",
									`"newValue`": `"https://$($dataLakeAccountName).blob.core.windows.net/healthcare-reports`"
								}
								]
								}"	
        }
        elseif ($report.name -eq "HealthCare Predctive Analytics_V1") {
            $body = "{
			`"updateDetails`": [
								{
									`"name`": `"Healthcare_server`",
									`"newValue`": `"$($synapseWorkspaceName).sql.azuresynapse.net`"
								},
								{
									`"name`": `"HealthcareDW`",
									`"newValue`": `"$($sqlPoolName)`"
								}
								]
								}"	
        }
	
        Write-Host "PBI connections updating for report : $($report.name)"	
        $url = "https://api.powerbi.com/v1.0/myorg/groups/$($wsId)/datasets/$($report.PowerBIDataSetId)/Default.UpdateParameters"
        $pbiResult = Invoke-RestMethod -Uri $url -Method POST -Body $body -ContentType "application/json" -Headers @{ Authorization = "Bearer $powerbitoken" } -ErrorAction SilentlyContinue;
		
        start-sleep -s 5
    }

