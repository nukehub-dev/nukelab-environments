# SPDX-FileCopyrightText: 2023-2026 NukeHub Developers
# SPDX-License-Identifier: BSD-2-Clause
# shellcheck shell=bash

# Activate the radiation-transport toolchain environment.
# All tooling lives under /opt/nuke so the whole directory can be mounted as a
# single toolchain volume into the workspace runtime.
NUKE_DIR="${NUKE_DIR:-/opt/nuke}"

PATH="${NUKE_DIR}/bin:${NUKE_DIR}/moab/bin:${NUKE_DIR}/double-down/lib:${NUKE_DIR}/geant4/bin:${NUKE_DIR}/dagmc/bin:${NUKE_DIR}/libmesh/bin:${NUKE_DIR}/njoy2016/bin:${NUKE_DIR}/openmc/bin:${NUKE_DIR}/kdsource/bin:${NUKE_DIR}/alara/bin${PATH:+:${PATH}}"
LD_LIBRARY_PATH="${NUKE_DIR}/moab/lib:${NUKE_DIR}/double-down/lib:${NUKE_DIR}/geant4/lib:${NUKE_DIR}/dagmc/lib:${NUKE_DIR}/libmesh/lib:${NUKE_DIR}/njoy2016/lib:${NUKE_DIR}/openmc/lib:${NUKE_DIR}/kdsource/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
OPENMC_DATA_DIR="${NUKE_DIR}/openmc_data"
OPENMC_CROSS_SECTIONS="${OPENMC_DATA_DIR}/lib80x_hdf5/cross_sections.xml"
OPENMC_CHAIN_FILE="${OPENMC_DATA_DIR}/chain/chain_endfb80_thermal.xml"

export PATH LD_LIBRARY_PATH OPENMC_DATA_DIR OPENMC_CROSS_SECTIONS OPENMC_CHAIN_FILE

# Activate the conda env in login/interactive shells.
if [ -d "${NUKE_DIR}/bin" ]; then
	conda activate "${NUKE_DIR}" >/dev/null 2>&1 || true
fi
