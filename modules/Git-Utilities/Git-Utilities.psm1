<#
.SYNOPSIS
    Checks if the current directory is a Git repository.
.DESCRIPTION
    This function determines whether the current working directory is part of a Git repository.
    It uses the 'git rev-parse' command to make this determination.
.EXAMPLE
    Test-IsGitRepository
    Returns: $true or $false
    
    This will check if the current directory is a Git repository and return a boolean result.
.EXAMPLE
    Push-Location C:\MyProject
    $isGitRepo = Test-IsGitRepository
    Pop-Location
    
    This example changes to a specific directory, checks if it's a Git repository, 
    stores the result in a variable, then returns to the original directory.
.OUTPUTS
    System.Boolean
    Returns $true if the current directory is a Git repository, $false otherwise.
.NOTES
    Requires Git to be installed and accessible in the system PATH.
#>
function Test-IsGitRepository {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        Write-Verbose "Starting Git repository check"
    }

    process {
        try {
            $null = git rev-parse --is-inside-work-tree 2>&1
            $isGitRepo = $?
            
            if ($isGitRepo) {
                Write-Verbose "This is a Git repository"
            }
            else {
                Write-Verbose "This is not a Git repository"
            }

            return $isGitRepo
        }
        catch {
            Write-Error "An error occurred while checking Git status: $_"
            return $false
        }
    }

    end {
        Write-Verbose "Completed Git repository check"
    }
}

<#
.SYNOPSIS
    Gets the name of the current Git branch.
.DESCRIPTION
    This function retrieves the name of the current Git branch in the repository.
    It first checks if the current directory is a Git repository using Test-IsGitRepository,
    then uses the 'git rev-parse' command to get the branch name.
.EXAMPLE
    Get-GitCurrentBranch
    Returns: "main"
    
    This will return the name of the current Git branch (e.g., "main", "develop", etc.).
.EXAMPLE
    Push-Location C:\MyProject
    $currentBranch = Get-GitCurrentBranch
    Pop-Location
    Write-Output "The current branch is: $currentBranch"
    
    This example changes to a specific directory, gets the current Git branch name,
    stores it in a variable, returns to the original directory, then outputs the branch name.
.OUTPUTS
    System.String
    Returns the name of the current Git branch as a string, or $null if not in a Git repository or if an error occurs.
.NOTES
    Requires Git to be installed and accessible in the system PATH.
    This function depends on Test-IsGitRepository.
#>
function Get-GitCurrentBranch {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    begin {
        Write-Verbose "Starting to fetch current Git branch"
    }

    process {
        try {
            if (-not (Test-IsGitRepository)) {
                Write-Error "Not a Git repository"
                return $null
            }

            $branch = git rev-parse --abbrev-ref HEAD 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Verbose "Current branch: $branch"
                return $branch
            }
            else {
                Write-Error "Failed to get current branch: $branch"
                return $null
            }
        }
        catch {
            Write-Error "An error occurred while fetching the current branch: $_"
            return $null
        }
    }

    end {
        Write-Verbose "Completed fetching current Git branch"
    }
}

<#
.SYNOPSIS
    Creates a new merge branch for deploying to a target branch.
.DESCRIPTION
    This function creates a new branch for merging your feature branch with a specified target branch.
    It checks for uncommitted changes, unstaged changes, and unpushed commits.
    If there are unpushed commits, it prompts the user to push before proceeding.
    If the working directory is clean and all commits are pushed (or user agrees to push),
    it performs a series of Git operations to ensure a clean merge and pushes the result if successful.
    If there are no differences between the new branch and the target branch, it cleans up and notifies the user.
.PARAMETER TargetBranch
    The name of the target branch to merge from (e.g., 'develop', 'main', 'staging').
.EXAMPLE
    New-MergeBranch -TargetBranch 'develop'
    Creates a new merge branch from the 'develop' branch.
.EXAMPLE
    New-MergeBranch -TargetBranch 'main'
    Creates a new merge branch from the 'main' branch.
.NOTES
    Requires Git to be installed and accessible in the system PATH.
    This function depends on Test-IsGitRepository and Get-GitCurrentBranch.
