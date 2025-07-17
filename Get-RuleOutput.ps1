Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Import-Module Microsoft.Graph -ErrorAction SilentlyContinue

# AAD rule to PowerShell filter converter
function Convert-AADRuleToPowerShell {
    param ($rule)

    $converted = $rule

    # Simple regex replacements
    $converted = $converted -replace ' -startsWith ', ' -like '
    $converted = $converted -replace ' -notStartsWith ', ' -notlike '
    $converted = $converted -replace ' -contains ', ' -like '
    $converted = $converted -replace ' -notContains ', ' -notlike '

    # Convert quoted values after like/notlike
    $converted = $converted -replace ' -like "(.*?)"', { '-like "' + $Matches[1] + '*"' }
    $converted = $converted -replace ' -notlike "(.*?)"', { '-notlike "' + $Matches[1] + '*"' }

    # Replace 'device.' or 'user.' prefix with $_.
    $converted = $converted -replace '\b(device|user)\.', '$_.'    

    return $converted
}

# GUI Setup
$form = New-Object System.Windows.Forms.Form
$form.Text = "Entra ID Dynamic Rule Tester"
$form.Size = New-Object System.Drawing.Size(650,430)
$form.StartPosition = "CenterScreen"

$label1 = New-Object System.Windows.Forms.Label
$label1.Text = "Paste Entra ID Dynamic Membership Rule:"
$label1.Size = New-Object System.Drawing.Size(600,20)
$label1.Location = New-Object System.Drawing.Point(20,20)
$form.Controls.Add($label1)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.Size = New-Object System.Drawing.Size(600,90)
$textBox.Location = New-Object System.Drawing.Point(20,45)
$form.Controls.Add($textBox)

$typeLabel = New-Object System.Windows.Forms.Label
$typeLabel.Text = "Entity Type:"
$typeLabel.Location = New-Object System.Drawing.Point(20,150)
$form.Controls.Add($typeLabel)

$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(100,147)
$comboBox.Size = New-Object System.Drawing.Size(120,20)
$comboBox.Items.AddRange(@("device", "user"))
$comboBox.SelectedIndex = 0
$form.Controls.Add($comboBox)

$button = New-Object System.Windows.Forms.Button
$button.Text = "Run Query"
$button.Location = New-Object System.Drawing.Point(250,145)
$button.Size = New-Object System.Drawing.Size(100,30)
$form.Controls.Add($button)

$outputLabel = New-Object System.Windows.Forms.Label
$outputLabel.Text = ""
$outputLabel.Size = New-Object System.Drawing.Size(600, 200)
$outputLabel.Location = New-Object System.Drawing.Point(20,190)
$form.Controls.Add($outputLabel)

$button.Add_Click({
    $aadRule = $textBox.Text
    $type = $comboBox.SelectedItem

    if (-not $aadRule) {
        [System.Windows.Forms.MessageBox]::Show("Please paste an Entra ID dynamic rule.")
        return
    }

    try {
        Connect-MgGraph -Scopes "Device.Read.All", "User.Read.All" -ErrorAction Stop
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to connect to Microsoft Graph: $_")
        return
    }

    $outputLabel.Text = "Translating rule and fetching data..."

    try {
        $psRule = Convert-AADRuleToPowerShell -rule $aadRule

        if ($type -eq "device") {
            $objects = Get-MgDevice -All
        } else {
            $objects = Get-MgUser -All
        }

        $script = [ScriptBlock]::Create("`$_ | Where-Object { $psRule }")
        $matches = $objects | & $script
        $outputLabel.Text = "$($matches.Count) $type(s) match the rule.`n`nPowerShell filter:`n$psRule"
    }
    catch {
        $outputLabel.Text = "Error: $_"
    }
})

[void]$form.ShowDialog()