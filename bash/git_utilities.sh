#!/bin/bash

# Function to check if current directory is a Git repository
is_git_repository() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to get current Git branch
get_git_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Function to create a new merge branch
new_merge_branch() {
    local target_branch="$1"
    
    if [ "$(is_git_repository)" != "true" ]; then
        echo "Not in a Git repository." >&2
        return 1
    fi

    local original_branch=$(get_git_current_branch)
    if [ -z "$original_branch" ]; then
        echo "Failed to get current branch." >&2
        return 1
    fi

    # Check for uncommitted or unstaged changes
    if [ -n "$(git status --porcelain)" ]; then
        echo "Your branch has uncommitted or unstaged changes. Please commit or stash them before proceeding." >&2
        return 1
    fi

    # Check for unpushed commits
    if [ -n "$(git log origin/$original_branch..$original_branch)" ]; then
        echo "You have unpushed commits on your branch." >&2
        read -p "Do you want to push these commits before proceeding? (Y/N) " push
        if [[ $push =~ ^[Yy]$ ]]; then
            git push || { echo "Failed to push commits. Please push manually and try again." >&2; return 1; }
            echo "Commits pushed successfully."
        else
            echo "Operation aborted. Please push your commits and try again." >&2
            return 1
        fi
    fi

    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local branch_prefix=$(get_git_prefix "$original_branch")
    local new_branch_name="${branch_prefix}/merge_${target_branch}_$timestamp"

    # Perform Git operations
    git checkout "$target_branch" && \
    git pull && \
    git checkout "$original_branch" && \
    git checkout -b "$new_branch_name" && \
    if ! git merge "$target_branch"; then
        echo "Merge conflicts occurred." >&2
        git checkout "$original_branch"
        return 1
    fi

    # Check for differences
    if [ -z "$(git diff $target_branch $new_branch_name)" ]; then
        echo "No differences found between $new_branch_name and $target_branch."
        git checkout "$original_branch"
        git branch -D "$new_branch_name"
        echo "Cleaned up: Switched back to $original_branch and deleted $new_branch_name."
        return 0
    fi

    # Push new branch
    if ! git push --set-upstream origin "$new_branch_name"; then
        echo "Failed to push new branch $new_branch_name." >&2
        git checkout "$original_branch"
        return 1
    fi

    echo "Successfully created and pushed merge branch: $new_branch_name"
    git checkout "$original_branch"
}

# Function to get Git prefix
get_git_prefix() {
    local branch_name="$1"
    local prefix=${branch_name%/*}
    if [ "$prefix" = "$branch_name" ]; then
        echo "$branch_name"
    else
        echo "$prefix"
    fi
}

# Function to get topic branches
get_topic_branches() {
    local branch_name="$1"
    [ -z "$branch_name" ] && branch_name=$(get_git_current_branch)
    
    local prefix=$(get_git_prefix "$branch_name")
    git branch -a --format="%(refname:short)" | grep "^$prefix"
}

# Function to get branches containing a string
get_branches() {
    local contains_string="$1"
    local include_remote="$2"

    local branches=$(git branch | grep "$contains_string" | sed 's/^\*\?\s*//')
    
    if [ "$include_remote" = "true" ]; then
        local remote_branches=$(git branch -r | grep "$contains_string" | sed 's/^\s*origin\///')
        branches+=$'\n'$remote_branches
    fi

    echo "$branches" | sort -u
}

# Function to remove branches
remove_branches() {
    local contains_string="$1"
    local include_remote="$2"

    local current_branch=$(get_git_current_branch)
    local branches=$(get_branches "$contains_string" "$include_remote")

    if [ -z "$branches" ]; then
        echo "No branches found containing '$contains_string'"
        return
    fi

    echo "The following branches will be deleted:"
    echo "$branches"
    read -p "Do you want to continue? (Y/N) " confirmation
    if [ "$confirmation" != "Y" ] && [ "$confirmation" != "y" ]; then
        echo "Operation aborted by user."
        return
    fi

    while IFS= read -r branch; do
        if [ "$branch" = "$current_branch" ]; then
            echo "Cannot delete the current branch '$branch'. Skipping."
            continue
        fi

        if [[ $branch == origin/* ]]; then
            remote_name=${branch%%/*}
            remote_branch_name=${branch#*/}
            echo "Deleting remote branch: $branch"
            git push "$remote_name" --delete "$remote_branch_name"
        else
            if git branch --list | grep -q "$branch"; then
                remote_branch=$(git for-each-ref --format='%(upstream:short)' refs/heads/"$branch")
                if [ -n "$remote_branch" ]; then
                    remote_name=${remote_branch%%/*}
                    remote_branch_name=${remote_branch#*/}
                    echo "Deleting remote tracking branch: $remote_branch"
                    git push "$remote_name" --delete "$remote_branch_name"
                fi
                echo "Deleting local branch: $branch"
                git branch -D "$branch"
            else
                echo "Local branch not found: $branch. It may be a remote-only branch."
                if git ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
                    echo "Deleting remote branch: origin/$branch"
                    git push origin --delete "$branch"
                else
                    echo "Remote branch not found: origin/$branch. Skipping."
                fi
            fi
        fi
    done <<< "$branches"
}

# Main script logic can go here
# You can call the functions as needed

# Example usage:
# new_merge_branch "develop"
# get_topic_branches "feature/123"
# remove_branches "merge_" "true"

#make it executable with chmod +x git_utilities.sh, 
#and then you can source it in your Bash sessions or other scripts 
#with . ./git_utilities.sh or source ./git_utilities.sh.