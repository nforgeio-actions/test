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

$repo          = Get-ActionInput "repo" $true
$resultsFolder = Get-ActionInput "results-folder" $true

try
{
    # Delete any existing test results folder and then create a fresh folder.
      
    if ([System.IO.File]::Exists($resultsFolder))
    {
        [System.IO.File]::Delete($resultsFolder)
    }

    [System.IO.Directory]::CreateDirectory($resultsFolder)

    # Determine the solution path for the repo as well as the paths to
    # test project folders.
    
    # NOTE: These lists will need to be manually maintained as test
    #       projects are added or deleted.
    
    $testProjectFolders = @()

    Switch ($repo)
    {
        ""
        {
            throw "[inputs.repo] is required."
        }
          
        "neonCLOUD"
        {
            $solutionPath = [System.IO.Path]::Combine($env:NC_ROOT, "neonCLOUD.sln")
            $testRoot     = [System.IO.Path]::Combine($env:NC_ROOT, "Test")

            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Cloud.Desktop")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Enterprise.Kube")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.nuget-versioner")
            Break
        }
          
        "neonKUBE"
        {
            $solutionPath = [System.IO.Path]::Combine($env:NF_ROOT, "neonKUBE.sln")
            $testRoot     = [System.IO.Path]::Combine($env:NF_ROOT, "Test")

            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Cadence")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Cadence.net")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Cassandra")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Common")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Common.net")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Couchbase")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Cryptography")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Cryptography.net")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Deployment")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Kube")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.ModelGen")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.ModelGenCli")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Postgres")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Service")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Temporal")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Temporal.net")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Web")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Xunit")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.YugaByte")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.NeonCli")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.RestApi")
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test_Identity")
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

    # Delete all of the project test result folders.

    ForEach ($projectFolder in $testProjectFolders)
    {
        $projectResultFolder = [System.IO.Path]::Combine($projectFolder, "TestResults")

        if ([System.IO.Directory]::Exists($projectResultFolder))
        {
            [System.IO.Directory]::Delete($projectResultFolder, $true)
        }
    }

    # Run the solution tests.

    dotnet test $solutionPath --logger "liquid.md"
    $success = $?

    # Copy all of the test results from the folders where they were
    # generated to the results folder passed to the action.  Note that
    # we're going to rename each file to: PROJECT-NAME.md.

    function RenameAndCopy
    {
        [CmdletBinding()]
        param (
            [Parameter(Position=0, Mandatory=$true)]
            [string]$projectFolder
        )

        $projectName    = [System.IO.Path]::GetFileName($projectFolder)
        $resultsPattern = [System.IO.Path]::Combine($projectFolder, "TestResults", "*.md")

        dir "$projectFolder\TestResults\" | rename-item -NewName {$_.name -replace "*.md","$projectName.md"}
        Copy-Item -Path $resultsPattern -Destination $resultsFolder
    }

    ForEach ($projectFolder in $testProjectFolders)
    {
        RenameAndCopy $projectFolder
    }

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
    Write-ActionException $_
    Set-ActionOutput "success" "false"
    return
}

Set-ActionOutput "success" $success