#>
function New-MergeBranch {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TargetBranch
    )

    begin {
        if (-not (Test-IsGitRepository)) {
            throw "Not in a Git repository."
        }

        $originalBranch = Get-GitCurrentBranch
        if (-not $originalBranch) {
            throw "Failed to get current branch."
        }

        # Check for uncommitted or unstaged changes
        $status = git status --porcelain
        if ($status) {
            throw "Your branch has uncommitted or unstaged changes. Please commit or stash them before proceeding."
        }

        # Check for unpushed commits
        $unpushedCommits = git log @("origin/$originalBranch..$originalBranch")
        if ($unpushedCommits) {
            Write-Warning "You have unpushed commits on your branch."
            $push = Read-Host "Do you want to push these commits before proceeding? (Y/N)"
            if ($push -eq 'Y' -or $push -eq 'y') {
                git push
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to push commits. Please push manually and try again."
                }
                Write-Output "Commits pushed successfully."
            }
            else {
                throw "Operation aborted. Please push your commits and try again."
            }
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        
        $branchPrefix = Get-GitPrefix -BranchName $originalBranch
        $newBranchName = "${branchPrefix}/merge_${TargetBranch}_$timestamp"
    }

    process {
        try {
            # 1. Switch to target branch
            git checkout $TargetBranch
            if ($LASTEXITCODE -ne 0) { throw "Failed to switch to $TargetBranch branch." }

            # 2. Pull to get latest
            git pull
            if ($LASTEXITCODE -ne 0) { throw "Failed to pull latest changes from $TargetBranch." }

            # 3. Switch back to original feature branch
            git checkout $originalBranch
            if ($LASTEXITCODE -ne 0) { throw "Failed to switch back to $originalBranch." }

            # 4 & 5. Create and checkout new branch
            git checkout -b $newBranchName
            if ($LASTEXITCODE -ne 0) { throw "Failed to create and checkout new branch $newBranchName." }

            # 6. Merge target branch into the new branch
            $mergeOutput = git merge $TargetBranch 2>&1
            if ($LASTEXITCODE -ne 0) {
                # 7. If there are conflicts, create an error
                throw "Merge conflicts occurred: `n$mergeOutput"
            }

            # Check if there are any differences between the new branch and the target branch
            $diffOutput = git diff $TargetBranch $newBranchName
            if (-not $diffOutput) {
                Write-Output "No differences found between $newBranchName and $TargetBranch."
                git checkout $originalBranch
                git branch -D $newBranchName
                Write-Output "Cleaned up: Switched back to $originalBranch and deleted $newBranchName."
                return
            }

            # 8. If there are differences, push the new branch
            git push --set-upstream origin $newBranchName
            if ($LASTEXITCODE -ne 0) { throw "Failed to push new branch $newBranchName." }

            Write-Output "Successfully created and pushed merge branch: $newBranchName"

            # Create a new PR
            $projectType = Get-ProjectType
            $prTitle = "Merge $originalBranch into $TargetBranch"
            $prBody = "This PR merges changes from $originalBranch into $TargetBranch."

            $prResult = New-PR -Title $prTitle -ToBranch $TargetBranch -Body $prBody -ProjectType $projectType

            # Extract PR URL from the result
            $prUrl = $prResult -replace "Pull request created successfully. PR URL: "

            # Extract JIRA key from the original branch name
            $jiraKey = if ($originalBranch -match '^Bug/([A-Z]+-\d+)') {
                $matches[1]
            }
            elseif ($originalBranch -match '^([A-Z]+-\d+)') {
                $matches[0]
            }
            else {
                $null
            }

            if (-not $jiraKey) {
                Write-Warning "Could not extract a valid JIRA key from the branch name. Skipping JIRA update."
            }
            else {
                # Append PR information to JIRA issue description
                $currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $prInfo = @"
PR: $currentDate
FROM: $newBranchName
TO: $TargetBranch
URL: $prUrl
"@

                Add-TextToJiraDescription -IssueKey $jiraKey -TextToAdd $prInfo

                Write-Output "PR information added to JIRA issue $jiraKey"
            }
        }
        catch {
            Write-Error $_.Exception.Message
        }
        finally {
            # Always try to return to the original branch
            git checkout $originalBranch
        }
    }
}

<#
.SYNOPSIS
    Extracts the prefix from a Git branch name.
.DESCRIPTION
    This function takes a Git branch name and extracts the prefix, which includes all parts before the last forward slash (/). 
    If there's no slash, it returns the entire branch name. This is useful for maintaining consistent naming conventions in branch operations.
.PARAMETER BranchName
    The full name of the Git branch from which to extract the prefix.
.EXAMPLE
    Get-GitPrefix -BranchName "JIRA-123/feature-description"
    Returns: "JIRA-123"
.EXAMPLE
    Get-GitPrefix -BranchName "Bugs/HKBP-222/fix-login"
    Returns: "Bugs/HKBP-222"
.EXAMPLE
    Get-GitPrefix -BranchName "main"
    Returns: "main"
.OUTPUTS
    System.String
#>
function Get-GitPrefix {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $BranchName
    )
    
    process {
        # Extract the prefix (everything before the last slash)
        $prefix = $BranchName -replace '/[^/]*$'
        
        # If the branch name doesn't contain a slash, the entire name is returned
        if ($prefix -eq $BranchName) {
            return $BranchName
        }
        
        return $prefix
    }
}

<#
.SYNOPSIS
    Lists all Git branches with a given prefix.
.DESCRIPTION
    This function retrieves all Git branches that share the same prefix as the specified branch.
    The prefix is treated as a folder, so "Bugs/HKBP-222" would be considered a single prefix.
.PARAMETER BranchName
    The full name of the Git branch from which to extract the prefix and find related branches.
    If not provided, the current branch is used.
.EXAMPLE
    Get-TopicBranches -BranchName "Bugs/HKBP-222/feature-description"
    Returns: All branches starting with "Bugs/HKBP-222/"
.EXAMPLE
    Get-TopicBranches
    Returns: All branches sharing the same prefix as the current branch
.OUTPUTS
    System.String[]
