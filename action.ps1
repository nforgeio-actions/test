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

# NOTE: We're using the LiquidTestReports.Markdown nuget package to generate
#       the test output:
#
#       https://dev.to/kurtmkurtm/testing-net-core-apps-with-github-actions-3i76
#       https://github.com/kurtmkurtm/LiquidTestReports

$ncRoot = $env:NC_ROOT

if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
{
    throw "Runner Config: neonCLOUD repo is not present."
}

$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")

Push-Location $ncPowershell
. ./includes.ps1
Pop-Location

# Perform the operation.  Note that we're assuming that a code build has already been
# performed for the Release configuration via a previous [nforgeio-actions/build] 
# action step.

# Read the inputs.

$repo        = Get-ActionInput "repo"
$testLogPath = Get-ActionInput "test-log-path" $true

try
{
    # Delete any existing test log file.
      
    if ([System.IO.File]::Exists($testLogPath))
    {
        [System.IO.File]::Delete($testLogPath)
    }

    # Determine the solution path for the repo.

    Switch ($repo)
    {
        ""
        {
            throw "[inputs.repo] is required."
        }
          
        "neonCLOUD"
        {
            $solutionPath = [System.IO.Path]::Combine($env:NC_ROOT, "neonCLOUD.sln")
            Break
        }
          
        "neonKUBE"
        {
            $solutionPath = [System.IO.Path]::Combine($env:NF_ROOT, "neonKUBE.sln")
            Break
        }
          
        "neonLIBRARY"
        {
            throw "[neonLIBRARY] build is not implemented."
            Break
        }
          
        "cadence-samples"
        {
            throw "[cadence-samples] build is not implemented."
            Break
        }
          
        "temporal-samples"
        {
            throw "[temporal-samples] build is not implemented."
            Break
        }
          
        default
        {
            throw "[$repo] is not a supported repo."
            Break
        }
    }

    # Run the tests.

    dotnet test $solutionPath --logger "liquid.md;File=$testLogPath"
    $success = $?

    # Set the outputs.

    if ($success)
    {
        Set-ActionOutput "success" "true"
    }
    else
    {
        Set-ActionOutput "success" "false"
    }
}
catch
{
    Set-ActionOutput "success" "false"
    return
}

Set-ActionOutput "success" "true"
