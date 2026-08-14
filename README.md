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
ghcr.io/nukelab/base
└── ghcr.io/nukelab/conda-base          # shared conda/Python/build foundation
    ├── ghcr.io/nukelab/workspace       # runtime image (IDE)
    ├── ghcr.io/nukelab/nuclear-base    # toolchain image
    │   ├── ghcr.io/nukelab/radiation-transport
    │   ├── ghcr.io/nukelab/moose
    │   └── ghcr.io/nukelab/cardinal
    ├── ghcr.io/nukelab/gpu-toolkit     # toolchain image
    └── ghcr.io/nukelab/openfoam        # toolchain image
```

`base` and `conda-base` are built and published from the main `nukelab/nukelab`
repository. All toolchain images in this repo inherit from `ghcr.io/nukelab/conda-base`.

## Toolchain contract

Every toolchain image must:

- Install software under `/opt/nuke` so the whole directory can be mounted as a
  single volume.
- Provide `/opt/nuke/etc/toolchain-env.sh`, which exports `PATH`,
  `LD_LIBRARY_PATH`, and any other required variables.
- Provide `/opt/nuke/nukelab-toolchain.json`, a manifest describing mounts and
  env vars. The manifest is generated automatically from
  `toolchain-env.sh` during the image build.

Example manifest:

```json
{
  "name": "radiation-transport",
  "version": "v1.0.0",
  "mounts": ["/opt/nuke"],
  "env": {
    "PATH": "/opt/nuke/bin:/opt/nuke/moab/bin:...:${PATH}",
    "LD_LIBRARY_PATH": "/opt/nuke/moab/lib:...:${LD_LIBRARY_PATH}"
  }
}
```

## Repository layout

| Directory | Image | Kind | Description |
|-----------|-------|------|-------------|
| `nuclear-base/` | `ghcr.io/nukelab/nuclear-base` | toolchain | MOAB, Double-Down, Geant4, DAGMC, libMesh, NJOY2016 |
| `radiation-transport/` | `ghcr.io/nukelab/radiation-transport` | toolchain | OpenMC, PyNE, KDSource, ALARA, cross-section data |
| `moose/` | `ghcr.io/nukelab/moose` | toolchain | MOOSE framework scaffold |
| `cardinal/` | `ghcr.io/nukelab/cardinal` | toolchain | MOOSE + OpenMC coupling scaffold |
| `openfoam/` | `ghcr.io/nukelab/openfoam` | toolchain | OpenFOAM CFD scaffold |
| `gpu-toolkit/` | `ghcr.io/nukelab/gpu-toolkit` | toolchain | NVIDIA CUDA toolkit |
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

Images are built and published by GitHub Actions to `ghcr.io/nukelab/<image>`.
See `.github/workflows/build-images.yml` for the matrix build configuration.

## Adding a new environment

1. Create a new directory under this repo root.
2. Inherit from `ghcr.io/nukelab/conda-base`.
3. Install everything under `/opt/nuke`.
4. Provide `toolchain-env.sh` and generate the manifest (copy the pattern from
   `nuclear-base/` or `radiation-transport/`).
5. Add the directory to the build matrix in `.github/workflows/build-images.yml`
   and to `scripts/build.sh`.
6. Update the image hierarchy diagram in this README.
