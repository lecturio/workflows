#!/bin/bash

REPO_PATH="${WF_REPO%.git}"

if [[ "$REPO_PATH" =~ ^git@github\.com:([^/]+)/(.+)$ ]]; then
	GH_OWNER="${BASH_REMATCH[1]}"
	GH_REPO="${BASH_REMATCH[2]}"
elif [[ "$REPO_PATH" =~ ^https://github\.com/([^/]+)/(.+)$ ]]; then
	GH_OWNER="${BASH_REMATCH[1]}"
	GH_REPO="${BASH_REMATCH[2]}"
else
	print_err "WF_REPO must point at github.com (ssh or https): $WF_REPO"
	exit 1
fi

PR_URL="https://github.com/${GH_OWNER}/${GH_REPO}/compare/master...${WF_TASK}?expand=1"
print_msg "$PR_URL"
