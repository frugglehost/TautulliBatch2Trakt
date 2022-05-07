#    Description:  Notificaion script for Tautulli <https://tautulli.com/> to 
#                  automatically scrobble media to Trakt.tv.
#
#    Contributors: Bassed off of the https://github.com/Generator/tautulli2t
#                  rakt script. 
#
#    Copyright (C) 2022 FruggleHost <FruggleHost+TautulliBatch _AT_ gmail _DOT_ com>
#
#    This program is free software: You can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#    
#    


#############################
## Aplication ISE Commands ##
#############################

#Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process
#Remove-Variable * -ErrorAction SilentlyContinue; Remove-Module *; $error.Clear();

##############################
## Default Global Variables ##
##############################

# Clear the screen for a fresh start.
clear

## OS Detection - Might be used in the future
$OSType=(Get-WmiObject -class Win32_OperatingSystem).Caption

## App info
$APP_VER="0.0.2"
$APP_DATE=Get-Date -UFormat "%Y-%m-%d"


## Script path and names
$SCRIPTFULL=$MyInvocation.MyCommand.Path

$SCRIPTFILE=Split-Path -Path $SCRIPTFULL -Leaf
$SCRIPTNAME=$SCRIPTFILE.TrimEnd(".ps1")
$SCRIPTPATH=Split-Path -Path $SCRIPTFULL
$ScriptData=$SCRIPTPATH + "\" + $SCRIPTNAME + ".data"
$ScriptDebug=$SCRIPTPATH + "\" + $SCRIPTNAME + ".debug" #Only used if present.
$ScriptLog=$SCRIPTPATH + "\" + $SCRIPTNAME + ".log" #Only used if present.

###############
## Functions ##
###############

# Quick check to see if there is a "-" in a arg or not.
function CheckDash([string]$ValuePassed) {
    if ($ValuePassed.StartsWith("-")) {
        return ""
    } else {
        return $ValuePassed
    }
}

