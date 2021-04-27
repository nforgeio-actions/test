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
    
    # NOTE: These lists will need to be manually maintained as
    #       test projects are added or deleted.
    
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
    # generated to the results folder passed to the action.  There should
    # only be one results file in eachn directory and we're going to 
    # rename each file to: PROJECT-NAME.md.

    function RenameAndCopy
    {
        [CmdletBinding()]
        param (
            [Parameter(Position=0, Mandatory=$true)]
            [string]$projectFolder
        )

        $projectName          = [System.IO.Path]::GetFileName($projectFolder)
        $projectResultsFolder = [System.IO.Path]::Combine($projectFolder, "TestResults")
        $projectResultFiles   = [System.IO.Directory]::GetFiles($projectResultsFolder, "*.md")
        
        if ($projectResultFiles.Count -eq 0)
        {
            return  # No results for this test project
        }

        Copy-Item -Path $projectResultFiles[0] -Destination $([System.IO.Path]::Combine($resultsFolder, "$projectName.md"))
    }

    ForEach ($projectFolder in $testProjectFolders)
    {
        RenameAndCopy $projectFolder
    }

    # We're using the [nforgeio/test-results] repo to hold the test results so
    # we can include result links in notifications.  The nice thing about using
    # a GitHub repo for this is that GitHub will handle the markdown translation
    # automatically.  Test results are persisted to the [$/reults] folder and
    # will be named like:
    # 
    #       yyyy-MM-ddThh:mm:ssZ-NAME.md
    #
    # where NAME identifies the test project that generated the result file.
    #
    # We're also going to remove files with timestamps older than the integer
    # value from [$/setting-retention-days] to keep a lid on the number of 
    # files that need to be pulled (note that the history will keep growing).

    $testRepoPath      = $env:TR_ROOT
    $testResultsFolder = [System.IO.Path]::Combine($testRepoPath, "results")

    if ([System.String]::IsNullOrEmpty($testRepoPath) -or ![System.IO.Directory]::Exists($testRepoPath))
    {
        throw "[test-results] repo is not configured locally."
    }

    Push-Location $testRepoPath

        # Pull the [test-results] repo and then scan the test results file and remove
        # those with timestamps older than [$/settings-retention-days].

        git pull
        ThrowOnExitCode

        $retentionDaysPath = [System.IO.Path]::Combine($testRepoPath, "settings-retention-days")
        $retentionDays     = [int][System.IO.File]::ReadAllText($retentionDaysPath).Trim()
        $utcNow            = [System.DateTime]::UtcNow
        $minRetainTime     = $utcNow.Date - $retentionDays

        ForEach ($testResultPath in [System.IO.Directory]::GetFiles("$testResultsFolder/*.md"))
        {
            # Extract and parse the timestamp.

            $filename   = [System.IO.Path]::GetFileName($testResultPath)
            $timestring = $filename.SubString(0, 20)    # Extract the "yyyy-MM-ddThh:mm:ssZ" part
            $timestamp  = [System.DateTime]::Parse("o").ToUniversalTime()

            if ($timestamp -lt $minRetainTime)
            {
                [System.IO.File]::Delete($testResultPath)
            }
        }

        # Copy the project test results into the results] folder in the [test-results] repo,
        # renaming the files to be like: 
        #
        #       yyyy-MM-ddThh:mm:ssZ-NAME.md

        $timestamp = $utcNow.ToString("o")

        ForEach ($testResultPath in [System.IO.Directory]::GetFiles("$resultsFolder/*.md"))
        {
            $projectName = [System.IO.Path]::GetFileName($testResultPath)
            $targetPath  = [System.IO.path]::Combine($testResultsFolder, "$timestamp-$projectName.md")

            Copy-Item -Path $testResultPath -Destination $targetPath
        }

        # Commit and push the [test-results] repo changes.

        git add --all
        ThrowOnExitCode

        git commit --all --message "test[$repo]: " + $utcNow.ToString("o")
        ThrowOnExitCode

        git push
        ThrowOnExitCode

    Pop-Location

    # Set the other return values.

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
