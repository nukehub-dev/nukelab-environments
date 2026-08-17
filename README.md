# NukeLab Environments

Scientific computing toolchain images for the NukeLab platform.

## Purpose

This repository contains **domain-specific toolchain images** that are mounted
into the NukeLab workspace runtime at container start time. Keeping them
separate from the main platform repository allows:

- Independent versioning and release cadence per environment
- Workspace/IDE updates without rebuilding heavy C++/Fortran scientific stacks
- Domain-specific maintainers and review rules
- Heavy CI runners dedicated to long compile jobs
- A clear contract between the platform runtime and the scientific software it
  hosts

## Runtime composition

NukeLab servers are created from two independent images:

1. **Runtime image** (`nukelab-workspace`) — nginx, auth sidecar, IDE, conda
   base. Built in the main `nukelab/nukelab` repository.
2. **Toolchain image** (`nukelab-nuclear-base`, `nukelab-radiation-transport`,
   `nukelab-gpu-toolkit`, etc.) — scientific software installed under
   `/opt/nuke`. Built in this repository.

At spawn time the backend:

- Creates a named volume from the toolchain image
- Mounts it at `/opt/nuke` inside the workspace container
- Injects the environment variables declared in the toolchain manifest

This means updating `nukelab-workspace` (e.g., a new IDE version) does **not**
force MOAB, Geant4, or OpenMC to recompile.

## Image hierarchy

```text
ghcr.io/nukehub-dev/base
└── ghcr.io/nukehub-dev/conda-base          # shared conda/Python/build foundation
    ├── ghcr.io/nukehub-dev/workspace       # runtime image (IDE)
    ├── ghcr.io/nukehub-dev/nuclear-base    # toolchain image
    │   ├── ghcr.io/nukehub-dev/radiation-transport
    │   ├── ghcr.io/nukehub-dev/moose
    │   └── ghcr.io/nukehub-dev/cardinal
    ├── ghcr.io/nukehub-dev/gpu-toolkit     # toolchain image
    └── ghcr.io/nukehub-dev/openfoam        # toolchain image
```

`base` and `conda-base` are built and published from the main `nukelab/nukelab`
repository. All toolchain images in this repo inherit from `ghcr.io/nukehub-dev/conda-base`.

## Toolchain contract

Every toolchain image must:

- Install software under `/opt/nuke` so the whole directory can be mounted as a
  single volume.
- Provide `/opt/nuke/etc/toolchain-env.sh`, which exports `PATH`,
  `LD_LIBRARY_PATH`, and any other required variables.
- Provide `/opt/nuke/nukelab-toolchain.json`, a manifest describing mounts and
  env vars. The manifest is generated during the image build by
  `nukelab-generate-toolchain-manifest` (installed at `/usr/local/bin/` by the
  conda-base ancestor image), which sources `toolchain-env.sh` in a clean
  environment (`env -i NUKE_DIR=/opt/nuke`) and captures the variables it
  sets, so all values are fully resolved (no `${...}` shell syntax).
  PATH-family variables (`PATH`, `LD_LIBRARY_PATH`, `LIBRARY_PATH`, `CPATH`,
  `C_INCLUDE_PATH`, `CPLUS_INCLUDE_PATH`, `PKG_CONFIG_PATH`, `PYTHONPATH`,
  `MANPATH`) go into `env_prepend`; all other script-set variables go into
  `env`. Invoke it right after copying the activation script:

  ```dockerfile
  ARG TOOLCHAIN_VERSION=dev
  RUN nukelab-generate-toolchain-manifest \
      --name <image-name> \
      --version "${TOOLCHAIN_VERSION}"
  ```

  `scripts/build.sh` passes `TOOLCHAIN_VERSION` (git describe, or `dev`).

Example manifest:

```json
{
  "name": "radiation-transport",
  "version": "v1.0.0-3-gdeadbee",
  "mounts": ["/opt/nuke"],
  "env": {
    "OPENMC_DATA_DIR": "/opt/nuke/data/openmc"
  },
  "env_prepend": {
    "PATH": "/opt/nuke/bin:/opt/nuke/moab/bin:...",
    "LD_LIBRARY_PATH": "/opt/nuke/moab/lib:..."
  }
}
```

## Repository layout

| Directory | Image | Kind | Description |
|-----------|-------|------|-------------|
| `nuclear-base/` | `ghcr.io/nukehub-dev/nuclear-base` | toolchain | MOAB, Double-Down, Geant4, DAGMC, libMesh, NJOY2016 |
| `radiation-transport/` | `ghcr.io/nukehub-dev/radiation-transport` | toolchain | OpenMC, PyNE, KDSource, ALARA, cross-section data |
| `moose/` | `ghcr.io/nukehub-dev/moose` | toolchain | MOOSE framework scaffold |
| `cardinal/` | `ghcr.io/nukehub-dev/cardinal` | toolchain | MOOSE + OpenMC coupling scaffold |
| `openfoam/` | `ghcr.io/nukehub-dev/openfoam` | toolchain | OpenFOAM CFD scaffold |
| `gpu-toolkit/` | `ghcr.io/nukehub-dev/gpu-toolkit` | toolchain | NVIDIA CUDA toolkit |
| `scripts/` | — | — | Shared build helpers and CI entry points |

## Build locally

Set the parent image version you want to build against:

```bash
export BASE_TAG=v1.0.0
./scripts/build.sh radiation-transport
```

To build all images in dependency order:

```bash
./scripts/build.sh all
```

BuildKit cache mounts are used for C++ compilation. To disable the layer cache:

```bash
./scripts/build.sh radiation-transport --no-cache
```

## CI / Registry

Images are built and published by GitHub Actions to `ghcr.io/nukehub-dev/<image>`.
The workflow in `.github/workflows/build-images.yml` runs `./scripts/build.sh`,
which discovers Dockerfiles automatically, topologically sorts images by their
`ARG BASE_IMAGE` dependencies, and builds each dependency level in parallel.
Both Docker and Podman are supported via auto-detection (or `CONTAINER_ENGINE`).
Adding a new image does not require editing the workflow or build script.

## Adding a new environment

1. Create a new directory under this repo root.
2. Inherit from a published NukeLab parent image via `ARG BASE_IMAGE=...`.
3. Install everything under `/opt/nuke`.
4. Provide `toolchain-env.sh` and generate the manifest with
   `nukelab-generate-toolchain-manifest` (copy the two-line pattern from
   `nuclear-base/` or `radiation-transport/`).
5. Update the image hierarchy diagram in this README.

No workflow or build-script edits are required; both `./scripts/build.sh` and
`.github/workflows/build-images.yml` discover the new image automatically.
