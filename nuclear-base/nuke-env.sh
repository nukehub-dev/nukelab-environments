# SPDX-FileCopyrightText: 2023-2026 NukeHub Developers
# SPDX-License-Identifier: BSD-2-Clause
# shellcheck shell=bash

# Activate the shared nuclear toolchain environment.
# All tooling lives under /opt/nuke so the whole directory can be mounted as a
# single toolchain volume into the workspace runtime.
NUKE_DIR="${NUKE_DIR:-/opt/nuke}"

PATH="${NUKE_DIR}/bin:${NUKE_DIR}/moab/bin:${NUKE_DIR}/double-down/lib:${NUKE_DIR}/geant4/bin:${NUKE_DIR}/dagmc/bin:${NUKE_DIR}/libmesh/bin:${NUKE_DIR}/njoy2016/bin${PATH:+:${PATH}}"
LD_LIBRARY_PATH="${NUKE_DIR}/moab/lib:${NUKE_DIR}/double-down/lib:${NUKE_DIR}/geant4/lib:${NUKE_DIR}/dagmc/lib:${NUKE_DIR}/libmesh/lib:${NUKE_DIR}/njoy2016/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

export PATH LD_LIBRARY_PATH

# Activate the conda env in login/interactive shells.
if [ -d "${NUKE_DIR}/bin" ]; then
	conda activate "${NUKE_DIR}" >/dev/null 2>&1 || true
fi
