#!/bin/bash

setup_or_clone_repo() {
    if [ -d "$REPO_PATH" ]; then
        cd "$REPO_PATH"
        echo "Repository $REPO_NAME already exists locally. Updating..."
        git fetch origin
        git reset --hard origin/master || true
    else
        mkdir -p "$REPO_PATH"
        cd "$REPO_PATH"
        echo "Cloning repository $REPO_NAME..."
        if ! git clone "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git" . 2>/dev/null; then
            echo "Repository doesn't exist on GitHub. Creating a new one..."
            git init
            git remote add origin "https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"
            git clone "https://github.com/$GITHUB_USERNAME/website.git" .
            git add .
            git commit -m "Initial commit from template repository"
            git push -u origin master
        fi
    fi
}

update_repo_from_template() {
    local template_repo="website"
    local template_remote="template"
    local temp_branch="temp_update_branch_$$"
    local original_branch=$(git rev-parse --abbrev-ref HEAD)

    echo "Updating from template repository..."

    if git show-ref --quiet refs/heads/$temp_branch; then
        git worktree remove -f $temp_branch 2>/dev/null || true
        git branch -D $temp_branch 2>/dev/null || true
    fi

    if ! git remote | grep -q "^${template_remote}$"; then
        git remote add ${template_remote} "https://github.com/$GITHUB_USERNAME/$template_repo.git"
    fi

    git fetch ${template_remote}
    local template_default_branch=$(git remote show ${template_remote} | grep 'HEAD branch' | cut -d' ' -f5)
    git checkout -b $temp_branch

    if ! git merge -X theirs --no-commit --no-ff "${template_remote}/${template_default_branch}"; then
        echo "Failed to merge changes from template. Aborting merge and returning to original state."
        git merge --abort
        git checkout $original_branch
        git branch -D $temp_branch
        git remote remove ${template_remote}
        return 1
    fi

    git reset HEAD .domain .content .logo
    git checkout -- .domain .content .logo

    update_terraform_files

    git add .
    git commit -m "Update from template repository" || true

    git checkout $original_branch
    if ! git merge --no-ff $temp_branch -m "Merge template updates"; then
        echo "Failed to merge changes into the original branch. Please resolve conflicts manually."
        git merge --abort
        echo "Changes from the template are in the '$temp_branch' branch."
        git remote remove ${template_remote}
        return 1
    fi

    git branch -D $temp_branch
    git remote remove ${template_remote}

    echo "Successfully updated from template repository."
}

update_terraform_files() {
    if [ -f terraform/backend.tf ]; then
        sed -i'' "s/DOMAIN_NAME_PLACEHOLDER/$DOMAIN_NAME/g" terraform/backend.tf
    else
        echo "Warning: terraform/backend.tf not found. Skipping customization."
    fi

    if [ -f scripts/setup_terraform.sh ]; then
        sed -i'' "s/DOMAIN_NAME_PLACEHOLDER/$DOMAIN_NAME/g" scripts/setup_terraform.sh
    else
        echo "Warning: scripts/setup_terraform.sh not found. Skipping customization."
    fi

    rm -f scripts/setup_terraform.sh-e terraform/backend.tf-e
}