#>
function Get-TopicBranches {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false)]
        [string]
        $BranchName
    )
    
    begin {
        if (-not $BranchName) {
            $BranchName = git rev-parse --abbrev-ref HEAD
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to get current branch name."
            }
        }

        # Use the updated Get-GitPrefix function to extract the prefix
        $prefix = Get-GitPrefix -BranchName $BranchName
    }
    
    process {
        # Get all branches
        $allBranches = git branch -a --format="%(refname:short)"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve Git branches."
        }

        # Filter branches that start with the prefix
        $matchingBranches = $allBranches | Where-Object { $_ -like "$prefix*" }

        return $matchingBranches
    }
}

<#
.SYNOPSIS
    Retrieves a list of Git branches containing a specified string.

.DESCRIPTION
    This function searches for and returns a list of Git branches 
    (local and optionally remote) that contain a specified string in their names. 
    It works in the current Git repository.

.PARAMETER ContainsString
    The string to search for in branch names.

.PARAMETER IncludeRemote
    If specified, includes remote branches in the search.

.EXAMPLE
    Get-Branches "/merge_"
    Returns a list of all local branches containing "/merge_" in their names.

.EXAMPLE
    Get-Branches "feature/" -IncludeRemote
    Returns a list of all local and remote branches containing "feature/" in their names.

.EXAMPLE
    $branches = Get-Branches "develop" -IncludeRemote
    $branches | ForEach-Object { Write-Host $_ }
    Retrieves all local and remote branches containing "develop" and displays them.

.OUTPUTS
    System.String[]
    Returns an array of branch names as strings.

.NOTES
    Requires Git to be installed and accessible in the system PATH.
    This function depends on Test-IsGitRepository.
    Remote branches are returned without the 'origin/' prefix for consistency with local branch names.
    If a remote branch has the same name as a local branch, only the local branch is included in the output.
#>
function Get-Branches {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ContainsString,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeRemote
    )

    begin {
        Write-Verbose "Starting to fetch branches containing '$ContainsString'"
        if (-not (Test-IsGitRepository)) {
            Write-Error "Not in a Git repository. Aborting."
            return @()
        }
    }

    process {
        try {
            $matchingBranches = @()
            
            # Fetch local branches
            $localBranches = git branch | 
            Where-Object { $_ -like "*$ContainsString*" -and $_ -notmatch '^\*' } | 
            ForEach-Object { $_.Trim() }
            $matchingBranches += $localBranches

            # Fetch remote branches if flag is set
            if ($IncludeRemote) {
                $remoteBranches = git branch -r | 
                Where-Object { $_ -like "*$ContainsString*" } | 
                ForEach-Object { $_.Trim() -replace '^origin/', '' } |
                Where-Object { $_ -notin $localBranches }
                $matchingBranches += $remoteBranches
            }

            Write-Verbose "Found $($matchingBranches.Count) matching branches"
            return $matchingBranches
        }
        catch {
            Write-Error "An error occurred while fetching branches: $_"
            return @()
        }
    }

    end {
        Write-Verbose "Completed fetching branches containing '$ContainsString'"
    }
}

<#
.SYNOPSIS
    Removes Git branches containing a specified string.

.DESCRIPTION
    This function removes Git branches (local and optionally remote) 
    that contain a specified string in their names. It works in the current Git repository 
    and provides user confirmation before deletion.

.PARAMETER ContainsString
    The string to search for in branch names. Branches containing this string will be targeted for deletion.

.PARAMETER IncludeRemote
    If specified, includes remote branches in the search and deletion process.

.EXAMPLE
    Remove-Branches "/merge_"
    Removes all local branches containing "/merge_" in their names and their corresponding remote tracking branches after user confirmation.

.EXAMPLE
    Remove-Branches "feature/" -IncludeRemote -Verbose
    Removes all local and remote branches containing "feature/" with verbose output.

.NOTES
    Requires Git to be installed and accessible in the system PATH.
    This function depends on Test-IsGitRepository, Get-GitCurrentBranch, and Get-Branches.
    The current branch will not be deleted even if it matches the criteria.
    If a local branch has a corresponding remote branch, the remote branch will be deleted first.
