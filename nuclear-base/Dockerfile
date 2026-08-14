# Copyright (c) NukeLab Development Team.
# Distributed under the terms of the BSD-2-Clause license.

# Shared nuclear simulation toolchain.
# Extends the NukeLab conda-base image with MOAB, Double-Down, Geant4, DAGMC,
# libMesh, and NJOY2016. All software lives under /opt/nuke so the image can be
# mounted as a single toolchain volume into the workspace runtime.
ARG BASE_TAG=v1.0.0
ARG BASE_IMAGE=ghcr.io/nukelab/conda-base:${BASE_TAG}
ARG PYTHON_VERSION=3.13
ARG CI_JOBS=4

ARG MOAB_BRANCH="5.5.1"
ARG DOUBLE_DOWN_BRANCH="v1.1.0"
ARG GEANT4_BRANCH="v11.4.2"
ARG DAGMC_BRANCH="v3.2.4"
ARG LIBMESH_BRANCH="v1.8.4"
ARG NJOY2016_BRANCH="2016.79"

ARG DOWNLOAD_GEANT4_DATA=ON

FROM $BASE_IMAGE

WORKDIR /tmp

ARG PYTHON_VERSION
ARG CI_JOBS

ARG MOAB_BRANCH
ARG DOUBLE_DOWN_BRANCH
ARG GEANT4_BRANCH
ARG DAGMC_BRANCH
ARG LIBMESH_BRANCH
ARG NJOY2016_BRANCH

ARG DOWNLOAD_GEANT4_DATA

# Graphics and visualization libraries used by Geant4/ParaView/VTK.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libxft-dev \
        libxext-dev \
        libglu1-mesa-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# All nuclear tooling is installed under /opt/nuke so a single volume mount
# (/opt/nuke) brings the entire toolchain into the workspace container.
ENV NUKE_DIR=/opt/nuke
ENV MOAB_ROOT=${NUKE_DIR}/moab \
    DOUBLE_DOWN_ROOT=${NUKE_DIR}/double-down \
    GEANT4_ROOT=${NUKE_DIR}/geant4 \
    DAGMC_ROOT=${NUKE_DIR}/dagmc \
    LIBMESH_ROOT=${NUKE_DIR}/libmesh \
    NJOY2016_ROOT=${NUKE_DIR}/njoy2016

ENV PATH="${NUKE_DIR}/bin:${MOAB_ROOT}/bin:${DOUBLE_DOWN_ROOT}/lib:${GEANT4_ROOT}/bin:${DAGMC_ROOT}/bin:${LIBMESH_ROOT}/bin:${NJOY2016_ROOT}/bin:${PATH}" \
    LD_LIBRARY_PATH="${MOAB_ROOT}/lib:${DOUBLE_DOWN_ROOT}/lib:${GEANT4_ROOT}/lib:${DAGMC_ROOT}/lib:${LIBMESH_ROOT}/lib:${NJOY2016_ROOT}/lib"

# Create the shared conda prefix that child images extend.
RUN conda create --yes -p ${NUKE_DIR} \
        python=${PYTHON_VERSION} \
        ipykernel \
        trame \
        paraview \
        cadquery \
        pythonocc-core \
        python-gmsh && \
    conda clean --all -f -y

# Register /opt/nuke as a system-wide envs_dir so the runtime user sees it.
RUN conda config --system --append envs_dirs /opt/nuke

# Activation script used by the runtime container after mounting /opt/nuke.
RUN mkdir -p /opt/nuke/etc
COPY nuke-env.sh /opt/nuke/etc/toolchain-env.sh

# Generate the toolchain manifest by sourcing the activation script in a clean
# environment. The generator is installed by the conda-base ancestor image as
# /usr/local/bin/nukelab-generate-toolchain-manifest.
ARG TOOLCHAIN_VERSION=dev
RUN nukelab-generate-toolchain-manifest \
    --name nuclear-base \
    --version "${TOOLCHAIN_VERSION}"

