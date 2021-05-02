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

$repo             = Get-ActionInput "repo"               $true
$buildBranch      = Get-ActionInput "build-branch"       $false
$buildConfig      = Get-ActionInput "build-config"       $false
$buildCommit      = Get-ActionInput "build-commit"       $false
$buildCommitUri   = Get-ActionInput "build-commit-uri"   $false
$testFilter       = Get-ActionInput "test-filter"        $false
$resultsFolder    = Get-ActionInput "results-folder"     $true
$issueRepo        = Get-ActionInput "issue-repo"         $false
$issueTitle       = Get-ActionInput "issue-title"        $false
$issueAssignees   = Get-ActionInput "issue-assignees"    $false
$issueLabels      = Get-ActionInput "issue-labels"       $false
$issueAppendLabel = Get-ActionInput "issue-append-label" $false

if ($buildConfig -ne "release")
{
    $buildConfig = "debug"
}

try
{
    if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
    {
        throw "Runner Config: neonCLOUD repo is not present."
    }

    # Fetch the workflow and run run URIs.

    $workflowUri    = Get-WorkflowUri $env:workflow-path
    $workflowRunUri = Get-WorkflowRunUri

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
            $testProjectFolders += [System.IO.Path]::Combine($testRoot, "Test.Neon.Identity")
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

    $filterOption = ""

    if (![System.String]::IsNullOrEmpty($testFilter))
    {
        $filterOption = "--filter"
    }

    dotnet test $solutionPath --logger "liquid.md" --configuration $buildConfig $filterOption $testFilter | Out-Null
    $success = $?

    # Copy all of the test results from the folders where they were
    # generated to the results folder passed to the action.  There should
    # only be one results file in each directory and we're going to 
    # rename each file to: PROJECT-NAME.md.
    #
    # NOTE: It's possible that there will be no results file for a 
    #       project when a specified filter filters-out all tests
    #       from the project.
    #
    #       RenameAndCopy() will build a map with the projects that
    #       have acutally has results for user further below.

    $projectsWithResults = @{}

    function RenameAndCopy
    {
        [CmdletBinding()]
        param (
            [Parameter(Position=0, Mandatory=$true)]
            [string]$projectFolder
        )

        $projectName          = [System.IO.Path]::GetFileName($projectFolder)
        $projectResultsFolder = [System.IO.Path]::Combine($projectFolder, "TestResults")
        
        if (![System.IO.Directory]::Exists($projectResultsFolder))
        {
            return  # No results for this test project
        }

        $projectResultFiles = [System.IO.Directory]::GetFiles($projectResultsFolder, "*.md")

        if ($projectResultFiles.Length -eq 0)
        {
            return  # No results for this test project
        }

        
        Copy-Item -Path $projectResultFiles[0] -Destination $([System.IO.Path]::Combine($resultsFolder, "$projectName.md"))

        $projectsWithResults.Add($projectName, "true")
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
    # files that need to be pulled (note that the history will always grow).

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

        $timestamp  = $utcNow.ToString("yyyy-MM-ddThh_mm_ssZ")
        $resultUris = ""
        $resultInfo = ""

        ForEach ($testResultPath in $sortedResultPaths)
        {
            $projectName = [System.IO.Path]::GetFileNameWithoutExtension($testResultPath)
            $targetPath  = [System.IO.path]::Combine($testResultsFolder, "$timestamp-$projectName.md")

            Copy-Item -Path $testResultPath -Destination $targetPath

            # Append the next test result URI.

            # [$resultUris] and [$resultInfo] will be returned as outputs to be consumed by
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
                $resultUris += ";" 
                $resultInfo += ";"
            }

            $resultUris += "[details](https://github.com/nforgeio/test-results/blob/master/results/$timestamp-$projectName.md)"

            # $hack(jefflill):
            #
            # We're going to read the test result markdown file to count the total number
            # of tests along with the errors and skips.  We'll also read the elapsed time.
            # This relies on the test report format not changing much in the future.

            $totalTests = 0
            $errorTests = 0
            $skipTests  = 0
            $elapsed    = "-na-"

            ForEach ($line in [System.IO.File]::ReadAllLines($testResultPath))
            {
                if ([System.String]::IsNullOrEmpty($line))
                {
                    Continue
                }

                if ($line.Contains("Passed </td>"))
                {
                    $totalTests++
                }
                elseif ($line.Contains("Failed </td>"))
                {
                    $totalTests++
                    $errorTests++
                }
                elseif ($line.Contains("Skipped </td>"))
                {
                    $totalTests++
                    skipTests++
                }
                elseif ($line.StartsWith("<strong>Date:</strong>"))
                {
                    $posStart = "<strong>Date:</strong>".Length
                    $posEnd   = $line.IndexOf("<br />", $posStart)

                    if ($posEnd -ne -1)
                    {
                        $timeRange = $line.SubString($posStart, $posEnd - $posStart)
                        $fields    = $timeRange.Split(" - ")
                        $startDate = [System.DateTime]::Parse($fields[0].Trim())
                        $endDate   = [System.DateTime]::Parse($fields[1].Trim())

                        $elapsed = $(New-TimeSpan $startDate $endDate).ToString("c")
                    }
                }
            }

            $resultInfo += "$projectName,$totalTests,$errorTests,$skipTests,$elapsed"
        }

        # Commit and push any [test-results] repo changes.

        if ($sortedResultPaths.Length -gt 0)
        {
            git add --all | Out-Null
            ThrowOnExitCode

            git commit --all --message "test[$repo]: $timestamp" | Out-Null
            ThrowOnExitCode

            git push | Out-Null
            ThrowOnExitCode
        }

    Pop-Location
    
    #--------------------------------------------------------------------------
    # Create a new issue or append a comment to an existing one when there
    # are test failures and when the issue repo is passed.

Write-ActionOutput "***********************************************"
Write-ActionOutput "*** success:          $success"
Write-ActionOutput "*** issueRepo:        $issueRepo"
Write-ActionOutput "*** issueTitle:       $issueTitle"
Write-ActionOutput "*** issueAssignees:   $issueAssignees"
Write-ActionOutput "*** issueLabels:      $issueLabels"
Write-ActionOutput "*** issueAppendLabel: $issueAppendLabel"

    if (!$success -and ![System.String]::IsNullOrEmpty($issueRepo))
    {
Write-ActionOutput "*** 0"
        if (![System.String]::IsNullOrEmpty($issueTitle))
        {
Write-ActionOutput "*** 1"
            $issueTitle = "Automated tests failed!"
        }

Write-ActionOutput "*** 2"
        $assignees = @()

        if (![System.String]::IsNullOrEmpty($issueAssignees))
        {
Write-ActionOutput "*** 3"
            ForEach ($assignee in $issueAssignees.Split(","))
            {
                $assignee = $assignee.Trim();
                
                if ([System.String]::IsNullOrEmpty($asignee))
                {
                    Continue;
                }

                $assignees += $assignee
            }
        }
Write-ActionOutput "*** 4"

        $labels = @()

        if (![System.String]::IsNullOrEmpty($issueLabels))
        {
Write-ActionOutput "*** 5"
            ForEach ($label in $issueLabels.Split(","))
            {
                $label = $label.Trim();
                
                if ([System.String]::IsNullOrEmpty($label))
                {
                    Continue;
                }

                $labels += $label
            }
        }
Write-ActionOutput "*** 6"

        $body =
@'
<table>
<tr>
  <td><b>Outcome:</b></td>
  <td><b>TESTS FAILED</b></td>
</tr>
<tr>
  <td><b>Branch:</b></td>
  <td>@build-branch</td>
</tr>
<tr>
  <td><b>Config:</b></td>
  <td>@build-branch</td>
</tr>
<tr>
  <td><b>Filter:</b></td>
  <td>@test-filter</td>
</tr>
<tr>
  <td><b>Commit:</b></td>
  <td>@build-commit</td>
</tr>
<tr>
  <td><b>Runner:</b></td>
  <td>@runner</td>
</tr>
<tr>
  <td><b>Workflow Run:</b></td>
  <td><a href="@workflow-run-uri">workflow run</a></td>
</tr>
<tr>
  <td><b>Workflow:</b></td>
  <td><a href="@workflowuri">workflow run</a></td>
</tr>
@result-facts
</table>
'@
        if ([System.String]::IsNullOrEmpty($buildBranch))
        {
            $buildBranch = "-na-"
        }

        if ([System.String]::IsNullOrEmpty($buildConfig))
        {
            $buildConfig = "-na-"
        }

        if (![System.String]::IsNullOrEmpty($buildCommit) -and ![System.String]::IsNullOrEmpty($buildCommitUri))
        {
            $buildCommit = '<a href="$buildCommitUri">$buildCommit</a>'
        }
        else
        {
            $buildCommit = "-na-"
        }
Write-ActionOutput "*** 7"

        $runner = $env:COMPUTERNAME
        $runner = $runner.ToUpper()

        $filter = $testFilter

        if ([System.String]::IsNullOrEmpty($filter))
        {
            $filter = "-na-"
        }

        $body = $body.Replace("@build-branch", $buildBranch)
        $body = $body.Replace("@build-config", $buildConfig)
        $body = $body.Replace("@test-filter", $filter)
        $body = $body.Replace("@build-commit", $buildCommit)
        $body = $body.Replace("@workflow-run-uri", $workflowRunUri)
        $body = $body.Replace("@workflow-uri", $workflowUri)
Write-ActionOutput "*** 8"

        # Add details for each test project.

        $okStatus      = "&#x2714"      # heavy checkmark (HTML encoded)
        $warningStatus = "&#x26A0"      # warning sign (HTML encoded)
        $errorStatus   = "&#x274C"      # error cross (HTML encoded)

        $resultFacts = ""

        $resultUriArray  = $resultUris.Split(";")
        $resultInfoArray = $$resultInfo.Split(";")
        
        For ($i = 0; $i -lt $resultUriArray.Length; i++)
        {
            $resultUri = $resultUriArray[$i]

            # Extract the details from the corresponding summary.

            $details = $resultInfoArray[$i].Split(",")
            $name    = $details[0]
            $total   = [int]$details[1]
            $errors  = [int]$details[2]
            $skips   = [int]$details[3]
            $elapsed = $details[4]

            if ($errors -gt 0)
            {
                $status = $errorStatus
            }
            elseif ($skips -gt 0)
            {
                $status = $warningStatus
            }
            else
            {
                $status = $okStatus
            }

            $factTemplate =
@'
<tr>
  <td><b>@test-project:</b></td>
  <td>@status @result-uri - @elapsed pass: <b>@pass</b> fail: <b>@fail</b> skipped: @skip</td>
</tr>
'@
            $factTemplate = $factTemplate.Replace("@test-project", $name)
            $factTemplate = $factTemplate.Replace("@status", $status)
            $factTemplate = $factTemplate.Replace("@result-uri", $resultUri)
            $factTemplate = $factTemplate.Replace("@elapsed", $elapsed)
            $factTemplate = $factTemplate.Replace("@pass", $total - $errors - $skips)
            $factTemplate = $factTemplate.Replace("@fail", $errors)
            $factTemplate = $factTemplate.Replace("@skip", $skips)

            $resultFacts += $factTemplate
        }
Write-ActionOutput "*** 9"
[System.IO.File]::WriteAllText("C:\Temp\issue.txt", $body)

        $body = $body.Replace("@result-facts", $resultFacts)

        # Create the new issue or append to an existing one with the 
        # same author, append label, and title.

        New-GitHubIssue -Repo           $repo `
                        -Title          $issueTitle `
                        -Body           $body `
                        -AppendLabel    $issueAppendLabel `
                        -Labels         $labels `
                        -Assignees      $issueAssignees `
                        -MasterPassword $env:MASTER_PASSWORD
Write-ActionOutput "*** 10"
    }
Write-ActionOutput "***********************************************"

    # Set the output values.

    Set-ActionOutput "build-config" $buildConfig
    Set-ActionOutput "test-filter" $testFilter
    Set-ActionOutput "result-uris" $resultUris
    Set-ActionOutput "result-info" $resultInfo

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
