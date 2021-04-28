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
$ntRoot = $env:NT_ROOT

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

$repo          = Get-ActionInput "repo"           $true
$resultsFolder = Get-ActionInput "results-folder" $true

try
{
    if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
    {
        throw "Runner Config: neonCLOUD repo is not present."
    }

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
        }
          
        "neonLIBRARY"
        {
            throw "[neonLIBRARY] build is not implemented."
        }
          
        "cadence-samples"
        {
            throw "[cadence-samples] build is not implemented."
        }
          
        "temporal-samples"
        {
            throw "[temporal-samples] build is not implemented."
        }
          
        default
        {
            throw "[$repo] is not a supported repo."
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
    # automatically and GitHub also handles security.  Test results are persisted
    # to the [$/reults] folder and will be named like:
    # 
    #       yyyy-MM-ddThh_mm_ssZ-NAME.md
    #
    # where NAME identifies the test project that generated the result file.
    #
    # We're also going to remove files with timestamps older than the integer
    # value from [$/setting-retention-days] to keep a lid on the number of 
    # files that need to be pulled (note that the history will keep growing).

    $testResultsFolder = [System.IO.Path]::Combine($ntRoot, "results")

    if ([System.String]::IsNullOrEmpty($ntRoot) -or ![System.IO.Directory]::Exists($ntRoot))
    {
        throw "[test-results] repo is not configured locally."
    }

    Push-Location $ntRoot

        # Ensure that the [results] folder exists in the [test-results] repo.

        $testResultsRepoFolder = [System.IO.Path]::Combine($ntRoot, "results")

        [System.IO.Directory]::CreateDirectory($testResultsRepoFolder)

        # Pull the [test-results] repo and then scan the test results file and remove
        # those with timestamps older than [$/setting-retention-days].

        git pull
        ThrowOnExitCode

        $retentionDaysPath = [System.IO.Path]::Combine($ntRoot, "setting-retention-days")
        $retentionDays     = [int][System.IO.File]::ReadAllText($retentionDaysPath).Trim()
        $utcNow            = [System.DateTime]::UtcNow
        $minRetainTime     = $utcNow.Date - $(New-TimeSpan -Days $retentionDays)

        ForEach ($testResultPath in [System.IO.Directory]::GetFiles($testResultsRepoFolder, "*.md"))
        {
            # Extract and parse the timestamp.

            $filename   = [System.IO.Path]::GetFileName($testResultPath)
            $timestring = $filename.SubString(0, 20)        # Extract the "yyyy-MM-ddThh_mm_ssZ" part
            $timeString = $timeString.Replace("_", ":")     # Convert to: "yyyy-MM-ddThh:mm:ssZ"
            $timestamp  = [System.DateTime]::ParseExact($timeString, "yyyy-MM-ddThh:mm:ssZ", $([System.Globalization.CultureInfo]::InvariantCulture)).ToUniversalTime()

            if ($timestamp -lt $minRetainTime)
            {
                Write-ActionOutput "*** expired: $testResultPath"
                [System.IO.File]::Delete($testResultPath)
            }
        }

        # List the files in the results folder and created an array with the sorted file paths.
        # We're sorting here so the [nforgeio-actions/teams-notify-test] action won't have to.

        $sortedResultPaths = @()

        ForEach ($testResultPath in [System.IO.Directory]::GetFiles($resultsFolder, "*.md"))
        {
            $sortedResultPaths += $testResultPath
        }

        $sortedResultPaths = $($sortedResultPaths | Sort-Object)

        # Copy the project test results into the [results] folder in the [test-results] repo,
        # renaming the files to be like: 
        #
        #       yyyy-MM-ddThh_mm_ssZ-NAME.md
        #
        # Note that we're using underscores here because colons aren't allowed in URLs
        # without being escaped and Windows doesn't allow them in file names.
        #
        # We're also going to create the semicolon separated list of markdown formatted
        # test result URIs for the [result-uris] output along with the matching String
        # with test result summaries for the [result-summaries] output.

        $timestamp       = $utcNow.ToString("yyyy-MM-ddThh_mm_ssZ")
        $resultUris      = ""
        $resultSummaries = ""

        ForEach ($testResultPath in $sortedResultPaths)
        {
            $projectName = [System.IO.Path]::GetFileNameWithoutExtension($testResultPath)
            $targetPath  = [System.IO.path]::Combine($testResultsFolder, "$timestamp-$projectName.md")

            Copy-Item -Path $testResultPath -Destination $targetPath

            # Append the next test result URI.

            # [$resultUris] and [$resultSummaries] will be returned as outputs to be consumed by
            # subsequent [nforgeio-actions/teams-notify-test] step.  [result-uris] will be set to
            # the semicolon list of markdown formatted URIs to the test results as the well appear
            # in the [nforgeio/test-results] repo.
            #
            # [result-summaries] will return as a semicolon separated list of summaries with the
            # same order as [result-uris].  Each summary holds the total number of tests, failures 
            # and skips, formatted like:
            #
            #       #tests,#errors,#skips

            if (![System.String]::IsNullOrEmpty($resultUris))
            {
                $resultUris      += ";" 
                $resultSummaries += ";"
            }

            $resultUris += "[results](https://github.com/nforgeio/test-results/blob/master/results/$timestamp-$projectName.md)"

            # $hack(jefflill):
            #
            # We're going to read the test result markdown file to count the total number
            # of tests along with the errors and skips.  This relies on the test report
            # format not changing in the future.

            $totalTests = 0
            $errorTests = 0
            $skipTests  = 0

            ForEach ($line in [System.IO.File]::ReadAllLines($testResultPath))
            {
                if ($line.Contains("Passed </td>"))
                {
                    $totalTests++
                }
                elseif ($lines.Contains("Failed </td>"))
                {
                    $totalTests++
                    $errorTests++
                }
                elseif ($lines.Contains("Skipped </td>"))
                {
                    $totalTests++
                    skipTests++
                }
            }

            $resultSummaries += "$totalTests,$errorTests,$skipTests"
        }

        # Commit and push the [test-results] repo changes.

        git add --all
        ThrowOnExitCode

        git commit --all --message "test[$repo]: $timestamp"
        ThrowOnExitCode

        git push
        ThrowOnExitCode

    Pop-Location

    # Set the output values.

    Set-ActionOutput "result-uris"      $resultUris
    Set-ActionOutput "result-summaries" $resultSummaries

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
    exit 1
}

Set-ActionOutput "success" $success
