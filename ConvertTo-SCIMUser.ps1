<#
.SYNOPSIS
    Maps HRData.csv rows to SCIM bulk request JSON based on UserMapping.txt schema.
.DESCRIPTION
    Reads HRData.csv, maps each row to a SCIM User resource, and outputs
    a SCIM bulk request JSON file (BulkRequest.json).
    Edit the column mapping tables below to adjust for different HR data sources.
#>

param(
    [string]$CsvPath = "$PSScriptRoot\HRData.csv",
    [string]$OutputPath = "$PSScriptRoot\SCIMBulkRequest.json"
)

# ============================================================================
# COLUMN MAPPING CONFIGURATION
# Adjust these mappings when the HR CSV columns change.
# Format: SCIM attribute = CSV column name
# ============================================================================

# --- Core User Attributes ---
$CoreMapping = @{
    externalId        = 'WorkerID'
    userName          = 'WorkerID'
    userType          = 'WorkerType'
    title             = 'jobTitle'
    nickName          = 'WorkerID'
    preferredLanguage = 'preferredLanguage'
    activeField       = 'WorkerStatus'      # Compared against $ActiveValue
    activeValue       = 'TRUE'
}

# --- Name ---
$NameMapping = @{
    givenName  = 'FirstName'
    familyName = 'LastName'
}

# --- Address ---
$AddressMapping = @{
    country       = 'country'
    region        = 'state'
    locality      = 'city'
    postalCode    = 'postalCode'
    streetAddress = 'streetAddress'
}

# --- Phone Numbers (type = CSV column) ---
$PhoneMapping = [ordered]@{
    mobile = 'mobilePhone'
    work   = 'telePhone'
}

# --- Enterprise Extension (urn:ietf:params:scim:schemas:extension:enterprise:2.0:User) ---
$EnterpriseMapping = @{
    organization   = 'Company'
    costCenter     = 'CostCenter'
    department     = 'Department'
    division       = 'division'
    employeeNumber = 'WorkerID'
    manager        = 'managerID'
}

# --- Custom Enterprise Extension (nested under enterprise extension) ---
$CustomEnterpriseMapping = [ordered]@{
    TourOwnership = 'TourOwnership'
}

# --- Custom CSV Extension (urn:ietf:params:scim:schemas:extension:csv:1.0:User) ---
$CsvExtMapping = [ordered]@{
    GenderPronoun     = 'GenderPronoun'
    HireDate          = 'HireDate'
    JobCode           = 'JobCode'
    LastDayofWork     = 'LastDayofWork'
    securityClearance = 'securityClearance'
}

# ============================================================================
# PROCESSING — no changes needed below unless altering the SCIM structure
# ============================================================================

# Helper: return empty string instead of null
function NullToEmpty ($v) { if ($null -eq $v) { '' } else { $v } }

$workers = Import-Csv -Path $CsvPath

$operations = foreach ($worker in $workers) {

    # Active status
    $isActive = $false

    # Address
    $address = [ordered]@{ type = "work" }
    foreach ($key in $AddressMapping.Keys) {
        $address[$key] = NullToEmpty $worker.($AddressMapping[$key])
    }

    # Phone numbers (skip empty)
    $phoneNumbers = @()
    foreach ($type in $PhoneMapping.Keys) {
        $val = $worker.($PhoneMapping[$type])
        if ($val) {
            $phoneNumbers += [ordered]@{ type = $type; value = $val }
        }
    }

    # Enterprise extension
    $enterpriseExt = [ordered]@{}
    foreach ($key in 'organization','costCenter','department','division','employeeNumber') {
        $enterpriseExt[$key] = NullToEmpty $worker.($EnterpriseMapping[$key])
    }
    $mgr = NullToEmpty $worker.($EnterpriseMapping.manager)
    $enterpriseExt.manager = [ordered]@{ value = $mgr }

    # Nested custom enterprise extension
    $customEnterpriseExt = [ordered]@{}
    foreach ($key in $CustomEnterpriseMapping.Keys) {
        $customEnterpriseExt[$key] = NullToEmpty $worker.($CustomEnterpriseMapping[$key])
    }
    $enterpriseExt["urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"] = $customEnterpriseExt

    # CSV extension
    $csvExt = [ordered]@{}
    foreach ($key in $CsvExtMapping.Keys) {
        $csvExt[$key] = NullToEmpty $worker.($CsvExtMapping[$key])
    }

    # SCIM User resource
    $userData = [ordered]@{
        active            = $isActive
        addresses         = @($address)
        externalId        = NullToEmpty $worker.($CoreMapping.externalId)
        name              = [ordered]@{
            familyName = NullToEmpty $worker.($NameMapping.familyName)
            givenName  = NullToEmpty $worker.($NameMapping.givenName)
        }
        nickName          = NullToEmpty $worker.($CoreMapping.nickName)
        phoneNumbers      = $phoneNumbers
        preferredLanguage = NullToEmpty $worker.($CoreMapping.preferredLanguage)
        schemas           = @(
            "urn:ietf:params:scim:schemas:core:2.0:User"
            "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
            "urn:ietf:params:scim:schemas:extension:csv:1.0:User"
            "urn:itdrlab:params:scim:schemas:extension:enterprise:2.0:User"
        )
        title             = NullToEmpty $worker.($CoreMapping.title)
        "urn:ietf:params:scim:schemas:extension:csv:1.0:User"        = $csvExt
        "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = $enterpriseExt
        userName          = NullToEmpty $worker.($CoreMapping.userName)
        userType          = NullToEmpty $worker.($CoreMapping.userType)
    }

    # Bulk operation
    [ordered]@{
        bulkId = [guid]::NewGuid().ToString()
        data   = $userData
        method = "POST"
        path   = "/Users"
    }
}

# Wrap in SCIM bulk request envelope
$bulkRequest = [ordered]@{
    schemas    = @("urn:ietf:params:scim:api:messages:2.0:BulkRequest")
    Operations = $operations
    failOnErrors = $true
}

# Convert to JSON and write to file
$json = $bulkRequest | ConvertTo-Json -Depth 10
$json | Out-File -FilePath $OutputPath -Encoding UTF8

Write-Host "Generated $($operations.Count) SCIM operations -> $OutputPath"
