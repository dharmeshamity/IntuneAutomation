function Initialize-IAAppSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEV", "TEST", "PRODUCTION")]
        [string]
        $Environment,
        [Parameter(Mandatory)]
        [string]
        $path_seperator
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

function Get-IAMSGraphAPICredential {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("DEV", "TEST", "PRODUCTION")]
        [string]
        $Environment,
        [Parameter(Mandatory=$true)]
        [string]
        $IntuneAppDataFolderPath,
        [Parameter(Mandatory = $true)]
        [bool]
        $NeedRefresh
    )
    
    process {
        $credential_file = "$($IntuneAppDataFolderPath)credentials$($path_sep)msgraphapi-credentials.$($Environment).json"
        If(-not (Test-Path($credential_file)))
        {
            Write-Warning "Credentials file not found. Trying to create."
            New-Item -Path $credential_file -ItemType File -Force -ErrorAction Stop | Out-Null
            Write-Host "MS Graph API Credential File created"
        }
        
        $credentials = Get-Content $credential_file | ConvertFrom-Json -Depth 100 -AsHashtable
        if(-not $credentials) {
            $credentials = @{}
        }
        if($NeedRefresh -or $credentials.ContainsKey("credential") -eq $false) {
            $credentials.Clear()
            $apiCredentials = Get-Credential -Message "Please provide credentials for MS Graph API"
            $credentials["credential"] =  @{
                UserName = $apiCredentials.UserName
                Password = $apiCredentials.Password | ConvertFrom-SecureString
            }
            $credentials | ConvertTo-Json -depth 100 | Set-Content $credential_file
            Write-Warning "Saved new credentials to $credential_file"
        }
        Write-Host "Reading the MS Graph API Credential file"
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $credentials["credential"].UserName, ($credentials["credential"].Password | ConvertTo-SecureString)
        return $cred
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
        $body = @{
            resource = "https://graph.microsoft.com/"
            client_id = $MSGraphClientId
            grant_type = 'password'
            username = $MSGraphAPICredential.UserName
            password = $plainTextPassword
            scope = 'user_impersonation'
        }
        
        # Invoke POST method with constructed body
        $auth_response = Invoke-RestMethod -ContentType 'application/x-www-form-urlencoded' -Uri $MSGraphAuthenticationEndpoint -Method POST -Form $body -SkipHttpErrorCheck -StatusCodeVariable "responseStatusCode"

        if($responseStatusCode -and ($responseStatusCode -gt 299 -or $responseStatusCode -lt 200))
        {
            if($auth_response)
            {
                #Write-Error "Error: Authentication Failed with HTTP STATUS CODE: $($responseStatusCode)`n$($auth_response | Out-String)" -ErrorAction Stop -Category AuthenticationError
                 $expmsg = "Error: Authentication Failed with HTTP STATUS CODE: $($responseStatusCode)`n$($auth_response | Out-String)"
                 Throw $expmsg
            }
            #New-Object -TypeName System.ApplicationException -ArgumentList ([string]"Error: Authentication Failed with HTTP STATUS CODE: $responseStatusCode")
        }
        
        if($auth_response.access_token)
        {
            return $auth_response    
        }
        Throw "Error: Token was empty. HTTP STATUS CODE: $responseStatusCode"
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
        $response = Invoke-RestMethod -Headers $headers -Method Get -Uri "$($endpoint)/$($MSGraphDeviceId)" -StatusCodeVariable "returnStatusCode" -SkipHttpErrorCheck

        if($returnStatusCode -eq 200){
            return $response
        }
        if($returnStatusCode -eq 404) {
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