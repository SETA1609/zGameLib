#!/usr/bin/env python3
import json
import os
import sys
import urllib.request


def main():
    repo = sys.argv[1]
    token = os.environ.get("GH_TOKEN", "")

    url = f"https://api.github.com/repos/{repo}/actions/workflows/build.yml/runs"
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        print(f"::error::GitHub API error: {e.code} {e.reason}")
        sys.exit(1)

    # Find the latest completed run on dev
    for run in data.get("workflow_runs", []):
        if run["head_branch"] == "dev" and run["status"] == "completed":
            conclusion = run["conclusion"]
            if conclusion != "success":
                print(
                    f"::error::Latest CI run on 'dev' concluded with "
                    f"'{conclusion}' \u2014 must be 'success' before merging to main"
                )
                print(
                    f"::error::Visit https://github.com/{repo}/actions"
                    f"?query=branch:dev to check"
                )
                sys.exit(1)
            print("\u2705 Latest CI run on 'dev' passed")
            return

    print(
        "::warning::No completed CI run found on 'dev' branch "
        "\u2014 cannot verify status"
    )


if __name__ == "__main__":
    main()
