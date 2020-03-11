function Initialize-IAAppSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEV", "TEST", "PRODUCTION")]
        [string]
        $Environment,
        [Parameter(Mandatory)]
        [string]
        $path_seperator,
        [Parameter(Mandatory=$false)]
        [Hashtable]
        $AppSettingsOverrides
    )
    
    process {
        try{
            Write-Verbose "Init Application Settings"
            $appsettings = Get-Content -Path ".$($path_seperator)appsettings.$Environment.json" | ConvertFrom-Json
            <#if($AppSettingsOverrides) {
                ForEach($key in $AppSettingsOverrides.Keys) {
                    $appsettings.$key = $AppSettingsOverrides.$key
                }
            }#>
            $appsettings
            Write-Verbose "Done Init Application Settings"
        }
        catch{
            Write-Error "Unable to Init App Settings"
            $_
        }
    }
    
}

function Get-IAAuthenticationToken {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $MSGraphAuthenticationEndpoint,
        [Parameter(Mandatory)]
        [string]
        $MSGraphClientId,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]
        $MSGraphAPICredential
    )
    
    process {
        # Convert secure string to plain text
        $plainTextPassword = $MSGraphAPICredential.Password | ConvertFrom-SecureString -AsPlainText

        # Define body passed in POST method
        $body = "resource={0}&client_id={1}&grant_type={2}&username={3}&password={4}&scope={5}" -f 
                [System.Net.WebUtility]::UrlEncode("https://graph.microsoft.com/"), 
                [System.Net.WebUtility]::UrlEncode($MSGraphClientId),
                [System.Net.WebUtility]::UrlEncode('password'),
                [System.Net.WebUtility]::UrlEncode($MSGraphAPICredential.UserName),
                [System.Net.WebUtility]::UrlEncode($plainTextPassword),
                [System.Net.WebUtility]::UrlEncode('user_impersonation')
        
        $headers = @{
            'Content-Type' = 'application/x-www-form-urlencoded'
        }
        
        # Invoke POST method with constructed body
        $auth_response = Invoke-RestMethod -Headers $headers -Uri $MSGraphAuthenticationEndpoint -Method POST -Body $body
        
        # Return authentication hash table
        return $auth_response.access_token
    }

}

function Get-IAManagedDeviceInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $MSGraphDeviceManagementEndpoint,
        [Parameter(Mandatory)]
        [string]
        $MSGraphAuthToken,
        [Parameter(Mandatory)]
        [string]
        $MSGraphDeviceId
    )
    
    process {
        $headers = @{
            "Authorization" = "Bearer $($MSGraphAuthToken)"
        }
        $endpoint = $MSGraphDeviceManagementEndpoint.Trim().EndsWith("/") ? $MSGraphDeviceManagementEndpoint.Trim().TrimEnd("/") : $MSGraphDeviceManagementEndpoint.Trim()
        try {
            $response = Invoke-RestMethod -Headers $headers -Method Get -Uri "$($endpoint)/$($MSGraphDeviceId)"
            return $response
        }
        catch {
            Write-Error "Unable to Get Device Information for Device ID: $($MSGraphDeviceId). See error details below"
            Write-Error $_.Exception.Message
            Write-Error "Error Details:"
            Write-Error $_.ErrorDetails
            return $null
        }
    }
}

function Update-IAManagedOwnerType {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $MSGraphDeviceManagementEndpoint,
        [Parameter(Mandatory)]
        [string]
        $MSGraphAuthToken,
        [Parameter(Mandatory)]
        [string]
        $MSGraphDeviceId,
        [Parameter(Mandatory)]
        [string]
        $NewOwnerType
    )
        
    process {
        $headers = @{
            "Authorization" = "Bearer $($MSGraphAuthToken)"
            "Content-Type" = "application/json"
        }
        $endpoint = $MSGraphDeviceManagementEndpoint.Trim().EndsWith("/") ? $MSGraphDeviceManagementEndpoint.Trim().TrimEnd("/") : $MSGraphDeviceManagementEndpoint.Trim()
        $body = @{
            managedDeviceOwnerType = $NewOwnerType
        }  | ConvertTo-Json

        try {
            Invoke-RestMethod -Headers $headers -Method Patch -Uri "$($endpoint)/$($MSGraphDeviceId)" -Body $body
            return $true
        }
        catch {
            Write-Error "Unable to update Device Owner Type for Device ID: $($MSGraphDeviceId). See error details below"
            Write-Error $_.Exception.Message
            Write-Error "Error Details:"
            Write-Error $_.ErrorDetails
            return $false
        }        
    }
    
}