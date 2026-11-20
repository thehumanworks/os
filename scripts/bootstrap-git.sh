#!/usr/bin/env bash
set -euo pipefail

doppler secrets get GITHUB_ENTERPRISE_TOKEN --project global --config dev --plain | gh auth login --hostname leadforensics.ghe.com --with-token
gh auth setup-git --hostname leadforensics.ghe.com

doppler secrets get GITHUB_TOKEN --project global --config dev --plain | gh auth login --hostname github.com --with-token
gh auth setup-git --hostname github.com
