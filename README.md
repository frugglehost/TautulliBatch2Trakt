<br />
<p align="center">
  <a href="https://github.com/Generator/tautulli2trakt">
    <img src="logo.png" alt="Logo In The Works" width="80" height="80">
  </a>

  <h3 align="center">Tautulli Batch 2 Trakt</h3>

</p>

<!-- TABLE OF CONTENTS -->
## Table of Contents

* [Description](#description)
* [Getting Started](#getting-started)
   * [Prerequisites](#prerequisites)
   * [Installation](#installation)
     * [Script Setup](#script-setup)
     * [Tautulli](#tautulli)
     * [Script Settings](#script-settings)
* [Usage](#usage)
* [License](#license)
* [Similar Projects](#similar-projects)

## Description: 
Powershell script to send Tautulli notificaions for multiple users to Trakt.

## Getting Started
### Prerequisites
Windows only  

### Installation
    CD "<Enter Install Path>"
    Invoke-WebRequest https://raw.githubusercontent.com/frugglehost/TautulliBatch2Trakt/master/TautulliBatch2Trakt.ps1 -OutFile TautulliBatch2Tra22kt.ps1
    ICACLS "TautulliBatch2Trakt.ps1" /grant:r "Everyone:(F)" /C

### Script Setup
Create a new application https://trakt.tv/oauth/applications  
Add the follow settings:

**Name:** `TautulliBatch2Trakt`  
**Redirect uri:** `urn:ietf:wg:oauth:2.0:oob`  
**Permissions:** `/scrobble`


**Save the Client ID and Client Secret**

Run script for initial setup and follow instructions  
```
CD "<Enter Install Path>"
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process
# Press "Yes", Once the powershell window is closed the settings will revert back.
.\TautulliBatch2Trakt.ps1 -setup
```

The script will automaticly copy the code for you to enter into Trakt.



### Tautulli

#### Add Script
- `Settings` > `Notification Agents` > `Add a Notification Agent` > `Script`

### Script Settings

#### Configuration
- **Script Folder**
  - `<script path location>`
- **Script File**
  - `TautulliBatch2Trakt.ps1`

#### Triggers
- Playback Start 
- Playback Stop
- Playback Pause
- Playback Resume
- Watched 

#### Arguments
- Playback Start / Playback Resume :  
`-m {media_type} -s "{show_name}" -M "{title}" -y "{year}" -t "{thetvdb_id}" -i "{imdb_id}" -S {season_num} -E {episode_num} -P {progress_percent} -a start -PlexUser {username}`  

- Playback Stop / Watched :  
`-m {media_type} -s "{show_name}" -M "{title}" -y "{year}" -t "{thetvdb_id}" -i "{imdb_id}" -S {season_num} -E {episode_num} -P {progress_percent} -a stop -PlexUser {username}` 

- Playback Pause :   
`-m {media_type} -s "{show_name}" -M "{title}" -y "{year}" -t "{thetvdb_id}" -i "{imdb_id}" -S {season_num} -E {episode_num} -P {progress_percent} -a pause -PlexUser {username}`


## Usage
```
-setup              Setup aplication
-reset              Reset settings and revoke token

-m                  Media type (movie, show, episode)
-a                  Action (start, pause, stop)
-s                  Name of the TV Series
-M                  Name of the Moviename
-y                  Year of the movie/TV Show
-S                  Season number
-E                  Episode number
-t                  TVDB ID
-i                  IMDB ID
-P                  Percentage progress (Ex: 10.0)
-PlexUser           The Plex username
-refreshToken       Refreshes the Trakt token 
```

## FAQ & Troubleshooting
* [Frequently Asked Questions](TBD)  
* [Troubleshooting](TBD)

## License
Distributed under the GPL License.

## Similar Projects 

- https://github.com/JvSomeren/tautulli-watched-sync   
- https://github.com/xanderstrike/goplaxt  
- https://github.com/gazpachoking/trex  
- https://github.com/dabiggm0e/plextrakt  
- https://github.com/trakt/Plex-Trakt-Scrobbler
- https://github.com/Generator/tautulli2trakt