#>
function Remove-Branches {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ContainsString,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeRemote
    )

    begin {
        Write-Verbose "Starting branch removal process for branches containing '$ContainsString'"
        if (-not (Test-IsGitRepository)) {
            Write-Error "Not in a Git repository. Aborting."
            return
        }
    }

    process {
        try {
            $currentBranch = Get-GitCurrentBranch
            if ($null -eq $currentBranch) {
                Write-Error "Failed to get current branch. Aborting."
                return
            }

            $matchingBranches = Get-Branches $ContainsString -IncludeRemote:$IncludeRemote

            if ($matchingBranches.Count -eq 0) {
                Write-Host "No branches found containing '$ContainsString'"
                return
            }

            Write-Host "The following branches will be deleted:"
            $matchingBranches | ForEach-Object { Write-Host "  $_" }
            $confirmation = Read-Host "Do you want to continue? (Y/N)"
            if ($confirmation -ne 'Y') {
                Write-Host "Operation aborted by user."
                return
            }

            foreach ($branch in $matchingBranches) {
                if ($branch -eq $currentBranch) {
                    Write-Error "Cannot delete the current branch '$branch'. Skipping."
                    continue
                }

                $isRemote = $branch -like "origin/*"
                if ($isRemote) {
                    $remoteName = ($branch -split "/")[0]
                    $remoteBranchName = ($branch -split "/", 2)[1]
                    Write-Host "Deleting remote branch: $branch"
                    git push $remoteName --delete $remoteBranchName
                }
                else {
                    # Check if the branch exists locally
                    if (git branch --list $branch) {
                        $remoteBranch = git for-each-ref --format='%(upstream:short)' refs/heads/$branch
                        if ($remoteBranch) {
                            $remoteName = ($remoteBranch -split "/")[0]
                            $remoteBranchName = ($remoteBranch -split "/", 2)[1]
                            Write-Host "Deleting remote tracking branch: $remoteBranch"
                            git push $remoteName --delete $remoteBranchName
                        }

                        Write-Host "Deleting local branch: $branch"
                        git branch -D $branch
                    }
                    else {
                        Write-Host "Local branch not found: $branch. It may be a remote-only branch."
                        if (git ls-remote --exit-code --heads origin $branch) {
                            Write-Host "Deleting remote branch: origin/$branch"
                            git push origin --delete $branch
                        }
                        else {
                            Write-Host "Remote branch not found: origin/$branch. Skipping."
                        }
                    }
                }
            }
        }
        catch {
            Write-Error "An error occurred: $_"
        }
    }

    end {
        Write-Verbose "Branch removal process completed"
    }
}

<#
.SYNOPSIS
    Lists local Git branches that are not tracking any remote branch.
.DESCRIPTION
    This function identifies and lists local Git branches that are not tracking any remote branch.
    It provides information about each untracked branch, including its name and the date of its last commit.
.EXAMPLE
    Get-UntrackedBranches
    This will list all local branches that are not tracking any remote branch, along with their last commit date.
.OUTPUTS
    System.Object[]
    Returns an array of custom objects, each containing the branch name and last commit date.
.NOTES
    Requires Git to be installed and accessible in the system PATH.
    This function depends on Test-IsGitRepository.
#>
function Get-UntrackedBranches {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param()
    
    begin {
        if (-not (Test-IsGitRepository)) {
            Write-Error "Not in a Git repository. Aborting."
            return
        }
        Write-Verbose "Starting to fetch untracked branches"
    }
    
    process {
        try {
            # Get all local branches
            $localBranches = git for-each-ref --format='%(refname:short)' refs/heads/

            $untrackedBranches = @()

            foreach ($branch in $localBranches) {
                # Check if the branch has a tracking remote
                $trackingBranch = git for-each-ref --format='%(upstream:short)' refs/heads/$branch
                if (-not $trackingBranch) {
                    # Get the last commit date for this branch
                    $lastCommitDate = git log -1 --format="%ai" $branch

                    # Create a custom object with branch info
                    $branchInfo = [PSCustomObject]@{
                        BranchName     = $branch
                        LastCommitDate = $lastCommitDate
                    }

                    $untrackedBranches += $branchInfo
                }
            }

            return $untrackedBranches
        }
        catch {
            Write-Error "An error occurred: $_"
        }
    }
    
    end {
        Write-Verbose "Completed fetching untracked branches"
    }
}

<#
.SYNOPSIS
    Lists local branches that have not been merged into a specified target branch.
.DESCRIPTION
    This function identifies local branches that contain changes not present in the specified target branch.
    It uses a diff-based approach to compare each local branch with the target branch.
.PARAMETER TargetBranch
    The name of the target branch to compare against (e.g., 'develop', 'staging').
.EXAMPLE
    Get-UnmergedBranches -TargetBranch 'develop'
    Lists all local branches that have changes not present in the 'develop' branch.
.OUTPUTS
    System.Object[]
    Returns an array of custom objects, each containing the branch name and its status.
.NOTES
    This function assumes that merges are done via Pull Requests and not direct merges.
    It checks for changes in the local branch that are not in the target branch.
#>
function Get-UnmergedBranches {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetBranch
    )

    begin {
        if (-not (Test-IsGitRepository)) {
            Write-Error "Not in a Git repository. Aborting."
            return
        }
        Write-Verbose "Starting to check for unmerged branches against $TargetBranch"
    }

    process {
        try {
            $currentBranch = Get-GitCurrentBranch
            $localBranches = git for-each-ref --format='%(refname:short)' refs/heads/

            $unmergedBranches = @()

            foreach ($branch in $localBranches) {
                if ($branch -eq $TargetBranch) {
                    continue  # Skip the target branch itself
                }

                # Check if there are any commits in the branch that are not in the target branch
                $unmergedCommits = git log "$TargetBranch..$branch" --oneline

                if ($unmergedCommits) {
                    $branchInfo = [PSCustomObject]@{
                        BranchName      = $branch
                        Status          = "Not fully merged"
                        UnmergedCommits = ($unmergedCommits -split "`n").Count
                    }
                    $unmergedBranches += $branchInfo
                }
            }

            return $unmergedBranches
        }
        catch {
            Write-Error "An error occurred: $_"
        }
        finally {
            # Ensure we switch back to the original branch
            if ($currentBranch) {
                git checkout $currentBranch | Out-Null
            }
        }
    }

    end {
        Write-Verbose "Completed checking for unmerged branches"
    }
}

