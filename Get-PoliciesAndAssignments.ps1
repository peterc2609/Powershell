# Define the output CSV file path
$OutputCsvPath = "Intune_Policies_Assignments.csv"

# Initialize an array to hold policy assignment details
$policyAssignments = @()

# Function to retrieve group display name by Group ID
function Get-GroupName($groupId) {
    try {
        $group = Get-MgGroup -GroupId $groupId
        return $group.DisplayName
    } catch {
        return "Group Not Found"
    }
}

# Function to retrieve filter display name by Filter ID
function Get-FilterName($filterId) {
    try {
        $filter = Get-MgDeviceManagementAssignmentFilter -FilterId $filterId
        return $filter.DisplayName
    } catch {
        return "Filter Not Found"
    }
}

# Array of policy types to retrieve
$policyTypes = @(
    @{ Name = "Device Configuration Profiles"; Uri = "deviceManagement/deviceConfigurations" },
    @{ Name = "Administrative Templates"; Uri = "deviceManagement/groupPolicyConfigurations" },
    @{ Name = "Settings Catalog Policies"; Uri = "deviceManagement/configurationPolicies" },
    @{ Name = "Compliance Policies"; Uri = "deviceManagement/deviceCompliancePolicies" },
    @{ Name = "Endpoint Security Policies"; Uri = "deviceManagement/intents" }
)

# Iterate through each policy type
foreach ($policyType in $policyTypes) {
    $policies = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/$($policyType.Uri)?`$expand=assignments"

    foreach ($policy in $policies.value) {
        foreach ($assignment in $policy.assignments) {
            # Determine the assignment type (Include or Exclude)
            $assignmentType = if ($assignment.target."@odata.type" -eq "#microsoft.graph.exclusionGroupAssignmentTarget") { "Exclude" } else { "Include" }

            # Retrieve group information
            $groupId = $assignment.target.groupId
            $groupName = Get-GroupName $groupId

            # Retrieve filter information
            $filterId = $assignment.target.deviceAndAppManagementAssignmentFilterId
            $filterName = Get-FilterName $filterId
            $filterType = $assignment.target.deviceAndAppManagementAssignmentFilterType

            # Add the collected information to the policyAssignments array
            $policyAssignments += [PSCustomObject]@{
                PolicyType     = $policyType.Name
                PolicyName     = $policy.displayName
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

# Export the collected data to a CSV file
$policyAssignments | Export-Csv -Path $OutputCsvPath -NoTypeInformation

Write-Output "Export completed. The data is available in: $OutputCsvPath"
