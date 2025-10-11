# Upstream Reference Files

This directory contains reference copies of configuration files from the upstream `langgenius/dify` repository.

## Purpose

These files are automatically copied during the sync process from `sdks/python-client/` directory in the upstream repository. They serve as references for manually merging configuration changes into our root-level config files.

## Files

- **README.md** - Upstream documentation for reference
- **pyproject.toml** - Upstream dependency configuration for reference

## Usage

When the sync workflow creates a PR:

1. Review files in this directory to see upstream changes
2. Compare with root-level config files (e.g., `/README.md`, `/pyproject.toml`)
3. Manually merge relevant changes to root config files
4. If `pyproject.toml` dependencies changed, run `uv lock` to regenerate `uv.lock`

## Note

**Do not use these files directly** - they are for reference only. Our repository may have customizations that should be preserved during merges.
