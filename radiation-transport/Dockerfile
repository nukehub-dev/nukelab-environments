# Copyright (c) NukeLab Development Team.
# Distributed under the terms of the BSD-2-Clause license.

# Radiation transport toolchain.
# Extends nukelab-nuclear-base with OpenMC, PyNE, KDSource, ALARA, and data.
# All software lives under /opt/nuke so the image can be mounted as a single
# toolchain volume into the workspace runtime.
ARG BASE_TAG=v1.0.0
ARG BASE_IMAGE=ghcr.io/nukelab/nuclear-base:${BASE_TAG}
ARG CI_JOBS=4
ARG PYTHON_VERSION=3.13

ARG OPENMC_BRANCH="v0.15.3"
ARG KDSOURCE_BRANCH="v0.2.2"
ARG PYNE_BRANCH="scikit-build-core"
ARG ALARA_BRANCH="main"

ARG DOWNLOAD_CROSS_SECTION_DATA=ON
ARG DOWNLOAD_CHAIN_DATA=ON

FROM $BASE_IMAGE

WORKDIR /tmp

ARG CI_JOBS
ARG PYTHON_VERSION

ARG OPENMC_BRANCH
ARG KDSOURCE_BRANCH
ARG PYNE_BRANCH
ARG ALARA_BRANCH

ARG DOWNLOAD_CROSS_SECTION_DATA
ARG DOWNLOAD_CHAIN_DATA

# Extend the nuclear-base environment variables with radiation-transport tools.
# Everything is under /opt/nuke for a single volume mount.
ENV NUKE_DIR=/opt/nuke
ENV OPENMC_ROOT=${NUKE_DIR}/openmc \
    KDSOURCE_ROOT=${NUKE_DIR}/kdsource \
    ALARA_ROOT=${NUKE_DIR}/alara \
    OPENMC_DATA_DIR=${NUKE_DIR}/openmc_data \
    OPENMC_CROSS_SECTIONS=${OPENMC_DATA_DIR}/lib80x_hdf5/cross_sections.xml \
    OPENMC_CHAIN_FILE=${OPENMC_DATA_DIR}/chain/chain_endfb80_thermal.xml

ENV PATH="${OPENMC_ROOT}/bin:${KDSOURCE_ROOT}/bin:${ALARA_ROOT}/bin:${PATH}" \
    LD_LIBRARY_PATH="${OPENMC_ROOT}/lib:${KDSOURCE_ROOT}/lib:${LD_LIBRARY_PATH}"

# Update the toolchain activation script and regenerate the manifest by
# sourcing it in a clean environment, so the spawner sees the fully resolved
# radiation-transport paths and env vars. The generator is installed by the
# conda-base ancestor image as /usr/local/bin/nukelab-generate-toolchain-manifest.
COPY nuke-env.sh /opt/nuke/etc/toolchain-env.sh
ARG TOOLCHAIN_VERSION=dev
RUN nukelab-generate-toolchain-manifest \
    --name radiation-transport \
    --version "${TOOLCHAIN_VERSION}"

# Install OpenMC
RUN --mount=type=cache,target=/root/.ccache \
    git clone -b ${OPENMC_BRANCH} https://github.com/openmc-dev/openmc.git && \
    cd openmc && mkdir build && cd build && \
    cmake ../ \
        -DCMAKE_INSTALL_PREFIX=${OPENMC_ROOT} \
        -DOPENMC_USE_DAGMC=ON \
        -DDAGMC_DIR=${DAGMC_ROOT} \
        -DOPENMC_USE_LIBMESH=ON \
        -DCMAKE_PREFIX_PATH=${LIBMESH_ROOT} && \
    make -j${CI_JOBS} && make install && \
    cd .. && pip install --no-cache-dir . && \
    rm -rf /tmp/openmc

# Download cross-section and depletion chain data
COPY --chmod=755 download_cross_sections.sh download_chain_files.sh .
RUN ./download_cross_sections.sh ${DOWNLOAD_CROSS_SECTION_DATA} ${OPENMC_DATA_DIR} && \
    ./download_chain_files.sh ${DOWNLOAD_CHAIN_DATA} ${OPENMC_DATA_DIR} && \
    rm download_cross_sections.sh download_chain_files.sh

# Install PyNE
RUN --mount=type=cache,target=/root/.ccache \
    git clone -b ${PYNE_BRANCH} https://github.com/pyne/pyne.git && \
    cd pyne && \
    export SKBUILD_CMAKE_ARGS="-DDOWNLOAD_EIGEN3=OFF; \
        -DDOWNLOAD_LAPACK=OFF; \
        -DDOWNLOAD_BLAS=OFF; \
        -DDOWNLOAD_HDF5=OFF; \
        -DDOWNLOAD_MOAB=OFF; \
        -DMOAB_ROOT=${MOAB_ROOT}; \
        -DDOWNLOAD_DAGMC=OFF; \
        -DDAGMC_ROOT=${DAGMC_ROOT}" && \
    pip -v install --no-cache-dir . && \
    nuc_data_make && \
    cd .. && rm -rf pyne

# KDSource's CMake invokes `mcpl-config --show cmakedir`, so install the MCPL
# Python package (which provides the utility and CMake files) first.
RUN pip install --no-cache-dir mcpl

# Install KDSource
RUN --mount=type=cache,target=/root/.ccache \
    git clone -b ${KDSOURCE_BRANCH} --recurse-submodules https://github.com/KDSource/KDSource.git && \
    cd KDSource && mkdir build && cd build && \
    cmake ../ \
        -DCMAKE_INSTALL_PREFIX=${KDSOURCE_ROOT} && \
    make -j${CI_JOBS} && make install && \
    rm -rf /tmp/KDSource

# Install ALARA
RUN --mount=type=cache,target=/root/.ccache \
    git clone -b ${ALARA_BRANCH} --depth 1 https://github.com/svalinn/ALARA && \
    cd ALARA && \
    mkdir build && cd build && \
    cmake ../ \
        -DCMAKE_INSTALL_PREFIX=${ALARA_ROOT} && \
    make -j${CI_JOBS} && make install && \
    rm -rf /tmp/ALARA

# Install remaining Python packages from PyPI and GitHub.
RUN pip install --no-cache-dir \
        --extra-index-url https://shimwell.github.io/wheels \
        moab \
        montepy \
        ncrystal \
        paramak \
        plasmapy \
        geant4-pybind \
        vmecpp \
        git+https://github.com/svalinn/pydagmc@4afa678d24aa091417798ef4b3d11fda98b165f8
