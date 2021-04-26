#------------------------------------------------------------------------------
# FILE:         action.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

# Verify that we're running on a properly configured neonFORGE jobrunner 
# and import the deployment and action scripts from neonCLOUD.

# NOTE: This assumes that the required [$NC_ROOT/Powershell/*.ps1] files
#       in the current clone of the repo on the runner are up-to-date
#       enough to be able to obtain secrets and use GitHub Action functions.
#       If this is not the case, you'll have to manually pull the repo 
#       first on the runner.

$ncRoot = $env:NC_ROOT

if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
{
    throw "Runner Config: neonCLOUD repo is not present."
}

$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")

Push-Location $ncPowershell
. ./includes.ps1
Pop-Location

# Loads an environment variable into the current job environment.

function LoadVariable
{
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$variable
    )

    $value = [System.Environment]::GetEnvironmentVariable($variable)

    if ([System.String]::IsNullOrEmpty($value))
    {
        throw "The [$variable] environment variable does not exist."
    }

    Set-ActionOutput $variable $value
}

# COMPUTERNAME is a special case

$computername = [System.Net.Dns]::GetHostName()
Set-ActionOutput "COMPUTERNAME" $computername

# Load the environment variables

LoadVariable NF_REPOS
LoadVariable NF_BUILD
LoadVariable NF_CACHE
LoadVariable NF_CODEDOC
LoadVariable NF_ROOT
LoadVariable NF_SAMPLES_CADENCE
LoadVariable NF_SNIPPETS
LoadVariable NF_TEMP
LoadVariable NF_TEST
LoadVariable NF_TOOLBIN

LoadVariable NC_ACTIONS_ROOT
LoadVariable NC_BUILD
LoadVariable NC_CACHE
LoadVariable NC_NUGET_DEVFEED
LoadVariable NC_NUGET_VERSIONER
LoadVariable NC_REPOS
LoadVariable NC_ROOT
LoadVariable NC_TEMP
LoadVariable NC_TEST
LoadVariable NC_TOOLBIN

# When the action has access to DEVBOT's master 1Password, persist the password
# to the MASTER-PASSWORD environment variable and also load useful common 
# secrets into the process environment and job environments.

$masterPassword = Get-ActionInput "master-password"

if ([System.String]::IsNullOrEmpty($masterPassword))
{
    $masterPassword = $env:MASTER_PASSWORD
}

if (![System.String]::IsNullOrEmpty($masterPassword))
{
    [System.Environment]::SetEnvironmentVariable("MASTER_PASSWORD", $masterPassword)

    # Reads a 1Password secret and adds it to the process and
    # job environments.

    function LoadSecret
    {
        [CmdletBinding()]
        param (
            [Parameter(Position=0, Mandatory=$true)]
            [string]$variable,
            [Parameter(Position=1, Mandatory=$true)]
            [string]$secretName
        )

        $value = GetSecretValue -name $secretName -masterPassword $masterPassword -nullOnNotFound $false

        if (![System.String]::IsNullOrEmpty($value))
        {
            [System.Environment]::SetEnvironmentVariable($variable, $value)
            Set-ActionOutput $variable $value
        }
    }

    LoadSecret "AWS_ACCESS_KEY_ID"     "AWS_ACCESS_KEY_ID[password]"
    LoadSecret "AWS_SECRET_ACCESS_KEY" "AWS_SECRET_ACCESS_KEY[password]"
    LoadSecret "DOCKER_USERNAME"       "DOCKER_LOGIN[username]"
    LoadSecret "DOCKER_PASSWORD"       "DOCKER_LOGIN[password]"
    LoadSecret "GITHUB_USERNAME"       "GITHUB_LOGIN[username]"
    LoadSecret "GITHUB_PASSWORD"       "GITHUB_LOGIN[password]"
    LoadSecret "GITHUB_PAT"            "GITHUB_PAT[password]"
    LoadSecret "NEONFORGE_USERNAME"    "NEONFORGE_LOGIN[username]"
    LoadSecret "NEONFORGE_PASSWORD"    "NEONFORGE_LOGIN[password]"
    LoadSecret "NUGET_PUBLIC_KEY"      "NUGET_PUBLIC_KEY[password]"
    LoadSecret "NUGET_VERSIONER_KEY"   "NUGET_VERSIONER_KEY[value]"
    LoadSecret "NUGET_DEVFEED_KEY"     "NUGET_DEVFEED_KEY[value]"
    LoadSecret "TEAM_DEVOPS_CHANNEL"   "TEAM_DEVOPS_CHANNEL[value]"
}

