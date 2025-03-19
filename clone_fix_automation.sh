#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Define the branch to checkout before running 'make gen'
BRANCH="branch_name"  # Change this value to the desired branch
ORIGINAL_WA_ROOT="$(pwd)"

# Define repositories and their corresponding directories
declare -A repos=(
  ["dummy_repo_1"]="repo_link.git"
  ["dummy_repo_2"]="repo_link.git"
  ["dummy_repo_3"]="repo_link.git"
  ["dummy_repo_3"]="repo_link.git"
)

# Function to remove existing repositories
remove_repos() {
  echo "🔴 Removing existing repositories..."
  for dir in "${!repos[@]}"; do
    rm -rf "$dir"
  done
  echo "✅ Repositories removed successfully."
}

# Function to clone repositories
clone_repos() {
  echo "🌍 Cloning repositories..."
  for dir in "${!repos[@]}"; do
    git clone "${repos[$dir]}" "$dir"
  done
  echo "✅ Repositories cloned successfully."
}

# Function to run 'make gen' in each directory after checking out the branch
generate_build() {
  echo "⚙️  Running 'make gen' in each repository..."    
  for dir in "${!repos[@]}"; do
    (
      cd "$dir"

      # Ensure we are on the correct branch before running commands
      git fetch origin "$BRANCH"
      git checkout "$BRANCH" || echo "⚠️ Branch $BRANCH not found, staying on current branch."

      # Check if cache exists and matches latest commit hash
      GIT_HASH=$(git rev-parse HEAD)
      if [[ -f ".cache_status" && "$(cat .cache_status)" == "$GIT_HASH" ]]; then
        echo "✅ $dir is already up to date, skipping 'make gen'..."
        continue
      fi

      # Suppress specific error messages from .init
      source .init 2>&1 | grep -Ev "Docker launch script was changed|ERROR: \$WA_ROOT is not the current directory!|Please exit this container via 'exit' command and rerun 'source .init'" || true      

      # Run make gen, log errors, and store cache
      make gen 
       # Special case: If the repo is "sub/ares", run the extra command
      if [[ "$dir" == "sub/ares" ]]; then
        echo "🔧 Running extra command for sub/ares: make gen.cmod_dpi"
        make gen.cmod_dpi
      fi
      echo "$GIT_HASH" > .cache_status
    )
  done    
  echo "✅ generate process completed."
}

# Function to run extra commands after the script
extra_commands() {
  echo "⚙️  Running 'make gen.base' in mercury ..."
  echo "WA_ROOT SET TO :: $WA_ROOT"

  export WA_ROOT="$ORIGINAL_WA_ROOT"
  
  echo "WA_ROOT Setting back to  :: $WA_ROOT"

  # cd "$WA_ROOT"

  # Suppress known error messages from .init
  source .init 2>&1 | grep -Ev "Docker launch script was changed|ERROR: \$WA_ROOT is not the current directory!" || true  

  make gen.base  
  echo "✅ extra_commands completed."
}


# Function to show usage instructions
usage() {
  echo "🚀 **Automated Repository Management Script** 🚀"
  echo
  echo "This script automates the process of managing repositories. It can:"
  echo "  - Remove existing cloned repositories"
  echo "  - Clone fresh copies from GitLab"
  echo "  - Checkout a specific branch and run 'make gen'"
  echo
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  -r, --remove      🔴 Remove existing repositories"
  echo "  -c, --clone       🌍 Clone repositories from GitLab"
  echo "  -g, --generate    ⚙️  Checkout branch and run 'make gen' in each repository"
  echo "  -e, --extra       ⚙️  Run 'make gen.base' only"
  echo "  -a, --all         🚀 Run all steps (remove → clone → checkout & build)"
  echo "  -h, --help        📖 Show this help message"
  echo
  echo "Examples:"
  echo "  ./common_clone_fix.sh --remove          # Remove old repositories"
  echo "  ./common_clone_fix.sh --clone           # Clone repositories only"
  echo "  ./common_clone_fix.sh --generate        # Checkout branch and run 'make gen'"
  echo "  ./common_clone_fix.sh --extra           # Run 'make gen.base' only"
  echo "  ./common_clone_fix.sh --all             # Run everything"
  echo
  echo "✨ Created for efficient repo management!"
  exit 0
}

# If no arguments are provided, show usage
if [[ $# -eq 0 ]]; then
  usage
fi

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--remove)   remove_repos ;;
    -c|--clone)    clone_repos ;;
    -g|--generate) generate_build ;;
    -e|--extra)    extra_commands ;;
    -a|--all)      remove_repos; clone_repos; generate_build; extra_commands ;;
    -h|--help)     usage ;;
    *) echo "❌ Invalid option: $1"; usage ;;
  esac
  shift
done