<#
.SYNOPSIS
    Shows the diff between a specific branch and a target branch.
.DESCRIPTION
    This function displays the differences between a specified branch and a target branch.
    It shows both a summary of changed files and the detailed diff.
.PARAMETER BranchName
    The name of the branch to compare against the target branch.
.PARAMETER TargetBranch
    The name of the target branch (e.g., 'develop', 'staging').
.EXAMPLE
    Show-Diff -BranchName 'HKBP-98/feature_admin-phone-changes' -TargetBranch 'develop'
    Shows the diff between 'HKBP-98/feature_admin-phone-changes' and 'develop'.
.NOTES
    This function requires Git to be installed and accessible in the system PATH.
#>
function Show-Diff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName,

        [Parameter(Mandatory = $true)]
        [string]$TargetBranch
    )

    begin {
        if (-not (Test-IsGitRepository)) {
            Write-Error "Not in a Git repository. Aborting."
            return
        }
        Write-Verbose "Starting diff between '$BranchName' and '$TargetBranch'"
    }

    process {
        try {
            $currentBranch = Get-GitCurrentBranch

            # Show summary of changes
            Write-Host "Summary of changes:" -ForegroundColor Cyan
            git diff --stat "${TargetBranch}...${BranchName}"

            Write-Host "`nDetailed diff:" -ForegroundColor Cyan
            
            # Show detailed diff
            git diff "${TargetBranch}...${BranchName}" | 
            ForEach-Object {
                if ($_ -match '^\+') {
                    Write-Host $_ -ForegroundColor Green
                }
                elseif ($_ -match '^-') {
                    Write-Host $_ -ForegroundColor Red
                }
                elseif ($_ -match '^@@') {
                    Write-Host $_ -ForegroundColor Cyan
                }
                else {
                    Write-Host $_
                }
            }
        }
        catch {
            Write-Error "An error occurred: $_"
        }
        finally {
            # Ensure we switch back to the original branch
            if ($currentBranch) {
                git checkout $currentBranch | Out-Null
            }
        }
    }

    end {
        Write-Verbose "Completed diff between '$BranchName' and '$TargetBranch'"
    }
}

<#
.SYNOPSIS
    Gets the name of the current Git repository.
.DESCRIPTION
    This function retrieves the name of the current Git repository from the remote origin URL.
    It works with both HTTPS and SSH remote URLs.
.EXAMPLE
    Get-Repo
    Returns: "my-repo-name"
.OUTPUTS
    System.String
    Returns the repository name as a string, or $null if it can't be determined.
.NOTES
    Requires Git to be installed and accessible in the system PATH.
    This function depends on Test-IsGitRepository.
#>
function Get-Repo {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    begin {
        Write-Verbose "Starting to fetch Git repository name"
        if (-not (Test-IsGitRepository)) {
            Write-Error "Not in a Git repository. Aborting."
            return $null
        }
    }

    process {
        try {
            $remoteUrl = git config --get remote.origin.url
            if (-not $remoteUrl) {
                Write-Error "No remote origin URL found."
                return $null
            }

            Write-Verbose "Remote URL: $remoteUrl"

            $repoName = $remoteUrl | 
            Select-String -Pattern '(?:https://github\.com/|git@github\.com:)(?:[^/]+)/(.+?)(?:\.git)?$' | 
            ForEach-Object { $_.Matches.Groups[1].Value }

            if (-not $repoName) {
                Write-Error "Failed to extract repository name from the remote URL."
                return $null
            }

            Write-Verbose "Repository name: $repoName"
            return $repoName
        }
        catch {
            Write-Error "An error occurred while fetching the repository name: $_"
            return $null
        }
    }

    end {
        Write-Verbose "Completed fetching Git repository name"
    }
}

<#
.SYNOPSIS
    Gets a list of reviewers based on the project type.
.DESCRIPTION
    This function returns a predefined list of reviewers for different project types.
.PARAMETER ProjectType
    The type of project. Valid values are "BpWeb", "BpApi", and "OrgApi".
.EXAMPLE
    Get-Reviewers -ProjectType "BpWeb"
    Returns a list of reviewers for the BpWeb project.
.OUTPUTS
    System.String[]
    Returns an array of reviewer names.
.NOTES
    The reviewer lists are hardcoded in this function and should be updated as needed.
#>
function Get-Reviewers {
    [CmdletBinding()]
    [OutputType([string[]])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("BpWeb", "BpApi", "OrgApi", "Test")]
        [string]$ProjectType
    )

    switch ($ProjectType) {
        "BpWeb" {
            return @("rorybeling", "rayleneavenu", "ulrich-jvr")
        }
        "BpApi" {
            return @("rorybeling", "ulrich-jvr", "Dietrich-H2", "Zeliard-64", "neljaj")
        }
        "OrgApi" {
            return @("rorybeling", "timothd", "andrei-sadagurschi", "GertRouxAvenu")
        }
        "Test" {
            return @("rorybeling")  # This is now explicitly an array
        }
        default {
            Write-Error "Invalid project type specified."
            return @()
        }
    }
}

