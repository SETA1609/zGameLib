#!/usr/bin/env bash
# Run a command (default: bash) in the agent container: the build image plus Claude Code and uv.
# The home is the named volume personal-agent-home (override with AGENT_HOME_VOLUME), which
# keeps the agent's Claude login and git identity. The host's ~/.claude, ~/.gitconfig, and SSH
# keys are not mounted, so the container can commit but not push.
# Usage: ./scripts/agent.sh
#        ./scripts/agent.sh claude
set -euo pipefail

repository_directory="$(cd "$(dirname "$0")/.." && pwd -P)"
agent_home_volume="${AGENT_HOME_VOLUME:-personal-agent-home}"

echo "==> Building zgamelib-builder and zgamelib-agent..."
docker build -q -t zgamelib-builder -f "${repository_directory}/docker/Dockerfile" \
    "${repository_directory}" >/dev/null
docker build -q -t zgamelib-agent -f "${repository_directory}/docker/agent.Dockerfile" \
    --build-arg BASE_IMAGE=zgamelib-builder \
    --build-arg AGENT_USER_ID="$(id -u)" \
    --build-arg AGENT_GROUP_ID="$(id -g)" \
    "${repository_directory}" >/dev/null

# The checkout is mounted at its host path. When it is a submodule or a worktree, .git is a file
# pointing outside the checkout, so that git directory is mounted at its host path too.
git_directory_arguments=()
git_common_directory="$(git -C "${repository_directory}" rev-parse --path-format=absolute \
    --git-common-dir)"
case "${git_common_directory}" in
    "${repository_directory}"/*) ;;
    *) git_directory_arguments=(-v "${git_common_directory}:${git_common_directory}") ;;
esac

terminal_arguments=(-i)
if [ -t 0 ]; then
    terminal_arguments+=(-t)
fi

if [ "$#" -eq 0 ]; then
    set -- bash
fi

exec docker run --rm "${terminal_arguments[@]}" \
    -v "${agent_home_volume}:/home/agent" \
    -v "${repository_directory}:${repository_directory}" \
    "${git_directory_arguments[@]}" \
    -w "${repository_directory}" \
    zgamelib-agent "$@"
