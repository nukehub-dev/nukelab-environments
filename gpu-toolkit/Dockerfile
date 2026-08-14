# Copyright (c) NukeLab Development Team.
# Distributed under the terms of the BSD-2-Clause license.

# GPU toolchain: NVIDIA CUDA toolkit mounted into the workspace runtime.
ARG BASE_TAG=v1.0.0
ARG BASE_IMAGE=ghcr.io/nukelab/conda-base:${BASE_TAG}
ARG CUDA_VERSION=12.6

FROM $BASE_IMAGE

ARG CUDA_VERSION
ARG BASE_TAG

# Install the CUDA toolkit under /opt/nuke/cuda so the whole /opt/nuke
# directory can be mounted as a single toolchain volume.
RUN mkdir -p /opt/nuke/cuda && \
    conda install -y -c nvidia --prefix /opt/nuke/cuda cuda-toolkit=${CUDA_VERSION} && \
    conda clean -afy

# Activation script and manifest for runtime composition.
COPY toolchain-env.sh /opt/nuke/etc/toolchain-env.sh
RUN python3 - <<'PY'
import json, os, re
script = "/opt/nuke/etc/toolchain-env.sh"
env = {}
with open(script) as f:
    for line in f:
        line = line.strip()
        if line.startswith("export "):
            for assignment in line[7:].split():
                if "=" in assignment:
                    key, val = assignment.split("=", 1)
                    if val.startswith('"') and val.endswith('"'):
                        val = val[1:-1]
                    env[key] = val
manifest = {
    "name": "gpu-toolkit",
    "version": os.environ.get("BASE_TAG", "v1.0.0"),
    "mounts": ["/opt/nuke"],
    "env": env
}
with open("/opt/nuke/nukelab-toolchain.json", "w") as f:
    json.dump(manifest, f, indent=2)
PY

# Advertise GPU access to the NVIDIA container runtime.
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
