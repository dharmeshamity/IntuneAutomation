<#
.SYNOPSIS
Converts devices to company managed devices. 
.DESCRIPTION
This script will take Source CSV file with devices. For each device in the CSV file, the script will verify if the device is managed by the company. 
If not, it will update the device to be managed by the comany.

.PARAMETER Environment
Accepts DEV, TEST, PRODUCTION. 
.PARAMETER AppSettingsOverrides 
To override default attributes by environment use this parameter. 
.PARAMETER MSGraphAPICredential
Credential for using with microsoft graph api.
.EXAMPLE
kwejwe
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("DEV", "TEST", "PRODUCTION")]
    [string]
    $Environment,
    [Parameter(Mandatory=$true)]
    [System.Management.Automation.PSCredential]
    $MSGraphAPICredential,
    [Parameter(Mandatory=$false)]
    [Hashtable]
    $AppSettingsOverrides,
    [Parameter(Mandatory=$false)]
    [ValidateSet('company','personal')]
    [string]
    $newOwnerType = 'company'
)

begin{
    $path_sep = [IO.Path]::DirectorySeparatorChar
    . ".$($path_sep)Invoke-IntuneDeviceAutomationFunctions.ps1"
}
process {
    try{
        Write-Host "Begin"
        $appsettings = Initialize-IAAppSettings -Environment $Environment -path_seperator $path_sep -AppSettingsOverrides $AppSettingsOverrides

        If(-not (Test-Path($appsettings.SourceCSVFilePath)))
        {
            Write-Error "Source File not found or cannot access"
            return
        }

        if(-not (Test-Path($appsettings.ResultFolderPath))) {
            Write-Warning "Result path is not found. Trying to create.."
            New-Item -Path $appsettings.ResultFolderPath -ItemType Directory
            Write-Host "Created Result Path"
        }

        $auth_token = Get-IAAuthenticationToken -MSGraphAuthenticationEndpoint $appsettings.MSGraphApiAuthenticationEndpoint -MSGraphClientId $appsettings.MSGraphApiClientId -MSGraphAPICredential $MSGraphAPICredential
        If([string]::IsNullOrEmpty($auth_token)) 
        {
            throw "Auth Token is empty or null. Cannot proceed further"
        }
        Write-Host "Successfully received auth token"

        $devices = Import-csv -Delimiter $appsettings.SourceCSVDemiliter -Path $appsettings.SourceCSVFilePath
        $results = New-Object -TypeName "System.Collections.ArrayList"
        ForEach ($device in $devices) 
        {
            $device_info = Get-IAManagedDeviceInfo -MSGraphDeviceManagementEndpoint $appsettings.MSGraphApiIntuneDeviceManagementEndpoint -MSGraphAuthToken $auth_token -MSGraphDeviceId $device."Device ID"
            if($device_info) 
            {
                $owner_type = $device_info.managedDeviceOwnerType
                Write-Host "Managed Owner Type: $($owner_type)"
                $result_value = "";
                If(-not [string]::Equals($owner_type, $newOwnerType, [System.StringComparison]::InvariantCultureIgnoreCase)) 
                {
                    Write-Host "Device Id: $($device."Device ID") is not managed by $newOwnerType. Attempting to update the managed owner"
                    $issuccess = Update-IAManagedOwnerType -MSGraphDeviceManagementEndpoint $appsettings.MSGraphApiIntuneDeviceManagementEndpoint -MSGraphAuthToken $auth_token -MSGraphDeviceId $device."Device ID" -NewOwnerType $newOwnerType
                    if($issuccess)
                    {
                        $result_value = "Successfully Updated"
                        Write-Host "Success.. Device Id: $($device."Device ID") managed owner type is now $newOwnerType"
                    }
                    else 
                    {
                        $result_value = "Failed Update"
                        Write-Host "Failed to update..  Device Id: $($device."Device ID") was not updated"
                    }
                }
                else 
                {
                    $result_value = "No Action"
                    Write-Host "Device Id: $($device."Device ID") is managed by $newOwnerType. No actions will be taken"
                }
            }
            else 
            {
                $result_value = "Failed GET"
                Write-Host "Failed to Get Device Information..  Device Id: $($device."Device ID")"
            }
            $robj = @{
                "Device ID" = $device."Device ID"
                "Device name" = $device."Device name"
                "IMEI" = $device.IMEI
                "Result" = $result_value
            }
            $results.Add((New-Object PSObject -Property $robj)) 
        }
        Write-Host "Exporting Results"

        $resultcsv_filename = "$(Get-Date -Format "yyyyMMdd-HHmmss.ffff").csv"
        $result_full_path = "$($appsettings.ResultFolderPath)$($path_sep)$($resultcsv_filename)"
        Write-Host "Exporting results to file: $($result_full_path)"
        $results | Export-Csv -NoTypeInformation -Path $result_full_path -Delimiter $appsettings.SourceCSVDemiliter -UseQuotes AsNeeded -Encoding utf8

        Write-Host "Done"
    }
    catch{
        Write-Error "Unhandled Exception occured"
        Write-Error $_.Exception.Message
        Write-Error "Stack Trace:"
        Write-Error $_.ScriptStackTrace
        Write-Error "Error Details:"
        Write-Error $_.ErrorDetails
        # $_ | Format-List -Force
    }
    
}