# Saves the profile data into the Data (Structured as a JSON)
function saveDataFile (
    [string]$str_PlexUser,
    [string]$str_TRAKT_APP_ID,
    [string]$str_TRAKT_APP_SECRET,
    [string]$str_TRAKT_DEVICE_CODE,
    [string]$str_TRAKT_USER_CODE,
    [string]$str_TRAKT_TOKEN_TYPE,
    [string]$str_TRAKT_SCOPE,
    [string]$str_TRAKT_ACCESS_TOKEN,
    [string]$str_TRAKT_REFRESH_TOKEN,
     [int32]$int_TRAKT_EXPIRES_IN,
     [int32]$int_TRAKT_CREATED_AT,
    [string]$str_DataPath) {


    #Create JSON data on the fly and fill it with info from user input and/or Trakt.
    $NewJSONString= "{ 
        `"PLexUser`" : `""+$str_PlexUser+"`",
        `"client_id`" : `""+$str_TRAKT_APP_ID+"`",
        `"client_secret`" : `""+$str_TRAKT_APP_SECRET+"`",
        `"device_code`" : `""+$str_TRAKT_DEVICE_CODE+"`",
        `"user_code`" : `""+$str_TRAKT_USER_CODE+"`",
        `"access_token`" : `""+$str_TRAKT_ACCESS_TOKEN+"`",
        `"token_type`" : `""+$str_TRAKT_TOKEN_TYPE+"`",
        `"expires_in`" : `""+$int_TRAKT_EXPIRES_IN+"`",
        `"refresh_token`" : `""+$str_TRAKT_REFRESH_TOKEN+"`",
        `"scope`" : `""+$str_TRAKT_SCOPE+"`",
        `"created_at`" : `""+$int_TRAKT_CREATED_AT+"`"
    }"

    $NewPSObject= ConvertFrom-Json -InputObject $NewJSONString
    

    $combined = @()
    #Check if there is an exisiting Data file with user token info.
    if ([System.IO.File]::Exists($ScriptData)) {
        $DataJSON=Get-Content $str_DataPath | ConvertFrom-Json
        
        $DataJSONRows=($DataJSON | measure).count
        for ($i = 0; $i -le $DataJSONRows-1; $i++) {
            if ($DataJSON[$i].PLexUser -ne $PlexUser) { 
                $combined += $DataJSON[$i]
            }
        }


        # Merge data.
        $combined += $NewPSObject
    }else{
        # No merge required pass the variable along.
        $combined=$NewPSObject
    }
    
    
    # Save the token data for resue.
    $combined | ConvertTo-Json -depth 32 | Set-Content -Path $str_DataPath
    Write-Host "The Data file has been updated."

    # Dam... https://www.youtube.com/watch?v=SiMHTK15Pik
    if ([System.IO.File]::Exists($ScriptLog)) { Add-Content $ScriptLog "Status: 9999 - User: $PlexUser - Action: SavedFile - $($($body | ConvertTo-Json) -replace '\s+', '') " }

}


#################
## Args Setter ##
#################

# Loop though all the args to set parameters.
# Native powershell V6 or lower do not tell the between upper or lower case.
$numOfArgs = $args.Length
for ($i=0; $i -lt $numOfArgs; $i++)
{
    Switch -casesensitive ($args[$i]) 
    {
        "-m" {$MediaType=CheckDash($args[$i+1])}
        "-s" {$ShowName=CheckDash($args[$i+1])}
        "-M" {$MovieName=CheckDash($args[$i+1])}
        "-y" {$MediaYear=CheckDash($args[$i+1])}
        "-t" {$TVDB_ID=CheckDash($args[$i+1])}
        "-i" {$IMDB_ID=CheckDash($args[$i+1])}
        "-S" {$Season=CheckDash($args[$i+1])}
        "-E" {$Episode=CheckDash($args[$i+1])}
        "-P" {$Progress=CheckDash($args[$i+1])}
        "-a" {$Action=CheckDash($args[$i+1])}
        "-PlexUser" {$PlexUser=CheckDash($args[$i+1])}
        "-setup" {$RunSetup=$true}
        "-reset" {$RunReset=$true}
        "-refreshToken" {$RunRefresh=$true}
        "-help" {}
    }
}






######################
## Aplication Setup ##
######################

function scriptSetup() { 
    Write-Host "Starting up Setup Procedure."
    $ExpiresSec=[int]0
    while ([string]::IsNullOrEmpty($PlexUser)){
        $PlexUser = Read-Host "Enter the Plex username"
    }

    ## Check that we have a value for the Client ID and Secret.
    while ([string]::IsNullOrEmpty($TRAKT_APPID)) {
        $TRAKT_APPID = Read-Host "Enter Trackt.tv 'Client ID'"
    }
    while ([string]::IsNullOrEmpty($TRAKT_APPSECRET)) {
        $TRAKT_APPSECRET = Read-Host "Enter Trackt.tv 'Client Secret'"
    }

    ## Write the settings to the config.
    if (![string]::IsNullOrEmpty($TRAKT_APPID) -and ![string]::IsNullOrEmpty($TRAKT_APPSECRET)) {
        $ConfigJSON = [PSCustomObject]@{
            TRAKT_APPID     = $TRAKT_APPID
            TRAKT_APPSECRET = $TRAKT_APPSECRET
        }
        

        #Get Device and User Code
        try
        {
            $Uri="https://api.trakt.tv/oauth/device/code"
            $Body = @{ client_id=$TRAKT_APPID }
            $TraktRest=Invoke-WebRequest -Uri $Uri -Method POST -Body $Body
            $TraktRest=$TraktRest.Content | ConvertFrom-Json

            $User_CODE=$TraktRest.user_code
            $ExpiresSec=[int]$TraktRest.expires_in
            

            Write-Host "Autorize the aplication.`n1. Open the URL https://trakt.tv/activate`n2. Copy the temp code $User_CODE (Note it is already in the windows clipboard)`n3. Accept Web prompts.`n`nThis Screen will auto refresh untill the token is accepted.`n  There are $ExpiresSec seconds untill the code $User_CODE expires.`n`n"
            Set-Clipboard -Value $User_CODE
            Start-Process "https://trakt.tv/activate"
            
            
            $Dots=""
            $Adding=$true
            $Stats=""
            $TraktOAuth=$null
            #Lets loop untill the timer goes out or a token is taken.
            while($Stats -ne 200 -and $Stats -ne 409 -and $ExpiresSec -gt 0)
            {
                try {
                    ## Now we have our app allowed get token
                    $Uri="https://api.trakt.tv/oauth/device/token"
                    $Body = @{
                        code=$TraktRest.device_code
                        client_id=$TRAKT_APPID
                        client_secret=$TRAKT_APPSECRET
                    }
                    $TraktOAuth=Invoke-WebRequest -Uri $Uri -Method POST -Body $Body
                    $Stats=[INT]$TraktOAuth.StatusCode

                    $TraktOAuth=$TraktOAuth.Content | ConvertFrom-Json
                    Write-Host "Status: $Stats Sucess"

                    if ([System.IO.File]::Exists($ScriptLog)) { Add-Content $ScriptLog "Status: $Stats - User: $PlexUser - Action: $Action - $($($body | ConvertTo-Json) -replace '\s+', '') " }
                
                } catch {
                    
                    # Get the web status code.
                    $Stats=[INT]$_.Exception.Response.StatusCode.value__ 

                    # Add dots to string for end user message.
                    if ($Dots.Length -gt 15) { $Adding = $false }
                    if ($Dots.Length -lt 1) { $Adding = $true }

                    if ($Adding) { $Dots="."+$Dots } else { $Dots=$Dots.Substring(1) }

                    # Count down and send display to end user.
                    $ExpiresSec=$ExpiresSec-5
                    Write-Host "Status: $Stats Time Left: $ExpiresSec $Dots"
                    start-sleep -s 5
                }

            }

            #Set the variables
            $TRAKT_APPID    =    $TRAKT_APPID
            $TRAKT_APPSECRET=    $TRAKT_APPSECRET
            $DeviceCode     =    $TraktRest.device_code
            $UserCode       =    $TraktRest.user_code
            $OTokentype     =    $TraktOAuth.token_type
            $OScope         =    $TraktOAuth.scope
            $OAccessToken   =    $TraktOAuth.access_token
            $ORefreshToken  =    $TraktOAuth.refresh_token
            $OExpiresIn     =    [int32]$TraktOAuth.expires_in
            $OCreatedAt     =    [int32]$TraktOAuth.created_at

            #Save the Data
            saveDataFile $PlexUser $TRAKT_APPID $TRAKT_APPSECRET $DeviceCode $UserCode $OTokentype $OScope $OAccessToken $ORefreshToken $OExpiresIn $OCreatedAt $ScriptData

        } catch {
            # Dig into the exception to get the Response details.
            # Note that value__ is not a typo.
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        }
    } else {
        Write-Host "Missing Trakt Client ID or Secret.`nPersonaly I have no idea why though."
    }
    Exit
}

