#!/usr/bin/env bash
# Creates a throwaway private repo under the current gh-authenticated
# user, seeds a commit, and prints clone URL + token + cleanup name as
# JSON to stdout. Requires `gh` CLI authenticated with scopes: `repo`.
set -euo pipefail

REPO_NAME="libgit2-swift-it-$(date +%s)-$$"
gh repo create "$REPO_NAME" --private --confirm >/dev/null
gh api --method PUT "repos/:owner/$REPO_NAME/contents/README.md" \
  -f message="seed" -f content="$(printf 'hi\n' | base64)" >/dev/null

TOKEN=$(gh auth token)
REPO_URL=$(gh repo view "$REPO_NAME" --json url -q '.url').git
printf '{"repo_url":"%s","token":"%s","cleanup_name":"%s"}\n' \
  "$REPO_URL" "$TOKEN" "$REPO_NAME"
