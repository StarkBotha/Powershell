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
            throw "Your branch has uncommitted or unstaged changes. Please commit or stash them before proceeding.kek"
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
    'Show-Diff'
)