function New-PR {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $true)]
        [string]$ToBranch,
        
        [Parameter(Mandatory = $false)]
        [string]$Body = "",

        [Parameter(Mandatory = $true)]
        [ValidateSet("BpWeb", "BpApi", "OrgApi", "Test")]
        [string]$ProjectType,

        [Parameter(Mandatory = $false)]
        [switch]$NoDebug,

        [Parameter(Mandatory = $false)]
        [switch]$NoConfirm
    )

    begin {
        if (-not $NoDebug) { Write-Host "Debug: Starting New-PR function" -ForegroundColor Yellow }

        if (-not (Test-IsGitRepository)) {
            throw "Not in a Git repository."
        }
        if (-not $NoDebug) { Write-Host "Debug: Confirmed current directory is a Git repository" -ForegroundColor Yellow }

        # Get owner and token from environment variables
        $RepoOwner = [Environment]::GetEnvironmentVariable("GITHUB_OWNER", "User")
        $Token = [Environment]::GetEnvironmentVariable("GITHUB_PAT", "User")

        if (-not $NoDebug) { 
            Write-Host "Debug: RepoOwner: $RepoOwner" -ForegroundColor Yellow
            Write-Host "Debug: Token: [REDACTED]" -ForegroundColor Yellow
        }

        if (-not $RepoOwner -or -not $Token) {
            throw "GitHub owner or PAT not found in environment variables. Please set GITHUB_OWNER and GITHUB_PAT."
        }
    }

    process {
        try {
            $RepoName = Get-Repo
            if (-not $NoDebug) { Write-Host "Debug: RepoName: $RepoName" -ForegroundColor Yellow }

            if (-not $RepoName) {
                throw "Failed to determine the repository name."
            }

            $FromBranch = Get-GitCurrentBranch
            if (-not $FromBranch) {
                throw "Failed to determine the current branch."
            }
            if (-not $NoDebug) { Write-Host "Debug: FromBranch: $FromBranch" -ForegroundColor Yellow }

            $apiUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/pulls"
            if (-not $NoDebug) { Write-Host "Debug: API URL: $apiUrl" -ForegroundColor Yellow }
            
            $headers = @{
                Authorization = "token $Token"
                Accept        = "application/vnd.github.v3+json"
            }
            if (-not $NoDebug) { Write-Host "Debug: Headers set (token redacted)" -ForegroundColor Yellow }
            
            $bodyContent = @{
                title = $Title
                head  = $FromBranch
                base  = $ToBranch
                body  = $Body
            }

            if (-not $NoDebug) {
                Write-Host "Debug: Title: $Title" -ForegroundColor Yellow
                Write-Host "Debug: ToBranch: $ToBranch" -ForegroundColor Yellow
                Write-Host "Debug: Body: $Body" -ForegroundColor Yellow
            }

            $Reviewers = Get-Reviewers -ProjectType $ProjectType
            if (-not $NoDebug) {
                Write-Host "Debug: ProjectType: $ProjectType" -ForegroundColor Yellow
                Write-Host "Debug: Reviewers: $($Reviewers -join ', ')" -ForegroundColor Yellow
            }

            if ($Reviewers.Count -gt 0) {
                $bodyContent.Add("reviewers", $Reviewers)
            }

            $bodyJson = $bodyContent | ConvertTo-Json
            if (-not $NoDebug) { Write-Host "Debug: Request body created" -ForegroundColor Yellow }

            if (-not $NoConfirm) {
                $confirmation = Read-Host "Are you sure you want to create this PR? (Y/N)"
                if ($confirmation -ne 'Y') {
                    Write-Host "PR creation cancelled."
                    return
                }
            }

            $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $bodyJson -ContentType "application/json"
            if (-not $NoDebug) { Write-Host "Debug: Pull request created. Response received." -ForegroundColor Yellow }
            Write-Output "Pull request created successfully. PR URL: $($response.html_url)"

            if ($Reviewers.Count -gt 0 -and -not $response.requested_reviewers) {
                $reviewersUrl = "https://api.github.com/repos/$RepoOwner/$RepoName/pulls/$($response.number)/requested_reviewers"
                if (-not $NoDebug) { Write-Host "Debug: Adding reviewers. URL: $reviewersUrl" -ForegroundColor Yellow }
                $reviewersBody = @{
                    reviewers = @($Reviewers)  # Ensure reviewers is an array
                } | ConvertTo-Json

                try {
                    $reviewersResponse = Invoke-RestMethod -Uri $reviewersUrl -Method Post -Headers $headers -Body $reviewersBody -ContentType "application/json"
                    if (-not $NoDebug) { Write-Host "Debug: Reviewers added successfully" -ForegroundColor Yellow }
                    Write-Output "Reviewers added successfully."
                }
                catch {
                    Write-Error "Failed to add reviewers: $_"
                    if (-not $NoDebug) { 
                        Write-Host "Debug: Reviewers body sent:" -ForegroundColor Yellow
                        Write-Host $reviewersBody -ForegroundColor Yellow
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to create pull request or add reviewers: $_"
        }
    }

    end {
        if (-not $NoDebug) { Write-Host "Debug: New-PR function completed" -ForegroundColor Yellow }
    }
}

<#
.SYNOPSIS
    Create a branch that corresponds to a JIRA issue, use the JIRA issue to 
    name the branch, then insert the branch URL into the JIRA issue description.
.DESCRIPTION
    This function creates a new branch based on a JIRA issue key, names the branch
    using the JIRA issue summary and type, pushes the branch to GitHub, and updates 
    the JIRA issue description with the new branch URL.
.EXAMPLE
    New-Issue -JiraKey "PROJ-123" -FromBranch "develop"
    Creates a new branch for JIRA issue PROJ-123, branching from 'develop'.
.PARAMETER JiraKey
    The JIRA issue key (e.g., "PROJ-123").
.PARAMETER FromBranch
    The branch from which the new branch will be created.
#>
function New-Issue {
    [CmdletBinding()]    
    param(
        [Parameter(Mandatory = $true)]
        [string]$JiraKey,

        [Parameter(Mandatory = $true)]
        [string]$FromBranch
    )
    
    begin {
        if (-not (Test-IsGitRepository)) {
            throw "Not in a Git repository."
        }

        # Make sure the FromBranch exists
        if (-not (git rev-parse --verify $FromBranch 2>$null)) {
            throw "The specified FromBranch '$FromBranch' does not exist."
        }

        # Check for uncommitted or unstaged changes
        $status = git status --porcelain
        if ($status) {
            throw "Your branch has uncommitted or unstaged changes. Please commit or stash them before proceeding."
        }

        # Change branch to FromBranch
        git checkout $FromBranch
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to switch to branch '$FromBranch'."
        }
    }
    
    process {
        try {
            $jiraIssue = Get-JiraIssueObject -IssueKey $JiraKey
            if (-not $jiraIssue) {
                throw "Failed to fetch JIRA issue $JiraKey."
            }
        
            $issueSubject = $jiraIssue.summary
            $issueType = $jiraIssue.issuetype.name
        
            # Determine the branch prefix and structure based on issue type
            if ($issueType -eq "Bug") {
                $branchPrefix = "Bug/$($JiraKey.ToUpper())/"
                $branchName = "$branchPrefix$($issueSubject -replace '[^\w\-]', '_')"
            }
            else {
                $branchPrefix = "$($JiraKey.ToUpper())/"
                $branchName = "$branchPrefix$($issueSubject -replace '[^\w\-]', '_')"
            }

            # Convert the part after the prefix to lowercase
            $branchName = $branchPrefix + $branchName.Substring($branchPrefix.Length).ToLower()
        
            # Create and checkout the new branch
            git checkout -b $branchName
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create and checkout new branch '$branchName'."
            }
        
            # Push new branch to GitHub
            git push -u origin $branchName
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to push new branch '$branchName' to remote."
            }
        
            # Get the GitHub URL of the newly created branch
            $repoName = Get-Repo
            $repoOwner = [Environment]::GetEnvironmentVariable("GITHUB_OWNER", "User")
            $branchUrl = "https://github.com/$repoOwner/$repoName/tree/$branchName"
        
            # Update JIRA issue description
            Add-TextToJiraDescription -IssueKey $JiraKey -TextToAdd "`n$repoName Branch: $branchUrl`nBranched from: $FromBranch"
        
            Write-Host "Branch '$branchName' created and pushed successfully." -ForegroundColor Green
            Write-Host "JIRA issue $JiraKey updated with branch information." -ForegroundColor Green
        }
        catch {
            Write-Error "An error occurred: $_"
            # Attempt to clean up if an error occurs
            if (git rev-parse --verify $branchName 2>$null) {
                git checkout $FromBranch
                git branch -D $branchName
                Write-Host "Cleaned up: Switched back to $FromBranch and deleted $branchName locally." -ForegroundColor Yellow
            }
        }
    }
    
    end {
        Write-Host "New-Issue function completed" -ForegroundColor Cyan
    }
}