# Install MOAB
RUN --mount=type=cache,target=/root/.ccache \
    git clone -b ${MOAB_BRANCH} --depth 1 https://bitbucket.org/fathomteam/moab && \
    cd moab && \
    mkdir build && cd build && \
    pip install --no-cache-dir numpy cython && \
    cmake ../ \
        -DCMAKE_INSTALL_PREFIX=${MOAB_ROOT} \
        -DENABLE_HDF5=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DENABLE_PYMOAB=OFF && \
    make -j${CI_JOBS} && make install && \
    pip uninstall --yes cython && \
    rm -rf /tmp/moab

# Install Double-Down
RUN --mount=type=cache,target=/root/.ccache \
    git clone -b ${DOUBLE_DOWN_BRANCH} https://github.com/pshriwise/double-down.git && \
    cd double-down && \
    mkdir build && cd build && \
    cmake ../ \
        -DCMAKE_INSTALL_PREFIX=${DOUBLE_DOWN_ROOT} \
        -DMOAB_DIR=${MOAB_ROOT} && \
    make -j${CI_JOBS} && make install && \
    rm -rf /tmp/double-down

# Install Geant4
ENV GEANT4_DATA_DIR=${GEANT4_ROOT}/share/data
RUN --mount=type=cache,target=/root/.ccache \
    mkdir geant4 && cd geant4 && \
    wget https://github.com/Geant4/geant4/archive/refs/tags/${GEANT4_BRANCH}.tar.gz && \
    tar -xzvf ${GEANT4_BRANCH}.tar.gz && \
    cd $(tar tzf ${GEANT4_BRANCH}.tar.gz | head -1 | cut -f1 -d"/") && \
    mkdir -p build && cd build && \
    cmake ../ \
        -DCMAKE_INSTALL_PREFIX=${GEANT4_ROOT} \
        -DGEANT4_USE_QT=OFF \
        -DGEANT4_USE_OPENGL_X11=OFF \
        -DGEANT4_USE_SYSTEM_EXPAT=OFF \
        -DGEANT4_BUILD_TLS_MODEL=global-dynamic \
        -DGEANT4_BUILD_MULTITHREADED=ON \
        -DGEANT4_INSTALL_DATA=${DOWNLOAD_GEANT4_DATA} \
        -DGEANT4_INSTALL_DATADIR=${GEANT4_DATA_DIR} \
        -DGEANT4_INSTALL_DATA_TIMEOUT=0 && \
    make -j${CI_JOBS} && make install && \
    rm -rf /tmp/geant4

# Install DAGMC
RUN --mount=type=cache,target=/root/.ccache \
    git clone -b ${DAGMC_BRANCH} https://github.com/svalinn/DAGMC.git && \
    cd DAGMC && \
    mkdir build && cd build && \
    cmake ../ \
        -DCMAKE_INSTALL_PREFIX=${DAGMC_ROOT} \
        -DMOAB_DIR=${MOAB_ROOT} \
        -DBUILD_GEANT4=ON \
        -DGEANT4_DIR=${GEANT4_ROOT} \
        -DDOUBLE_DOWN=ON \
        -Ddd_ROOT=${DOUBLE_DOWN_ROOT} && \
    make -j${CI_JOBS} && make install && \
    rm -rf /tmp/DAGMC

# Install LibMesh
RUN --mount=type=cache,target=/root/.ccache \
    git clone --depth 1 -b ${LIBMESH_BRANCH} https://github.com/libMesh/libmesh.git && \
    cd libmesh && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    ../configure \
        --prefix=${LIBMESH_ROOT} \
        --disable-mpi && \
    make -j${CI_JOBS} && make install && \
    rm -rf /tmp/libmesh

# Install NJOY2016
RUN --mount=type=cache,target=/root/.ccache \
    git clone --depth 1 -b ${NJOY2016_BRANCH} https://github.com/njoy/NJOY2016.git && \
    cd NJOY2016 && \
    mkdir build && cd build && \
    cmake ../ \
        -DCMAKE_BUILD_TYPE=Release && \
    make -j${CI_JOBS} && \
    mkdir -p ${NJOY2016_ROOT}/bin && \
    cp njoy ${NJOY2016_ROOT}/bin/ && \
    cd .. && rm -rf /tmp/NJOY2016
