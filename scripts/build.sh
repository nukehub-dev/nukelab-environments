#!/bin/bash
# SPDX-FileCopyrightText: 2023-2026 NukeHub Developers
# SPDX-License-Identifier: BSD-2-Clause

# Build environment images in dependency order.
#
# Images are discovered automatically from subdirectories containing a
# Dockerfile. Dependencies are read from ARG BASE_IMAGE in each Dockerfile.
# Images that depend on "conda-base" are treated as roots (conda-base is built
# elsewhere). Every other dependency must resolve to another discovered image.
#
# Usage: ./scripts/build.sh [image|all] [--no-cache] [--push] [--parallel]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY="${REGISTRY:-ghcr.io/nukehub-dev}"
BASE_TAG="${BASE_TAG:-v1.0.0}"
SHA_TAG="${SHA_TAG:-}"
TOOLCHAIN_VERSION="${TOOLCHAIN_VERSION:-$(git -C "$REPO_ROOT" describe --tags --always --dirty 2>/dev/null || echo dev)}"
NO_CACHE=""
PUSH=""
PARALLEL=""

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
Usage: $(basename "$0") [image|all] [--no-cache] [--push] [--parallel]

Images:
  all                 Build all images in dependency order
  <image>             Build a single image (parent must already exist)

Options:
  --no-cache          Disable the layer cache
  --push              Push images after building
  --parallel          Build independent images within each dependency level
                      in parallel (default is sequential)

Environment variables:
  REGISTRY            Image registry prefix (default: ghcr.io/nukehub-dev)
  BASE_TAG            Primary tag for images and parent/child references
                      (default: v1.0.0)
  SHA_TAG             Optional additional tag, e.g. sha-abcdef1
  TOOLCHAIN_VERSION   Version recorded in toolchain manifests
                      (default: git describe, or "dev" outside a git checkout)
  CONTAINER_ENGINE    Force docker or podman
EOF
}

# Collect image directories in deterministic order.
discover_images() {
	mapfile -t DOCKERFILES < <(find "$REPO_ROOT" -maxdepth 2 -name Dockerfile \
		-not -path "$REPO_ROOT/scripts/*" \
		-not -path "$REPO_ROOT/.github/*" |
		sort)
	for dockerfile in "${DOCKERFILES[@]}"; do
		basename "$(dirname "$dockerfile")"
	done
}

# Return the in-repo parent image name from ARG BASE_IMAGE, or empty.
parent_of() {
	local image=$1
	local dockerfile="$REPO_ROOT/$image/Dockerfile"
	local base_image
	base_image=$(grep -E '^ARG BASE_IMAGE=' "$dockerfile" 2>/dev/null | head -1 | cut -d= -f2- || true)
	if [ -z "$base_image" ]; then
		echo ""
		return
	fi
	base_image=${base_image//\"/}
	base_image=${base_image//\'/}
	printf '%s' "$base_image" | sed -E 's|^.*/([^/:]+):.*$|\1|'
}

# Topologically sort discovered images by dependency depth.
# Prints "<level> <image>" per line, sorted by level then image name.
# Parents that are not discovered in this repository (e.g. base images built
# elsewhere) are treated as external roots with depth 0.
sort_images() {
	local -a all_images
	local -A parents
	local -A depth
	local -A discovered

	mapfile -t all_images < <(discover_images)

	if [ ${#all_images[@]} -eq 0 ]; then
		echo "No Dockerfiles found" >&2
		exit 1
	fi

	for image in "${all_images[@]}"; do
		discovered["$image"]=1
		parents["$image"]=$(parent_of "$image")
		depth["$image"]=0
	done

	# Iteratively propagate depths until stable. Skip parents that are not
	# discovered locally; they are external images and this repo cannot build
	# them, so treat them as roots.
	local changed=1
	while [ "$changed" -eq 1 ]; do
		changed=0
		for image in "${all_images[@]}"; do
			parent="${parents[$image]:-}"
			if [ -n "$parent" ] && [ -n "${discovered[$parent]:-}" ]; then
				new_depth=$((depth[$parent] + 1))
				if [ "$new_depth" -gt "${depth[$image]}" ]; then
					depth["$image"]=$new_depth
					changed=1
				fi
			fi
		done
	done

	# Print images sorted by depth, then alphabetically.
	for image in "${all_images[@]}"; do
		echo "${depth[$image]} $image"
	done | sort -n -k1,1 -k2,2
}

# Return all tags for an image as separate -t arguments.
image_tags() {
	local name=$1
	printf ' -t %s/%s:%s' "$REGISTRY" "$name" "$BASE_TAG"
	if [ -n "$SHA_TAG" ]; then
		printf ' -t %s/%s:%s' "$REGISTRY" "$name" "$SHA_TAG"
	fi
}

# Push all tags for an image.
push_image() {
	local name=$1
	local tag="${REGISTRY}/${name}:${BASE_TAG}"
	echo "==> Pushing ${tag}"
	$ENGINE push "${tag}"
	if [ -n "$SHA_TAG" ]; then
		local sha_tag="${REGISTRY}/${name}:${SHA_TAG}"
		echo "==> Pushing ${sha_tag}"
		$ENGINE push "${sha_tag}"
	fi
}

build_image() {
	local name=$1
	local tag_args
	tag_args=$(image_tags "$name")
	echo "==> Building ${REGISTRY}/${name} from ${name}/Dockerfile"
	# shellcheck disable=SC2086
	$ENGINE build \
		${NO_CACHE} \
		--build-arg REGISTRY="${REGISTRY}" \
		--build-arg BASE_TAG="${BASE_TAG}" \
		--build-arg TOOLCHAIN_VERSION="${TOOLCHAIN_VERSION}" \
		${tag_args} \
		-f "${REPO_ROOT}/${name}/Dockerfile" \
		"${REPO_ROOT}/${name}"
	if [ -n "$PUSH" ]; then
		push_image "$name"
	fi
}

# Build a single level of images. If --parallel is set, run builds in the
# background and wait for completion before returning.
build_level() {
	local -a level_images=("$@")
	if [ ${#level_images[@]} -eq 0 ]; then
		return
	fi

	if [ -n "$PARALLEL" ]; then
		local -a pids=()
		for image in "${level_images[@]}"; do
			build_image "$image" &
			pids+=("$!")
		done
		local failed=0
		for pid in "${pids[@]}"; do
			if ! wait "$pid"; then
				failed=1
			fi
		done
		if [ "$failed" -eq 1 ]; then
			exit 1
		fi
	else
		for image in "${level_images[@]}"; do
			build_image "$image"
		done
	fi
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
		--push) PUSH="1" ;;
		--parallel) PARALLEL="1" ;;
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
		local sort_images_output
		sort_images_output=$(sort_images) || exit 1
		mapfile -t build_order <<< "$sort_images_output"

		# Group by dependency level so --parallel can run independent images
		# within a level at the same time.
		local current_level=-1
		local -a level_images=()
		for line in "${build_order[@]}"; do
			read -r level image <<<"$line"
			if [ "$level" -ne "$current_level" ] && [ "$current_level" -ne -1 ]; then
				build_level "${level_images[@]}"
				level_images=()
			fi
			current_level=$level
			level_images+=("$image")
		done
		if [ ${#level_images[@]} -gt 0 ]; then
			build_level "${level_images[@]}"
		fi
		;;
	*)
		# Validate the requested image exists.
		if [ ! -f "${REPO_ROOT}/${target}/Dockerfile" ]; then
			echo "Unknown image: $target" >&2
			usage >&2
			exit 1
		fi
		build_image "$target"
		;;
	esac

	echo "==> Build complete"
}

main "$@"
