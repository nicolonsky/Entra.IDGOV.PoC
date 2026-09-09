#requires -Module Microsoft.Graph.Authentication,Microsoft.Graph.Beta.Applications,Microsoft.Graph.Applications

function Invoke-SCIMGalleryAppReport {

    begin {
        # Get all service principals (enterprise applications)
        $servicePrincipals = Get-MgServicePrincipal -Property DisplayName, AppId, Id, applicationTemplateId -All

        #Getting all apps from the Microsoft Application Catalog that support SCIM provisioning
        $catalogapps = Get-MgApplicationTemplate -Filter "displayName ne 'Custom' and NOT categories/any(c: tolower(c) eq tolower('mdm')) and (supportedProvisioningTypes/any(c: tolower(c) eq tolower('sync')))" -Sort "displayName" -All

        $allscimsupportedserviceprincipals = $servicePrincipals | Where-Object { $_.ApplicationTemplateId -in $catalogapps.Id }

        # Prepare an array to hold SCIM-enabled apps
        $scimApps = @()
    }
    process {
        # Loop through each service principal and check for synchronization jobs
        foreach ($sp in $allscimsupportedserviceprincipals) {
            try {
                $syncJobs = Get-MgServicePrincipalSynchronizationJob -ServicePrincipalId $sp.Id -ErrorAction Stop
                # Initialize flags
                $hasUser = $false
                $hasGroup = $false
                if ($syncJobs) {
                    $syncJobsStatus = "Enabled"
                    $SyncJobInfo = Get-MgBetaServicePrincipalSynchronizationJobSchema -ServicePrincipalId $sp.id -SynchronizationJobId $syncJobs.Id

                    #$SyncJobInfo = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/servicePrincipals/$($sp.id)/synchronization/jobs/$($syncJobs.Id)/schema"

                    $objectMappings = $SyncJobInfo.synchronizationRules.objectMappings

                    $targetdirectory = $SyncJobInfo.synchronizationRules.TargetDirectoryName

                    # Loop through each object mapping
                    foreach ($mapping in $objectMappings) {
                        if ($mapping.SourceObjectName -eq "User") {
                            $hasUser = $true
                            $SupporteduserActions = $mapping.flowTypes
                        }
                        elseif ($mapping.SourceObjectName -eq "Group") {
                            $hasGroup = $true
                            $SupportegroupActions = $mapping.flowTypes
                        }
                    }

                }
                Else {
                    $syncJobsStatus = "Disabled"
                    $SupporteduserActions = "N/A"
                    $SupportegroupActions = "N/A"
                    $targetdirectory = "N/A"

                }
        
                $scimApps += [PSCustomObject]@{
                    DisplayName           = $sp.DisplayName
                    AppId                 = $sp.AppId
                    ObjectId              = $sp.Id
                    Provisioningstatus    = $syncJobsStatus
                    Targetdirectory       = $targetdirectory
                    SupportsUserprov      = $hasUser
                    Supporteduseraction   = $SupporteduserActions
                    SupportsGroupprov     = $hasGroup
                    SupportedGroupActions = $SupportegroupActions
                }
            }
            catch {
                # No sync job found or access denied, skip
            }
        }
         If ($null -lt $scimApps.Count) {
            Write-Output "At least one Gallery Service Principal supports SCIM Provisioning..."
            $scimApps | Export-Csv -Path "$PWD\SCIMGalleryAppsReport.csv" -NoTypeInformation -Delimiter "," -Force
            Write-Output "Report has been exported to: $PWD\SCIMGalleryAppsReport.csv"
        }
        Else {
            Write-Output "No Gallery Service Principal which supports SCIM Provisioning is present in the tenant..."
        }
    }
    
}

###Begin###
#Get consent from the customer and connect using the following command 
Connect-MgGraph -Scopes "Application.Read.All", "Synchronization.Read.All"

#OR Connect using the Token from the Browser / Copy the token into your clipboard and connect using the below command:
#Connect-MgGraph -AccessToken $((Get-Clipboard).Replace("Bearer ", "") | ConvertTo-SecureString -AsPlainText -Force)

Invoke-SCIMGalleryAppReport