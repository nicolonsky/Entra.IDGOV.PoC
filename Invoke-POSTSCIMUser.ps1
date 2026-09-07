# POST SCIM user envelope to Graph API for bulk upload
# Note: this script assumes the SCIM user data is already prepared in a JSON file (SCIMBulkRequest)

if (-not $ENV:CI){
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
    Connect-MgGraph -Scopes "SynchronizationData-User.Upload" -TenantId '5f4eb598-671f-4066-8830-7ec82393defd'
}

$endpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/43a7fc53-b6c2-403a-937a-65020143ceab/synchronization/jobs/API2AAD.5f4eb598671f406688307ec82393defd.e3f2184f-a780-449b-b77f-98962523fc43/bulkUpload'
$requestBody = Get-Content -Raw -Path 'SCIMBulkRequest.json'
Invoke-MgGraphRequest -Method POST -Uri $endpoint -Body $requestBody -Headers @{ "Content-Type" = "application/scim+json" }