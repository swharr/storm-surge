# Storm Surge Makefile
# Useful commands for development and maintenance

.PHONY: help
help: ## Show this help message
	@echo "Storm Surge Development Commands"
	@echo "================================"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: fix-whitespace
fix-whitespace: ## Fix trailing whitespace in all project files
	@echo "🧹 Fixing trailing whitespace..."
	@./scripts/fix-whitespace.sh

.PHONY: test
test: ## Run all tests
	@echo "🧪 Running tests..."
	@python3 tests/test_middleware.py
	@python3 tests/test_security.py
	@python3 tests/test_authentication.py
	@python3 tests/test_scripts.py

.PHONY: test-security
test-security: ## Run security tests only
	@echo "🛡️ Running security tests..."
	@python3 tests/test_security.py

.PHONY: pre-commit
pre-commit: ## Run pre-commit hooks on all files
	@echo "🔍 Running pre-commit hooks..."
	@pre-commit run --all-files

.PHONY: install-hooks
install-hooks: ## Install Git hooks for the project
	@echo "📦 Installing Git hooks..."
	@git config core.hooksPath .githooks
	@echo "✅ Git hooks installed from .githooks/"
	@echo "   Pre-commit hook will automatically fix whitespace"

.PHONY: install-pre-commit
install-pre-commit: ## Install pre-commit framework
	@echo "📦 Installing pre-commit..."
	@pip install pre-commit
	@pre-commit install
	@echo "✅ Pre-commit installed"

.PHONY: clean
clean: ## Clean up generated files and caches
	@echo "🧹 Cleaning up..."
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@rm -rf coverage/ test-logs/ .coverage
	@echo "✅ Cleanup complete"

.PHONY: validate
validate: ## Validate all manifests and configurations
	@echo "✅ Validating configurations..."
	@./test-local.sh

.PHONY: format
format: fix-whitespace ## Format all code (includes whitespace fixes)
	@echo "📝 Formatting code..."
	@if command -v black &> /dev/null; then \
		black tests/ manifests/middleware/ finops/; \
	else \
		echo "⚠️  black not installed, skipping Python formatting"; \
	fi

.PHONY: lint
lint: ## Run linters on the codebase
	@echo "🔍 Running linters..."
	@if command -v flake8 &> /dev/null; then \
		flake8 tests/ manifests/middleware/ finops/ --max-line-length=120; \
	else \
		echo "⚠️  flake8 not installed, skipping Python linting"; \
	fi

.PHONY: check
check: fix-whitespace lint test ## Run all checks (whitespace, lint, tests)
	@echo "✅ All checks complete!"

.PHONY: ci
ci: ## Run CI pipeline locally
	@echo "🚀 Running CI pipeline locally..."
	@make fix-whitespace
	@make validate
	@make test
	@echo "✅ Local CI pipeline complete!"

# Default target
.DEFAULT_GOAL := help
