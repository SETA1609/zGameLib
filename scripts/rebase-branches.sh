#!/usr/bin/env bash
# Rebase all living branches onto the target branch (default: main).
# Runs on push to main or dev — keeps feature branches up to date.
# Branches with conflicts are SKIPPED (rebase aborted, not force-pushed).
set -euo pipefail

TARGET="${1:-main}"

git fetch origin --prune

CURRENT=$(git rev-parse --abbrev-ref HEAD)

# When rebasing onto dev, skip main (main is the root, not a child).
EXCLUDE="origin/$TARGET\$"
if [ "$TARGET" = "dev" ]; then
    EXCLUDE="$EXCLUDE|origin/main\$"
fi

for branch in $(git branch -r | grep -vE "$EXCLUDE" | grep -v 'origin/HEAD' | sed 's|origin/||'); do
    echo "==> Rebase: $branch onto $TARGET ..."

    git checkout -q "$branch" 2>/dev/null || git checkout -q -b "$branch" "origin/$branch"

    if git rebase "origin/$TARGET"; then
        git push origin "$branch" --force-with-lease 2>&1 | grep -v "Everything up-to-date" || true
        echo "  ✅ $branch rebased and pushed"
    else
        echo "  ❌ $branch has conflicts — aborting, branch left alone"
        git rebase --abort
    fi
done

git checkout -q "$CURRENT"
