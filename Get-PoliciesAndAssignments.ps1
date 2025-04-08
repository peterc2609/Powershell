# Define the output CSV file path
$OutputCsvPath = "Windows_IntunePolicies_Assignments.csv"

# Retrieve all device configuration policies
$allPolicies = Get-MgDeviceManagementDeviceConfiguration -All

# Filter policies to include only those targeting Windows (Platform 1 is Windows10AndLater)
$windowsPolicies = $allPolicies | Where-Object { $_.Platform -eq 1 }

# Initialize an array to hold policy assignment details
$policyAssignments = @()

# Iterate through each Windows policy to retrieve its assignments
foreach ($policy in $windowsPolicies) {
    $assignments = Get-MgDeviceManagementDeviceConfigurationAssignment -DeviceConfigurationId $policy.Id

    foreach ($assignment in $assignments) {
        # Determine the assignment type (Include or Exclude)
        $assignmentType = if ($assignment.Target."@odata.type" -eq "#microsoft.graph.exclusionGroupAssignmentTarget") { "Exclude" } else { "Include" }

        # Retrieve the group ID and name
        $groupId = $assignment.Target.GroupId
        $groupName = "Unknown Group"

        if ($groupId) {
            try {
                $group = Get-MgGroup -GroupId $groupId
                $groupName = $group.DisplayName
            } catch {
                $groupName = "Group Not Found"
            }
        }

        # Retrieve any assignment filters applied
        $filterId = $assignment.Target.DeviceAndAppManagementAssignmentFilterId
        $filterType = $assignment.Target.DeviceAndAppManagementAssignmentFilterType
        $filterName = "No Filter"

        if ($filterId) {
            try {
                $filter = Get-MgDeviceManagementAssignmentFilter -FilterId $filterId
                $filterName = $filter.DisplayName
            } catch {
                $filterName = "Filter Not Found"
            }
        }

        # Add the collected information to the policyAssignments array
        $policyAssignments += [PSCustomObject]@{
            PolicyName     = $policy.DisplayName
            PolicyId       = $policy.Id
            AssignmentType = $assignmentType
            GroupId        = $groupId
            GroupName      = $groupName
            FilterId       = $filterId
            FilterName     = $filterName
            FilterType     = $filterType
        }
    }
}

# Export the collected data to a CSV file
$policyAssignments | Export-Csv -Path $OutputCsvPath -NoTypeInformation

Write-Output "Export completed. The data is available in: $OutputCsvPath"