###################
## Refresh Token ##
###################

function refreshToken() {
    
    try {

    # Check if we have a username to refresh the record.
    if (![string]::IsNullOrEmpty($PlexUser)) {
        

        # Search the Data file for the Plex username.
        $DataJSON=Get-Content $ScriptData | ConvertFrom-Json

        
        # Loop though Data file for user.
        $PlexUserData= @()
        $DataJSONRows=$DataJSON.Count
        for ($i = 0; $i -le $DataJSONRows-1; $i++) {
            if ($DataJSON[$i].PLexUser -eq $PlexUser) { 
                $PlexUserData += $DataJSON[$i]
            }
        }

        if ($PlexUserData.Count -gt 0){

            #Set the variables
            $TRAKT_APPID    =    $PlexUserData[0].client_id
            $TRAKT_APPSECRET=    $PlexUserData[0].client_secret
            $DeviceCode     =    $PlexUserData[0].device_code
            $UserCode       =    $PlexUserData[0].user_code
            $OTokentype     =    $PlexUserData[0].token_type
            $OScope         =    $PlexUserData[0].scope
            $OAccessToken   =    $PlexUserData[0].access_token
            $ORefreshToken  =    $PlexUserData[0].refresh_token
            $OExpiresIn     =    [int32]$PlexUserData[0].expires_in
            $OCreatedAt     =    [int32]$PlexUserData[0].created_at


            $Uri="https://api.trakt.tv/oauth/token"
            $Body = @{
                refresh_token=$ORefreshToken
                client_id=$TRAKT_APPID
                client_secret=$TRAKT_APPSECRET
                redirect_uri="urn:ietf:wg:oauth:2.0:oob"
                grant_type="refresh_token"
            }
        
            $TraktOAuth=Invoke-WebRequest -Uri $Uri -Method POST -Body $Body
            $Stats=[INT]$TraktOAuth.StatusCode
        
            $TraktOAuth=$TraktOAuth.Content | ConvertFrom-Json

            $OTokentype     =    $TraktOAuth[0].token_type
            $OScope         =    $TraktOAuth[0].scope
            $OAccessToken   =    $TraktOAuth[0].access_token
            $ORefreshToken  =    $TraktOAuth[0].refresh_token
            $OExpiresIn     =    [int32]$TraktOAuth[0].expires_in
            $OCreatedAt     =    [int32]$TraktOAuth[0].created_at


            #Save the Data
            saveDataFile $PlexUser $TRAKT_APPID $TRAKT_APPSECRET $DeviceCode $UserCode $OTokentype $OScope $OAccessToken $ORefreshToken $OExpiresIn $OCreatedAt $ScriptData

            if ([System.IO.File]::Exists($ScriptLog)) { Add-Content $ScriptLog "Status: $Stats - User: $PlexUser - Action: $Action - $($($body | ConvertTo-Json) -replace '\s+', '') " }

            }
        } else {
            Write-Host "No user was found to refresh."
        }
    } catch {
        #Collect the status of the failed connection.
        $Stats=[INT]$_.Exception.Response.StatusCode.value__ 
        #Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    }

    Exit

}

function resetToken() {

    while ([string]::IsNullOrEmpty($PlexUser)){
        $PlexUser = Read-Host "Enter the Plex username"
    }

    $combined = @()
    # Check if we have a username to refresh the record.
    if ([System.IO.File]::Exists($ScriptData)) {
        
        $DataJSON=Get-Content $ScriptData | ConvertFrom-Json
        
        $DataJSONRows=($DataJSON | measure).count
        for ($i = 0; $i -le $DataJSONRows-1; $i++) {
            if ($DataJSON[$i].PLexUser -ne $PlexUser) { 
                $combined += $DataJSON[$i]
            }
        }


        # Save the token data for resue.
        if(($combined | measure).count -gt 0) {

            $combined | ConvertTo-Json -depth 32 | Set-Content -Path $ScriptData
            Write-Host "The Data file has been updated."
            if ([System.IO.File]::Exists($ScriptLog)) { Add-Content $ScriptLog "Status: 200 - User: $PlexUser - Action: RemovedData - $($($combined | ConvertTo-Json) -replace '\s+', '') " }
        } else {
            Remove-Item -Path "$ScriptData"
            Write-Host "The Data file has been removed."
            if ([System.IO.File]::Exists($ScriptLog)) { Add-Content $ScriptLog "Status: 201 - User: $PlexUser - Action: DeleatedData - $ScriptData " }
        }

    } else {
        Write-Host "Missing data file: $ScriptData"
        if ([System.IO.File]::Exists($ScriptLog)) { Add-Content $ScriptLog "Status: 404 - User: $PlexUser - Action: MissingData - $ScriptData " }
        exit
    }

}


if ($RunSetup) { scriptSetup }
elseif ($RunRefresh) { refreshToken }
elseif ($RunReset) { resetToken }


$FoundUser=$false
## Find Config file and source it
if ([System.IO.File]::Exists($ScriptData)) {
    Write-Host "Located the Data file."
    $CurrentUnix=[int32]([DateTimeOffset](Get-Date)).ToUnixTimeSeconds()

    #Read the Data file for contents. 
    $DataJSON=Get-Content $ScriptData | ConvertFrom-Json
    
    
    # Loop though Data file for user.
    $PlexUserData= @()
    $DataJSONRows=($DataJSON | measure).Count
    for ($i = 0; $i -le $DataJSONRows-1; $i++) {
        if ($DataJSON[$i].PLexUser -eq $PlexUser) { 
            $PlexUserData += $DataJSON[$i]
        }
    }
    
    # This should not ever happen but if we have different inputs all adding to the Data file.
    if ($PlexUserData.Count -gt 1) { Write-Host "Warnning $Count records found for the same user $PlexUser " }

    #Look at the last record of data found for the user.
    if ($PlexUserData.Count -gt 0) {

        $TRAKT_APPID=$PlexUserData.client_id
        $TRAKT_APPSECRET=$PlexUserData.client_secret
        $DeviceCode=$PlexUserData.device_code
        $UserCode=$PlexUserData.user_code
        $OTokentype=$PlexUserData.token_type
        $OScope=$PlexUserData.scope
        $OAccessToken=$PlexUserData.access_token
        $ORefreshToken=$PlexUserData.refresh_token
        $OExpiresIn=[int32]$PlexUserData.expires_in
        $OCreatedAt=[int32]$PlexUserData.created_at

        # Check if we need to refresh the token.
        if ($OCreatedAt +$OExpiresIn -le $CurrentUnix) {
             Write-Host "Refreshing Token"

             refreshToken
        }
        $FoundUser=$true
        Write-Host "User $PlexUser Found."
    } else {
        Write-Host "No User Found in Data file. $PlexUser"
        $FoundUser=$false
    }



} else {
    scriptSetup
}



##############
## Scrobble ##
##############

#If no user is found there is no need to scrobble
if ($FoundUser) { 
    if (![string]::IsNullOrEmpty($MediaType)) {
        Write-Host "Attempt to Enter data into Trakt." 

        $body=""
        $Stats=""
        if ($MediaType -eq "movie") {
    
            $body = "{`"movie`": {`"title`": `"$MovieName`",`"year`": `"$MediaYear`", `"ids`": {`"imdb`": `"$IMDB_ID`" } }"

        } elseif ($MediaType -eq "show" -or $MediaType -eq "episode") {

            $body = "{`"show`": { `"title`": `"$ShowName`", `"year`": `"$MediaYear`", `"ids`": { `"tvdb`": $TVDB_ID } },`"episode`": { `"season`": $Season, `"number`": $Episode }"
    
        } else {
            Write-Host "Failed to get Media type" + $MediaType

        }

        $body=$body + ",`"progress`": $Progress, `"app_version`": `"$APP_VER`", `"app_date`": `"$APP_DATE`"}"


        $Uri="https://api.trakt.tv/scrobble/"+$Action
        $Headders=@{
            "Content-Type"="application/json"
            "Authorization"="Bearer "+$OAccessToken
            "trakt-api-version"=2
            "trakt-api-key"=$TRAKT_APPID
        }
        $Stats=[INT]0
        try {
            $Scrobble=Invoke-WebRequest -Uri $Uri -Method POST -Body $Body -Headers $Headders
            $Stats=[INT]$Scrobble.StatusCode
	        if ([System.IO.File]::Exists($ScriptDebug)) {
                    $ScrobbleDebug=$Scrobble.Content | ConvertFrom-Json
                    $ScrobbleText = $ScrobbleDebug | ConvertTo-Json -depth 32
                    Add-Content $ScriptDebug $ScrobbleText
	        }
        } catch {
            # Dig into the exception to get the Response details.
            # Note that value__ is not a typo.
            $Stats=[INT]$_.Exception.Response.StatusCode.value__ 
            #Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        }

        Write-Host "Status Code:" $Stats

        if ([System.IO.File]::Exists($ScriptLog)) {Add-Content $ScriptLog "Status: $Stats - User: $PlexUser - Action: $Action - $body"}

    }
}