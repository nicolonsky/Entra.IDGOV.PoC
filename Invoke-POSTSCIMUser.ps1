<#
.SYNOPSIS
    Uploads a SCIM bulk request to Microsoft Entra API-driven provisioning.

.DESCRIPTION
    Reads SCIMBulkRequest.json from the script directory and submits it to the
    specified Microsoft Graph provisioning endpoint. When running outside CI,
    the script signs in interactively with the required delegated scope.

.PARAMETER ProvisioningEndpoint
    The complete Microsoft Graph bulkUpload endpoint for the API-driven
    provisioning job.

.PARAMETER SCIMBulkRequestPath
    The path to the SCIM bulk request JSON file. Defaults to
    SCIMBulkRequest.json in the script directory.

.EXAMPLE
    ./Invoke-POSTSCIMUser.ps1

    Uploads the SCIM bulk request to the default provisioning endpoint.

.EXAMPLE
    ./Invoke-POSTSCIMUser.ps1 -ProvisioningEndpoint $endpoint -WhatIf

    Shows the target endpoint without submitting the request.

.NOTES
    CI callers must authenticate to Microsoft Graph before invoking this script.
#>

#Requires -Modules Microsoft.Graph.Authentication

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [uri]$ProvisioningEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/43a7fc53-b6c2-403a-937a-65020143ceab/synchronization/jobs/API2AAD.5f4eb598671f406688307ec82393defd.e3f2184f-a780-449b-b77f-98962523fc43/bulkUpload',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SCIMBulkRequestPath = (Join-Path -Path $PSScriptRoot -ChildPath 'SCIMBulkRequest.json')
)

$ErrorActionPreference = 'Stop'

if (-not $env:CI) {
    Connect-MgGraph -Scopes 'SynchronizationData-User.Upload' -NoWelcome
}

$requestBody = Get-Content -Raw -LiteralPath $SCIMBulkRequestPath

if ($PSCmdlet.ShouldProcess($ProvisioningEndpoint, 'Upload SCIM bulk request')) {
    Invoke-MgGraphRequest `
        -Method POST `
        -Uri $ProvisioningEndpoint `
        -Body $requestBody `
        -Headers @{ 'Content-Type' = 'application/scim+json' }
}