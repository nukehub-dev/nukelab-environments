#!/bin/bash
# SPDX-FileCopyrightText: 2023-2026 NukeHub Developers
# SPDX-License-Identifier: BSD-2-Clause

# Build environment images in dependency order.
# Usage: ./scripts/build.sh [image|all] [--no-cache]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY="${REGISTRY:-ghcr.io/nukelab}"
BASE_TAG="${BASE_TAG:-v1.0.0}"
NO_CACHE=""

if [ -n "${CONTAINER_ENGINE:-}" ]; then
	ENGINE="$CONTAINER_ENGINE"
elif command -v docker >/dev/null 2>&1; then
	ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
	ENGINE="podman"
else
	echo "No container engine found (tried docker, podman)" >&2
	exit 1
fi

usage() {
	cat <<EOF
Usage: $(basename "$0") [image|all] [--no-cache]

Images:
  all                 Build all images in dependency order
  nuclear-base
  radiation-transport
  moose
  cardinal
  openfoam
  gpu-toolkit

Environment variables:
  REGISTRY            Image registry prefix (default: ghcr.io/nukelab)
  BASE_TAG            Version tag for parent images (default: v1.0.0)
EOF
}

build_image() {
	local dir=$1
	local name=$2
	local tag="${REGISTRY}/${name}:${BASE_TAG}"
	echo "==> Building ${tag} from ${dir}/Dockerfile"
	$ENGINE build \
		${NO_CACHE} \
		--build-arg BASE_TAG="${BASE_TAG}" \
		-t "${tag}" \
		-f "${REPO_ROOT}/${dir}/Dockerfile" \
		"${REPO_ROOT}/${dir}"
}

main() {
	local target="${1:-all}"

	if [[ "$target" == "--help" || "$target" == "-h" ]]; then
		usage
		exit 0
	fi

	shift || true
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--no-cache) NO_CACHE="--no-cache" ;;
		--help | -h)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1"
			usage
			exit 1
			;;
		esac
		shift
	done

	case "$target" in
	all)
		build_image nuclear-base nuclear-base
		build_image radiation-transport radiation-transport
		build_image moose moose
		build_image cardinal cardinal
		build_image openfoam openfoam
		build_image gpu-toolkit gpu-toolkit
		;;
	nuclear-base | radiation-transport | moose | cardinal | openfoam | gpu-toolkit)
		build_image "$target" "$target"
		;;
	*)
		echo "Unknown image: $target"
		usage
		exit 1
		;;
	esac

	echo "==> Build complete"
}

main "$@"
