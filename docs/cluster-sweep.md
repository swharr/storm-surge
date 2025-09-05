# Cluster Sweep Tool (`cluster-sweep.sh`)

This script safely resets your Kubernetes cluster to a clean state, preserving only the core system and hyperscaler-specific components. It is especially useful for repeatable testing and demo environments.

## Features

- Detects and prompts for Kubernetes context
- Performs a dry run or real destructive cleanup
- Preserves:
  - `kube-system`
  - `default`
  - `kube-public`
  - `kube-node-lease`
  - Known hyperscaler namespaces
- Deregisters Ocean Controller and deletes associated CRDs
- Outputs actions to a log file

## Usage

```bash
chmod +x scripts/cleanup/cluster-sweep.sh
./scripts/cleanup/cluster-sweep.sh --dry-run   # Simulate
./scripts/cleanup/cluster-sweep.sh --force     # Actually clean
```

## Warning

Use with caution! This script is designed to clear everything not explicitly protected. Double-check dry runs before using `--force`.

## Output

- Logs saved to: `cluster-cleanup-<timestamp>.log`
- Supports GitHub runner environments and interactive CLI sessions
