# Output path
$OutputCsvPath = "Filtered_OSPREY_IntunePolicies_Assignments.csv"

# Helper: Get group name
function Get-GroupName($groupId) {
    try {
        (Get-MgGroup -GroupId $groupId).DisplayName
    } catch {
        "Group Not Found"
    }
}

# Helper: Get filter name
function Get-FilterName($filterId) {
    try {
        (Get-MgDeviceManagementAssignmentFilter -FilterId $filterId).DisplayName
    } catch {
        "Filter Not Found"
    }
}

# Define policy types to fetch
$policyTypes = @(
    @{ Name = "Device Configuration Profiles"; Uri = "deviceManagement/deviceConfigurations" },
    @{ Name = "Administrative Templates"; Uri = "deviceManagement/groupPolicyConfigurations" },
    @{ Name = "Settings Catalog Policies"; Uri = "deviceManagement/configurationPolicies" },
    @{ Name = "Compliance Policies"; Uri = "deviceManagement/deviceCompliancePolicies" },
    @{ Name = "Endpoint Security Policies"; Uri = "deviceManagement/intents" }
)

# Store all results
$policyAssignments = @()

# Loop through each policy type
foreach ($policyType in $policyTypes) {
    $uri = "https://graph.microsoft.com/beta/$($policyType.Uri)?`$expand=assignments"
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri

    foreach ($policy in $response.value) {
        # Some Settings Catalog policies may not have displayName directly
        $displayName = if ($policy.displayName) { $policy.displayName } elseif ($policy.name) { $policy.name } else { "Unknown Name" }

        # Skip policies that don't match the OSPREY filter
        if ($displayName -notmatch "^\*?OSPREY") { continue }

        # Filter to Windows platform only (platform 1 = Windows10AndLater)
        if ($policy.PSObject.Properties.Name -contains "platform") {
            if ($policy.platform -ne 1) { continue }
        }

        foreach ($assignment in $policy.assignments) {
            $assignmentType = if ($assignment.target."@odata.type" -eq "#microsoft.graph.exclusionGroupAssignmentTarget") { "Exclude" } else { "Include" }

            $groupId    = $assignment.target.groupId
            $groupName  = if ($groupId) { Get-GroupName $groupId } else { "None" }

            $filterId   = $assignment.target.deviceAndAppManagementAssignmentFilterId
            $filterName = if ($filterId) { Get-FilterName $filterId } else { "None" }
            $filterType = if ($filterId) { $assignment.target.deviceAndAppManagementAssignmentFilterType } else { "None" }

            $policyAssignments += [PSCustomObject]@{
                PolicyType     = $policyType.Name
                PolicyName     = $displayName
                PolicyId       = $policy.id
                AssignmentType = $assignmentType
                GroupId        = $groupId
                GroupName      = $groupName
                FilterId       = $filterId
                FilterName     = $filterName
                FilterType     = $filterType
            }
        }
    }
}

# Export
$policyAssignments | Export-Csv -Path $OutputCsvPath -NoTypeInformation
Write-Host "Done. Output saved to: $OutputCsvPath"
