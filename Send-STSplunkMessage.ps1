#requires -version 2

# Author: Joakim Borger Svendsen, 2016-present.
# Svendsen Tech. MIT license.
# Send-STSplunkMessage. GitHub here: https://github.com/EliteLoser/Send-SplunkMessage

# I make an attempt at semantic versioning...

$Script:Version = "1.0.0" # 2021-05-31
function GetDomain {

    $ErrorActionPreference = "Stop"
    $Domain = 'unknown_domain'

    try {
        # Previously used method, would occasionally fail and is resource-expensive and slow, I think.
        #$Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Forest.ToString()
        # Will fail on non-Windows PS. Will then be set to 'unknown_domain'.
        $Domain = Get-WmiObject -Class Win32_ComputerSystem -Property Domain -ErrorAction Stop |
            Select-Object -ExpandProperty Domain -ErrorAction Stop
    }
    catch {
        $Domain = 'unknown_domain'
        Write-Warning "Couldn't retrieve domain. Domain set to: '$Domain'."
    }

    $ErrorActionPreference = "Continue"
    return $Domain

}

function Send-STSplunkMessage {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$True)] $InputObject,
        #[String] $Severity = "Information",
        [String] $Source = 'powershell.splunkmessage',
        [String] $SourceType = 'powershell.splunkmessage.testing',
        [String] $Index = 'test',
        [String] $SplunkHECToken = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
        [String[]] $SplunkUri = @(),
        [Switch] $VerboseJSONCreation = $false,
        [Switch] $CoerceNumberStrings = $false,
        [Switch] $Proxy = $false
    )
    Begin {
        if (($PSVersionTable.PSVersion.Major -eq 2) -or $CoerceNumberStrings) {
            # PSv2-compatible "$PSScriptRoot".
            $MyHome = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
            try {
                $ErrorActionPreference = 'Stop'
                # ConvertTo-STJson, https://github.com/EliteLoser/ConvertTo-Json
                # Svendsen Tech. MIT License. Copyright Joakim Borger Svendsen / Svendsen Tech. 2016-present.
                . "$MyHome\ConvertTo-STJson.ps1"
            }
            catch {
                Write-Error -ErrorAction Stop -Message "This script depends on 'ConvertTo-STJson.ps1' in the same folder as the calling script on PowerShell version 2 - and also if you specify the parameter -CoerceNumberStrings. See https://github.com/EliteLoser/ConvertTo-Json"
            }
            $ErrorActionPreference = 'Continue'
        }
        
        if ($SplunkUri.Count -eq 0) {
            # Using default list.
            Write-Verbose -Message "No Splunk forwarder URI specified. Using default list if one has been hardcoded in the source code."
            $SplunkUri = @() # list of strings with URLs to Splunk forwarders... I know this is esoteric, but kind of "real world"?
        }
        if ($SplunkUri.Count -eq 0) {
            # Fail and halt if no Splunk forwarders are specified (or hardcoded above).
            Write-Error -ErrorAction  Stop -Message "No Splunk forwarder URI specified. No default list hardcoded in source code. Exiting. Please specify splunk forwarder(s) using the parameter -SplunkUri."
        }
        Write-Verbose -Message "Choosing from the following Splunk URI(s):`n$($SplunkUri -join ""`n"")"
        $Domain = GetDomain
        [Bool] $GotGoodForwarder = $False
    }

    Process {
        Write-Verbose -Message "Trying to log to splunk. Source: '$Source'. SourceType: '$SourceType'. Index: '$Index'."
        # Code for PSv2 and up ...
        # http://www.powershelladmin.com/wiki/Convert_between_Windows_and_Unix_epoch_with_Python_and_Perl # using diff logic
        :FORWARD while ($True) {
            try {
                $ErrorActionPreference = "Stop"
                if ($GotGoodForwarder -eq $False) {
                    if ($SplunkUri.Count -eq 0) {
                        Write-Warning -Message "None of the Splunk forwarders worked. Last recorded error message in system buffer is: $(
                            $Error[0].Exception.Message)"
                        break FORWARD
                    }
                    $CurrentSplunkUri = $SplunkUri | Get-Random -Count 1
                    $SplunkUri = $SplunkUri | Where-Object { $_ -ne $CurrentSplunkUri } # pop...
                    Write-Verbose -Message "Splunk URIs left:`n$($SplunkUri -join ""`n"")"
                }
                if (($PSVersionTable.PSVersion.Major -eq 2) -or $CoerceNumberStrings) {
                    $Json = ConvertTo-STJson -InputObject $InputObject -Verbose:$VerboseJSONCreation -CoerceNumberStrings:$CoerceNumberStrings
                }
                else {
                    $Json = ConvertTo-Json -InputObject $InputObject -Verbose:$VerboseJSONCreation
                }
                if (-not (Get-Variable -Name STSplunkWebClient -ErrorAction SilentlyContinue)) {
                    $STSplunkWebClient = New-Object -TypeName System.Net.WebClient -ErrorAction Stop
                    $STSplunkWebClient.Headers.Add([System.Net.HttpRequestHeader]::Authorization, "Splunk $SplunkHECToken")
                    $STSplunkWebClient.Headers.Add("Content-Type", "application/json")
                    $STSplunkWebClient.Encoding = [System.Text.Encoding]::UTF8
                    if (-not $Proxy) {
                        # Do not use the proxy specified in browser/registry settings.
                        $STSplunkWebClient.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy()
                    }
                }
                $Result = $STSplunkWebClient.UploadString($CurrentSplunkUri, "POST", @"
{
    "time": $([Math]::Floor(([DateTime]::Now - (Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0)).TotalSeconds)),
    "host": "$env:ComputerName.$Domain",
    "source": "$Source",
    "sourcetype": "$SourceType",
    "index": "$Index",
    "event": $Json
}
"@.Trim()
                )
                if ($Result -match ':\s*"Success"') {
                    "Successfully sent event JSON to '$CurrentSplunkUri'."
                    $GotGoodForwarder = $True
                    break FORWARD
                }
                else {
                    Write-Warning -Message "It might not have gone well sending to '$CurrentSplunkUri'. Result looks like this: $Result. Last error in system buffer is: $($Error[0].Exception.Message -replace '[\r\n]+', ' ')"
                    Write-Verbose -Message "This is the 'event JSON' we tried:`n$Json"
                    #$GotGoodForwarder = $False # infinite loop with malformed data, etc., so we can't do that. -Joakim
                    #break FORWARD
                }
            }
            catch {
                Write-Warning -Message "[$([DateTime]::Now.ToString('yyyy\-MM\-dd HH\:mm\:ss'))]. Send-SplunkMessage failed to connect to '$CurrentSplunkUri' with the following error: '$($_ -replace '[\r\n]+', '; ')'"
                Write-Verbose -Message "This is the 'event' JSON we tried:`n$Json"
                # This makes it try another forwarder if a good one suddenly goes bad. Won't retry the formerly good one.
                # For that functionality I need a "once good forwarder cache" and it seems overkill for an obscure scenario?
                $GotGoodForwarder = $False
            }
        }
        Write-Verbose -Message "This is the 'event JSON' we tried:`n$Json"
        $ErrorActionPreference = "Continue"
    }

    End {
        # Do some house-keeping.
        if (Get-Variable -Name STSplunkWebClient -ErrorAction SilentlyContinue) {
            $STSplunkWebClient.Dispose()
            $STSplunkWebClient = $null
        }
        [System.GC]::Collect()
    }
}
