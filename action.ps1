#Requires -Version 7.0 -RunAsAdministrator
#------------------------------------------------------------------------------
# FILE:         action.ps1
# CONTRIBUTOR:  Jeff Lill
# COPYRIGHT:    Copyright (c) 2005-2021 by neonFORGE LLC.  All rights reserved.
#
# The contents of this repository are for private use by neonFORGE, LLC. and may not be
# divulged or used for any purpose by other organizations or individuals without a
# formal written and signed agreement with neonFORGE, LLC.

# Verify that we're running on a properly configured neonFORGE GitHub runner 
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
$naRoot = $env:NA_ROOT

if ([System.String]::IsNullOrEmpty($ncRoot) -or ![System.IO.Directory]::Exists($ncRoot))
{
    throw "Runner Config: neonCLOUD repo is not present."
}

$ncPowershell = [System.IO.Path]::Combine($ncRoot, "Powershell")

Push-Location $ncPowershell | Out-Null
. ./includes.ps1
Pop-Location | Out-Null

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

    # Delete any existing test results folder and then create a fresh folder.
      
    if ([System.IO.File]::Exists($resultsFolder))
    {
        [System.IO.File]::Delete($resultsFolder)
    }

    [System.IO.Directory]::CreateDirectory($resultsFolder) | Out-Null

    # Fetch the workflow and run run URIs.

    $workflowUri    = Get-ActionWorkflowUri
    $workflowRunUri = Get-ActionWorkflowRunUri

    Switch ($repo)
    {
        ""
        {
            throw "[inputs.repo] is required."
        }
          
        "neonCLOUD"
        {
            $repoPath     = "github.com/nforgeio/neonCLOUD"
            $solutionPath = [System.IO.Path]::Combine($env:NC_ROOT, "neonCLOUD.sln")
            $testRoot     = [System.IO.Path]::Combine($env:NC_ROOT, "Test")
        }
          
        "neonKUBE"
        {
            $repoPath     = "github.com/nforgeio/neonKUBE"
            $solutionPath = [System.IO.Path]::Combine($env:NF_ROOT, "neonKUBE.sln")
            $testRoot     = [System.IO.Path]::Combine($env:NF_ROOT, "Test")
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

    # Determine the solution path for the repo as well as the paths to
    # test project files.  This assumes that all tests are located at:
    #
    #       $/Test/**/*.csproj
        
    $testProjects       = @()
    $testProjectFolders = @()

    ForEach ($projectPath in $([System.IO.Directory]::GetFiles($testRoot, "*.csproj", [System.IO.SearchOption]::AllDirectories)))
    {
        $testProjects       += $projectPath
        $testProjectFolders += [System.IO.Path]::GetDirectoryName($projectPath)
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

    $filterOption = ""

    if (![System.String]::IsNullOrEmpty($testFilter))
    {
        $filterOption = "--filter"
    }

    $success = $true

    ForEach ($projectPath in $testProjects)
    {
        dotnet test $projectPath --logger "liquid.md" --no-restore --configuration $buildConfig $filterOption $testFilter | Out-Null
        
        $success = $? -and $success
    }

    # Copy all of the test results from the folders where they were
    # generated to the results folder passed to the action.  There should
    # only be one results file in each directory and we're going to 
    # rename each file to: PROJECT-NAME.md.
    #
    # NOTE: It's possible that there will be no results file for a 
    #       project when the specified filter filters-out all tests
    #       from the project.
    #
    #       RenameAndCopy() will build a map with the projects that
    #       have actually has results for use further below.

    $projectsWithResults = @{}

    function RenameAndCopy
    {
        [CmdletBinding()]
        param (
            [Parameter(Position=0, Mandatory=$true)]
            [string]$projectPath
        )

        $projectName          = [System.IO.Path]::GetFileName($projectPath)
        $projectFolder        = [System.IO.Path]::GetDirectoryName($projectPath)
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

    ForEach ($projectPath in $testProjects)
    {
        RenameAndCopy $projectPath
    }

    # We're using the [nforgeio/artifacts] repo to hold the test results so
    # we can include result links in notifications.  The nice thing about using
    # a GitHub repo for this is that GitHub will handle the markdown translation
    # automatically and GitHub also handles security.  Test results are persisted
    # to the [$/test] folder and will be named like:
    # 
    #       yyyy-MM-ddThh_mm_ssZ-NAME.md
    #
    # where NAME identifies the test project that generated the result file.
    #
    # We're also going to remove files with timestamps older than the integer
    # value from [$/setting-retention-days] to keep a lid on the number of 
    # files that need to be pulled (although the repo history will always grow).

    $testResultsFolder = [System.IO.Path]::Combine($naRoot, "test")

    if ([System.String]::IsNullOrEmpty($naRoot) -or ![System.IO.Directory]::Exists($naRoot))
    {
        throw "[artifacts] repo is not configured locally."
    }

    # Ensure that the [test] folder exists in the [artifacts] repo.

    [System.IO.Directory]::CreateDirectory($testResultsFolder) | Out-Null

    Push-Cwd $naRoot | Out-Null

        # Pull the [artifacts] repo

        Invoke-CaptureStreams "git reset --quiet --hard" | Out-Null
        Invoke-CaptureStreams "git fetch --quiet" | Out-Null
        Invoke-CaptureStreams "git checkout --quiet master" | Out-Null    
        Invoke-CaptureStreams "git pull --quiet" | Out-Null

        # List the files in the results folder and created an array with the sorted file paths.
        # We're sorting here so the [nforgeio-actions/teams-notify-test] action won't have to.

        $sortedResultPaths = @()

        ForEach ($testResultPath in [System.IO.Directory]::GetFiles($resultsFolder, "*.md"))
        {
            $sortedResultPaths += $testResultPath
        }

        $sortedResultPaths = $($sortedResultPaths | Sort-Object)

        # Copy the project test results into the [test] folder in the [artifacts] repo,
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

        $utcNow             = [System.DateTime]::UtcNow
        $timestamp          = $utcNow.ToString("yyyy-MM-ddThh_mm_ssZ")
        $resultMarkdownUris = ""
        $resultHtmlUris     = @()
        $resultInfo         = ""

        ForEach ($testResultPath in $sortedResultPaths)
        {
            $projectName = [System.IO.Path]::GetFileNameWithoutExtension($testResultPath)
            $targetPath  = [System.IO.path]::Combine($testResultsFolder, "$timestamp-$projectName.md")

            Copy-Item -Path $testResultPath -Destination $targetPath

            # Append the next test result URI.

            # [$resultMarkdownUris] and [$resultInfo] will be returned as outputs to be consumed by
            # subsequent [nforgeio-actions/teams-notify-test] step.  [result-uris] will be set to
            # the semicolon list of markdown formatted URIs to the test results as the well appear
            # in the [nforgeio/artifacts] repo.
            #
            # [result-summaries] will return as a semicolon separated list of summaries with the
            # same order as [result-uris].  Each summary holds the total number of tests, failures 
            # and skips, formatted like:
            #
            #       #tests,#errors,#skips

            if (![System.String]::IsNullOrEmpty($resultMarkdownUris))
            {
                $resultMarkdownUris += ";" 
                $resultInfo         += ";"
            }

            $resultMarkdownUris += "[details](https://github.com/nforgeio/artifacts/blob/master/test/$timestamp-$projectName.md)"
            $resultHtmlUris     += "<a href=`"https://github.com/nforgeio/artifacts/blob/master/test/$timestamp-$projectName.md`">details</a>"

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
                    $skipTests++
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

        # Commit and push any [artifacts] repo changes.

        if ($sortedResultPaths.Length -gt 0)
        {
            Invoke-CaptureStreams "git add --all" | Out-Null
            Invoke-CaptureStreams "git commit --quiet --all --message `"test[$repo]: $timestamp`"" | Out-Null
            Invoke-CaptureStreams "git push --quiet" | Out-Null
        }

    Pop-Cwd | Out-Null
    
    #--------------------------------------------------------------------------
    # Create a new issue or append a comment to an existing one when there
    # are test failures and when the issue repo is passed.

    if (!$success -and ![System.String]::IsNullOrEmpty($issueRepo))
    {
        if (![System.String]::IsNullOrEmpty($issueTitle))
        {
            $issueTitle = "Automated tests failed!"
        }

        $assignees = @()

        if (![System.String]::IsNullOrEmpty($issueAssignees))
        {
            ForEach ($assignee in $issueAssignees.Split(" "))
            {
                $assignee = $assignee.Trim();
                
                if ([System.String]::IsNullOrEmpty($asignee))
                {
                    Continue;
                }

                $assignees += $assignee
            }
        }

        $labels = @()

        if (![System.String]::IsNullOrEmpty($issueLabels))
        {
            ForEach ($label in $issueLabels.Split(" "))
            {
                $label = $label.Trim();
                
                if ([System.String]::IsNullOrEmpty($label))
                {
                    Continue;
                }

                $labels += $label
            }
        }

        $issueBody =
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
  <td>@build-config</td>
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
  <td><a href="@workflow-run-uri">link</a></td>
</tr>
<tr>
  <td><b>Workflow:</b></td>
  <td><a href="@workflow-uri">link</a></td>
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
            $buildCommit = "<a href=`"$buildCommitUri`">$buildCommit</a>"
        }
        else
        {
            $buildCommit = "-na-"
        }

        $runner = Get-ProfileValue "runner.name"
        $runner = $runner.ToUpper()

        $filter = $testFilter

        if ([System.String]::IsNullOrEmpty($filter))
        {
            $filter = "-na-"
        }

        $issueBody = $issueBody.Replace("@build-branch", $buildBranch)
        $issueBody = $issueBody.Replace("@build-config", $buildConfig)
        $issueBody = $issueBody.Replace("@test-filter", $filter)
        $issueBody = $issueBody.Replace("@build-commit", $buildCommit)
        $issueBody = $issueBody.Replace("@runner", $runner)
        $issueBody = $issueBody.Replace("@workflow-run-uri", $workflowRunUri)
        $issueBody = $issueBody.Replace("@workflow-uri", $workflowUri)

        # Add details for each test project.

        $okStatus        = "&#x2714"      # heavy checkmark (HTML encoded)
        $warningStatus   = "&#x26A0"      # warning sign (HTML encoded)
        $errorStatus     = "&#x274C"      # error cross (HTML encoded)
        $resultFacts     = ""
        $resultInfoArray = $resultInfo.Split(";")
        
        For ($i = 0; $i -lt $resultHtmlUris.Length; $i++)
        {
            $resultUri = $resultHtmlUris[$i]

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

        $issueBody = $issueBody.Replace("@result-facts", $resultFacts)

        # Create the new issue or append to an existing one with the 
        # same author, append label, and title.

        $issueUri = New-GitHubIssue -Repo           $repoPath `
                                    -Title          $issueTitle `
                                    -Body           $issueBody `
                                    -AppendLabel    $issueAppendLabel `
                                    -Labels         $labels `
                                    -Assignees      $issueAssignees `
                                    -MasterPassword $env:MASTER_PASSWORD
    }

    # Set the output values.

    Set-ActionOutput "build-config" $buildConfig
    Set-ActionOutput "test-filter" $testFilter
    Set-ActionOutput "result-uris" $resultMarkdownUris
    Set-ActionOutput "result-info" $resultInfo

    if (![System.String]::IsNullOrEmpty($issueUri))
    {
        Set-ActionOutput "issue-uri" $issueUri
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
    exit 1
}
