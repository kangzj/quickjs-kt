#!/usr/bin/env bash
# Builds :quickjs for every target and publishes it to this fork's `maven` branch,
# the Maven repository Yonto resolves io.github.kangzj from.
#
# Needs what README's Development section lists: run `bun scripts/setupMultiplatformJdks.ts`
# once, and have Zig 0.12.0 (what publish.yaml pins), CMake, Ninja, Xcode and the Android NDK.
# ZIG_HOME, when set, is put first on PATH.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "The working tree has changes; publish from a commit." >&2
  exit 1
fi
git submodule update --init --recursive

version="$(sed -n 's/^VERSION_NAME=//p' gradle.properties)"
group_path="$(sed -n 's/^GROUP=//p' gradle.properties | tr . /)"
commit="$(git rev-parse HEAD)"

# shellcheck source=/dev/null
source "$HOME/java-home-vars.sh"
[[ -n "${ZIG_HOME:-}" ]] && export PATH="$ZIG_HOME:$PATH"
[[ "$(zig version)" == "0.12.0" ]] || { echo "Zig 0.12.0 is needed, found $(zig version)." >&2; exit 1; }

repo="$root/build/yonto-maven"
rm -r -f -- "$repo"
./gradlew :quickjs:publishAllPublicationsToYontoRepository -Dyonto.repo="$repo" \
  --init-script scripts/yonto-repo.init.gradle.kts --no-configuration-cache

pages="$root/build/maven-branch"
rm -r -f -- "$pages"
if git ls-remote --exit-code --heads origin maven >/dev/null; then
  git fetch origin maven
  git worktree add --force "$pages" origin/maven --detach
else
  git worktree add --force --detach "$pages"
  git -C "$pages" checkout --orphan maven
  git -C "$pages" rm -r -q -f .
fi
trap 'git worktree remove --force "$pages"' EXIT

if ls "$pages/$group_path"/*/"$version" >/dev/null 2>&1; then
  echo "$version is already on the maven branch; bump VERSION_NAME rather than replace it." >&2
  exit 1
fi
mkdir -p "$pages/$group_path"
cp -R "$repo/$group_path/." "$pages/$group_path/"
git -C "$pages" add -A
git -C "$pages" commit -q -m "Publish $version from $commit"
git -C "$pages" push origin HEAD:refs/heads/maven
echo "Published $version. Pin settings.gradle.kts to maven commit $(git -C "$pages" rev-parse HEAD)."