function Get-ProjectType {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $repo = Get-Repo
    switch ($repo) {
        "BrokerPortalWeb" { return "BpWeb" }
        "Avenu20_BP" { return "BpApi" }
        "Avenu.Organizations" { return "OrgApi" }
        default { return "Test" }
    }
}

<#
.SYNOPSIS
    Shows Git output in Visual Studio Code.
.DESCRIPTION
    This function takes Git show output and displays it in Visual Studio Code.
    It supports showing specific commits or files from specific commits.
.PARAMETER CommitHash
    The commit hash to show. If not provided, defaults to HEAD.
.PARAMETER FileName
    Optional. The specific file to show from the commit.
.EXAMPLE
    Show-GitInVSCode
    Shows the latest commit (HEAD) in VS Code.
.EXAMPLE
    Show-GitInVSCode -CommitHash "abc123"
    Shows the specific commit in VS Code.
.EXAMPLE
    Show-GitInVSCode -CommitHash "abc123" -FileName "README.md"
    Shows the specific file from the specified commit in VS Code.
.NOTES
    Requires Visual Studio Code to be installed and 'code' command to be in PATH.
#>
function Show-Git {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CommitHash = "HEAD",

        [Parameter(Mandatory = $false)]
        [string]$FileName
    )

    begin {
        if (-not (Test-IsGitRepository)) {
            Write-Error "Not in a Git repository. Aborting."
            return
        }

        # Test if VS Code is available
        if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
            Write-Error "Visual Studio Code is not available in PATH. Aborting."
            return
        }
    }

    process {
        try {
            if ($FileName) {
                # Show specific file from commit
                git show "$CommitHash`:$FileName" | code -
            }
            else {
                # Show entire commit
                git show $CommitHash | code -
            }

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to show Git content in VS Code."
            }
        }
        catch {
            Write-Error "An error occurred: $_"
        }
    }
}

