#!/usr/bin/env bash
# Check that the latest CI run on the dev branch passed.
set -euo pipefail

REPO="$1"

# Get the latest completed workflow run on dev for the CI workflow
RUN_JSON=$(gh api "repos/$REPO/actions/workflows/build.yml/runs" \
    --jq '.workflow_runs[] | select(.head_branch == "dev" and .status == "completed") | .conclusion' \
    --paginate 2>/dev/null | head -1)

if [ -z "$RUN_JSON" ]; then
    echo "::warning::No completed CI run found on 'dev' branch — cannot verify status"
    exit 0
fi

if [ "$RUN_JSON" != "success" ]; then
    echo "::error::Latest CI run on 'dev' concluded with '$RUN_JSON' — must be 'success' before merging to main"
    echo "::error::Visit https://github.com/$REPO/actions?query=branch:dev to check"
    exit 1
fi

echo "✅ Latest CI run on 'dev' passed"
