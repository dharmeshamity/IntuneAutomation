<#
.SYNOPSIS
Converts devices to company managed devices. 
.DESCRIPTION
This script will take Source CSV file with devices. For each device in the CSV file, the script will verify if the device is managed by the company. 
If not, it will update the device to be managed by the comany.

.PARAMETER Environment
Accepts DEV, TEST, PRODUCTION.  
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
    [Parameter(Mandatory=$false)]
    [switch]
    $RefreshCredentials = $false,
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
    $runid = Get-Date -Format "yyyyMMdd-HHmmss.ffff"
    $Environment = $Environment.ToUpper()
    Write-Host "Run Identifier for this execution: $runid"
    $intuneAppDataPath = "$([System.Environment]::GetFolderPath('LocalApplicationData'))$($path_sep)IntuneAutomation$($path_sep)"
    $logFile = "$($intuneAppDataPath)$($runid).log"
    Write-Host "All Logs displayed will be also be written to the below transcription path as specified below"
    Start-Transcript -UseMinimalHeader -Path $logFile

    try{
        Write-Host "Begin"

        $appsettings = Initialize-IAAppSettings -Environment $Environment -path_seperator $path_sep

        if(-not (Test-Path($appsettings.ResultFolderPath))) {
            Write-Warning "Result path is not found. Trying to create.."
            New-Item -Path $appsettings.ResultFolderPath -ItemType Directory
            Write-Host "Created Result Path"
        }
        
        if (-not (Test-Path($appsettings.ArchiveFolderPath))) {
            Write-Warning "Archive Path is not found. Trying to create archive folder"
            New-Item -Path $appsettings.ArchiveFolderPath -ItemType Directory
            Write-Host "Created Archive Path"
        }

        If(-not (Test-Path($appsettings.SourceFolderPath)))
        {
            Throw "Source Folder not found or cannot access. Cannot continue"
        }

        $MSGraphAPICredential = Get-IAMSGraphAPICredential -Environment $Environment -IntuneAppDataFolderPath $intuneAppDataPath -NeedRefresh $RefreshCredentials

        $source_files = Get-ChildItem -Path "$($appsettings.SourceFolderPath)" -Include "*$($appsettings.SourceFileExtention)" -Recurse  -File
        $filesCount = ($source_files | Measure-Object).Count
        If($filesCount -eq 0)
        {
            Write-Host "No Source files found. Nothing to do.."
            Return
        }
        $index = 0
        $auth_token = $null
        $auth_response = $null
        $expires_on = 0
        ForEach ($source_file in $source_files)
        {
            Write-Host "Processing File $($index + 1) of $filesCount.."
            Write-Host "Currently processing file: $($source_file.Name)"

            $devices = $source_file | Import-csv -Delimiter $appsettings.SourceCSVDemiliter
            $results = New-Object -TypeName "System.Collections.ArrayList"
            ForEach ($device in $devices) 
            {
                $dt_unix_seconds = [DateTimeOffset]::UtcNow.AddSeconds(120).ToUnixTimeSeconds()
                if([string]::IsNullOrEmpty($auth_token) -or ($dt_unix_seconds -gt $expires_on))
                {
                    $auth_response = Get-IAAuthenticationToken -MSGraphAuthenticationEndpoint $appsettings.MSGraphApiAuthenticationEndpoint -MSGraphClientId $appsettings.MSGraphApiClientId -MSGraphAPICredential $MSGraphAPICredential
                    $auth_token = $auth_response.access_token
                    $expires_on = [long]$auth_response.expires_on
                }
                If([string]::IsNullOrEmpty($auth_token)) 
                {
                    Throw "Authentication to MS Graph API failed. Cannot continue"
                }
                Write-Information "Successfully received auth token"

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
                            $newOwnerType = $owner_type
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
                    Write-Warning "Device Id: $($device."Device ID") not found"
                }
                
                $robj = @{
                    "Result" = $result_value
                    "Device ID" = $device."Device ID" 
                    "Managed Device Owner Type" = $device_info ? ($newOwnerType -eq 'company' ? 'Corporate' : $newOwnerType)  : ""
                    "Email Address" = $device_info.emailAddress ? $device_info.emailAddress : ""
                    "User Display Name" = $device_info.userDisplayName ? $device_info.userDisplayName : ""
                    "Model" = $device_info.model ? $device_info.model : ""
                    "Manufacturer" = $device_info.manufacturer ? $device_info.manufacturer : ""
                    "IMEI" = $device_info.imei ? $device_info.imei : ""
                    "Device name" = $device_info.deviceName ? $device_info.deviceName : ""
                    "Serial Number" = $device_info.serialNumber ? $device_info.serialNumber : ""
                    "Phone Number" = $device_info.phoneNumber ? $device_info.phoneNumber : ""
                    "OS + OS Version" =  $device_info ? "$($device_info.operatingSystem) Version: $($device_info.osVersion)"  : ""
                }

                $results.Add((New-Object PSObject -Property $robj)) | Out-Null
            }
            Write-Host "Exporting Results"

            $resultcsv_filename = "results-$($source_file.BaseName)-$($runid).csv"
            $result_full_path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$($appsettings.ResultFolderPath)$($path_sep)$($resultcsv_filename)")
            Write-Host "Exporting results to file: $($result_full_path)"
            $results |
                Select-Object "Result", "Device ID", "Managed Device Owner Type", "Email Address", "User Display Name", "Model", "Manufacturer", "IMEI", "Device name", "Serial Number", "Phone Number", "OS + OS Version" |
                Export-Csv -NoTypeInformation -Path $result_full_path -Delimiter $appsettings.SourceCSVDemiliter -UseQuotes AsNeeded -Encoding utf8
            
            $archive_filename = "archive-$($source_file.BaseName)-$($runid)$($source_file.Extension)"
            $archive_full_path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$($appsettings.ArchiveFolderPath)$($path_sep)$($archive_filename)")
            Write-Host "Moving the source file to archive folder. Archive FileName: $archive_full_path"
            Move-Item -Path $source_file.FullName -Destination $archive_full_path -Force

            $index = $index + 1
        }

        Write-Host "Done.."
    }
    catch {
        Write-Host "Inside catch"
        $msg = $_ | Select-Object -Property ScriptStackTrace -ExpandProperty Exception | Format-List ScriptStackTrace, Message | Out-String
        Write-Error $msg
    }
    finally {
        Stop-Transcript 
    }
       
}
end {
    
}