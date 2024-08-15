#!/bin/bash

set -euo pipefail

# Source helper functions
source scripts/env_checks.sh
source scripts/git_operations.sh
source scripts/domain_management.sh

# Check required environment variables
check_env_variables

# Get or prompt for domain name and repo path
get_domain_and_repo

# Setup or clone the repository
setup_or_clone_repo

# Update repo from template
update_repo_from_template

# Setup website repo
setup_website_repo "$@"

# Cleanup
cleanup
