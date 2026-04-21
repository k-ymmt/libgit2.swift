#!/usr/bin/env bash
# Deletes a GitHub repo created by setup-github-fixture.sh. Usage:
#   teardown-github-fixture.sh <cleanup_name>
set -euo pipefail
gh repo delete "$1" --yes
