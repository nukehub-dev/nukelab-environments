# SPDX-FileCopyrightText: 2023-2026 NukeHub Developers
# SPDX-License-Identifier: BSD-2-Clause
# shellcheck shell=bash

# Activate the GPU toolchain environment.
# CUDA is installed under /opt/nuke/cuda and mounted into the workspace runtime.
NUKE_DIR="${NUKE_DIR:-/opt/nuke}"

PATH="${NUKE_DIR}/cuda/bin${PATH:+:${PATH}}"
LD_LIBRARY_PATH="${NUKE_DIR}/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

export PATH LD_LIBRARY_PATH
