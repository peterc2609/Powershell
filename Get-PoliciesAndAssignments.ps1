# Get all device configuration policies
$policies = Get-MgDeviceManagementDeviceConfiguration -All

# Initialize an array to hold policy details
$policyAssignments = @()

# Loop through each policy to get its assignments
foreach ($policy in $policies) {
    $assignments = Get-MgDeviceManagementDeviceConfigurationAssignment -DeviceConfigurationId $policy.Id
    foreach ($assignment in $assignments) {
        $policyAssignments += [PSCustomObject]@{
            PolicyName     = $policy.DisplayName
            PolicyId       = $policy.Id
            AssignmentType = $assignment.Target."@odata.type"
            TargetId       = $assignment.Target.GroupId
        }
    }
}

# Export the results to a CSV file
$policyAssignments | Export-Csv -Path "IntunePoliciesAssignments.csv" -NoTypeInformation