function Search-GitHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Pattern,
        
        [Parameter(Mandatory = $false)]
        [int]$LastNCommits = 10
    )

    begin {
        if (-not (Test-IsGitRepository)) {
            throw "Not in a Git repository."
        }
    }

    process {
        try {
            Write-Host "Retrieving commit history..." -ForegroundColor Cyan
            $commits = git rev-list --all -n $LastNCommits
            if (-not $commits) {
                Write-Warning "No commits found in repository."
                return
            }

            Write-Host "Searching through $($commits.Count) commits..." -ForegroundColor Cyan

            foreach ($commit in $commits) {
                git grep $Pattern $commit 2>$null
            }
        }
        catch {
            Write-Error "An error occurred: $_"
        }
    }
}

<#
.SYNOPSIS
    Searches current state of Git branches for a specific string.
.DESCRIPTION
    This function searches through the current state of Git branches for a specific string,
    only reporting branches that currently contain the string, not historical states.
.PARAMETER SearchString
    The exact string to search for in the branches.
.PARAMETER IncludeRemote
    If specified, includes remote branches in the search.
.EXAMPLE
    Find-BranchesContainingString -SearchString "VITE_BP_API_UPLOAD=/api/v1/user/upload-user-photo"
    Shows all branches currently containing the specified string.
#>
function Find-BranchesContainingString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchString,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeRemote
    )

    begin {
        if (-not (Test-IsGitRepository)) {
            Write-Error "Not in a Git repository. Aborting."
            return
        }
        Write-Verbose "Starting search for string: $SearchString"
        
        # Store current branch to return to it later
        $currentBranch = Get-GitCurrentBranch
    }

    process {
        try {
            # Get all branches
            $branches = if ($IncludeRemote) {
                git branch -a | ForEach-Object { $_.Trim() -replace '^[\*\s]+', '' }
            }
            else {
                git branch | ForEach-Object { $_.Trim() -replace '^[\*\s]+', '' }
            }

            $results = @()
            
            foreach ($branch in $branches) {
                Write-Verbose "Checking branch: $branch"
                
                # Skip remote branches if not included
                if (-not $IncludeRemote -and $branch -like "remotes/*") {
                    continue
                }

                # Clean branch name for checkout
                $cleanBranch = $branch -replace '^remotes/origin/', ''
                
                # Checkout branch
                $null = git checkout $cleanBranch 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Verbose "Failed to checkout branch: $cleanBranch"
                    continue
                }

                # Search for string in current branch state
                $found = git grep -l $SearchString 2>&1
                if ($found) {
                    $result = [PSCustomObject]@{
                        Branch = $cleanBranch
                        Files  = $found
                    }
                    $results += $result
                }
            }

            # Display results
            if ($results.Count -gt 0) {
                Write-Host "`nString found in the following branches:" -ForegroundColor Cyan
                foreach ($result in $results) {
                    Write-Host "`nBranch: " -NoNewline -ForegroundColor Yellow
                    Write-Host $result.Branch
                    Write-Host "Present in files:" -ForegroundColor Yellow
                    $result.Files | ForEach-Object { Write-Host "  - $_" }
                }
            }
            else {
                Write-Host "`nString not found in any current branch state." -ForegroundColor Yellow
            }

            return $results
        }
        catch {
            Write-Error "An error occurred: $_"
        }
        finally {
            # Return to original branch
            if ($currentBranch) {
                $null = git checkout $currentBranch 2>&1
            }
        }
    }

    end {
        Write-Verbose "Completed search for string"
    }
}


Export-ModuleMember -Function @(
    'Test-IsGitRepository',
    'Get-GitCurrentBranch',
    'New-MergeBranch',
    'Get-GitPrefix',
    'Get-TopicBranches',
    'Get-Branches',
    'Remove-Branches',
    'Get-UntrackedBranches',
    'Get-UnmergedBranches',
    'Show-Diff',
    'Get-Repo',
    'New-PR',
    'New-Issue',
    'Show-Git',
    'Search-GitHistory',
    'Find-BranchesContainingString'
)