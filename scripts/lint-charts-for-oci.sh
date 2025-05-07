#!/usr/bin/env bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

error=0
quiet=0
files=()

# Parse command-line arguments for quiet mode and directory/files
while getopts "q" opt; do
  case $opt in
    q)
      quiet=1
      ;;
    *)
      echo "Usage: $0 [-q] [directory or file(s)]" >&2
      exit 1
      ;;
  esac
done

# Check if there are additional arguments (either directory or files)
shift $((OPTIND - 1))

if [ $# -gt 0 ]; then
  # If arguments are provided, consider them as file paths or directories
  files=("$@")
else
  # If no arguments, default to current directory
  files=(".")
fi

check_chart_file() {
  local chart_file="$1"

  [[ "$(basename "$chart_file")" != "Chart.yaml" ]] && return

  if [ $quiet -eq 0 ]; then
    echo "Checking $chart_file..."
  fi

  # Extract all lines with 'repository:' key
  repositories=$(grep -E '^\s*repository:' "$chart_file" | sed -E 's/.*repository:\s*//')

  # If no repository lines found, chart is valid
  if [[ -z "$repositories" ]]; then
    if [ $quiet -eq 0 ]; then
      echo -e "${GREEN}✔ No repository fields found in $chart_file — considered valid.${NC}"
    fi
    return
  fi

  local has_error=0
  while IFS= read -r repo; do
    # Trim whitespace
    repo=$(echo "$repo" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ ! "$repo" =~ ^oci:// ]]; then
      echo -e "${RED}❌ Non-OCI repository found in $chart_file:${NC} $repo"
      has_error=1
      error=1
    fi
  done <<< "$repositories"

  if [[ $has_error -eq 0 ]] && [ $quiet -eq 0 ]; then
    echo -e "${GREEN}✔ All repositories in $chart_file use oci:// protocol.${NC}"
  fi
}

# Process the provided files or directories
for item in "${files[@]}"; do
  if [ -d "$item" ]; then
    # If it's a directory, find all Chart.yaml files within it
    while IFS= read -r chart_file; do
      check_chart_file "$chart_file"
    done < <(find "$item" -type f -name 'Chart.yaml')
  elif [ -f "$item" ]; then
    # If it's a file, check that specific Chart.yaml file
    check_chart_file "$item"
  else
    echo -e "${RED}❌ Invalid file or directory: $item${NC}"
    exit 1
  fi
done

if [ $error -eq 0 ]; then
  if [ $quiet -eq 0 ]; then
    echo -e "${GREEN}✅ All charts passed OCI repository check.${NC}"
  fi
else
  echo -e "${RED}❗ Some charts failed OCI repository check.${NC}"
  exit 1
fi
