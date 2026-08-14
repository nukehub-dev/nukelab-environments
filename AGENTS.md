# NukeLab Environments

## Purpose

Scientific computing toolchain images and build pipelines for the NukeLab
platform. Toolchain images are mounted as volumes into the `nukelab-workspace`
runtime container rather than extending it.

## Ownership

All files under this repository root.

## Local Contracts

- Each subdirectory under the root (except `scripts/` and `.github/`) defines one
  published toolchain image.
- Toolchain images must inherit from a published NukeLab parent image
  (`ghcr.io/nukelab/conda-base` for roots, or another published toolchain image
  for extensions). They must never depend on local-only tags.
- Every toolchain image installs software under `/opt/nuke` so the whole
  directory can be mounted as a single volume into the workspace runtime.
- Every toolchain image must provide:
  - `/opt/nuke/etc/toolchain-env.sh` — activation script exporting `PATH`,
    `LD_LIBRARY_PATH`, and any required variables.
  - `/opt/nuke/nukelab-toolchain.json` — manifest generated during the image
    build by `nukelab-generate-toolchain-manifest --name <name> --version
    "${TOOLCHAIN_VERSION}"` (installed at `/usr/local/bin/` by the conda-base
    ancestor image). The generator sources the activation script in a clean
    environment and captures the variables it sets. PATH-family variables
    (`PATH`, `LD_LIBRARY_PATH`, etc.) go to `env_prepend`, all other
    script-set variables to `env`; values are fully resolved absolute values
    (no `${...}` shell syntax). `TOOLCHAIN_VERSION` is passed by
    `scripts/build.sh` (git describe, or `dev`).
- `nuclear-base/` owns the shared toolchain used by `radiation-transport/`,
  `moose/`, and `cardinal/`. Changes here trigger rebuilds of all dependent
  images.
- Large data downloads (cross-sections, chain files, Geant4 data) must use
  separate scripts or cache mounts so layer rebuilds are incremental.
- Build scripts live in `scripts/` and must be POSIX/Bash 4+ compatible.
- The NAD framework from the main `nukelab` repository applies here; this
  `AGENTS.md` is the local contract for environment-specific work.

## Work Guidance

- Keep images minimal; use multi-stage builds where the build toolchain can be
  separated from the runtime image.
- Use BuildKit cache mounts (`--mount=type=cache`) for C++ compilation and
  package managers.
- Pin upstream versions with `ARG`s at the top of each Dockerfile.
- Large datasets (cross-sections, chain files) live under `/opt/nuke/data/<name>`
  so data is visibly separate from code; Geant4 datasets are the exception and
  stay at Geant4's native `${NUKE_DIR}/geant4/share/data` (its discovery
  machinery is tied to the install tree). A future enhancement may move big
  datasets to a dedicated shared data volume so code and data refresh
  independently — see the main repo `docs/plan/DECISION-LOG.md` (2026-08-15).
- Do not bake secrets or credentials into images.
- Update this `AGENTS.md` and `README.md` when adding, removing, or reparenting
  an environment image.

## Verification

```bash
./scripts/build.sh all
```

## Child NAD Index

- None
