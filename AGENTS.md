# Repository Guidelines

## Project Structure & Modules
- `scripts/`: Deploy/operate (e.g., `deploy.sh`, provider scripts, `prod_deploy_preview.sh`).
- `manifests/`: Kubernetes kustomize bases, middleware, finops, and security fixes (YAML).
- `finops/`: Python FinOps controller + tests and `requirements.txt`.
- `middleware/`: Flask-based middleware (deployed via manifests).
- `frontend/`: UI assets.
- `tests/`: Shell/Python validation (`test-suite.sh`, hook validators).
- `docs/`, `configs/`: Additional documentation and config.

## Build, Test, and Dev Commands
- Setup hooks: `pip install pre-commit && pre-commit install` (then `pre-commit run --all-files`).
- Local validation: `./test-local.sh` (offline-friendly manifest/security checks).
- Full suite: `./tests/test-suite.sh` or targeted Python tests (e.g., `python3 tests/test_middleware.py`).
- Deploy preview: `./scripts/deploy.sh --provider=gke` (or `eks|aks`).
- Production preview: `./scripts/prod_deploy_preview.sh [--provider=gke|aws|azure]`.

## Coding Style & Naming
- Python: 4-space indent, `snake_case` for files/functions; tests `tests/test_*.py`.
- Shell: POSIX/Bash with `set -euo pipefail`; filenames `kebab-case.sh`; pass `shellcheck`.
- YAML/Docs: Keep manifests minimal and kustomize-friendly; run `yamllint` and `markdownlint` via pre-commit.
- Tools: Pre-commit runs `shellcheck`, `yamllint`, markdown checks, and standard hygiene hooks.

## Testing Guidelines
- Prefer adding/adjusting tests alongside changes (Python unit tests, `tests/hooks/*` validators, and manifest checks).
- Run `./test-local.sh` and `pre-commit run --all-files` before pushing.
- For FinOps tests: `python3 -m venv finops-venv && source finops-venv/bin/activate && pip install -r finops/requirements.txt && python3 finops/tests/test_basic.py`.

## Commit & Pull Request Guidelines
- Commits: Imperative, present tense; scoped subjects (e.g., `scripts: add retry logic`). Keep to one logical change per commit.
- PRs: Clear description, linked issues, what/why, and risk/rollback notes. Include logs or screenshots (e.g., `kubectl` output) when relevant.
- Checks: CI must pass; run local tests and pre-commit; avoid noisy diffs (whitespace/format-only).

## Security & Configuration
- Never commit secrets; use environment variables and Kubernetes `Secret` manifests. Review `manifests/sec_fixes/` for GKE-specific hardening.
- Validate dependencies: `./verify-dependencies.sh`.
- Use approved regions/zones; follow provider scripts' validation.

## Agent Notes
- Prefer existing scripts and validators over new tooling.
- Avoid networked steps in tests unless required; rely on offline validation when possible.
