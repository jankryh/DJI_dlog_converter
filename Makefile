# Makefile for DJI Video Processor
# Provides convenient commands for testing, development, and maintenance

.PHONY: help test test-unit test-integration test-verbose test-watch clean install setup lint docs

# Default target
help: ## Show this help message
	@echo "DJI Video Processor - Development Commands"
	@echo "==========================================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make test              # Run all tests"
	@echo "  make test-unit         # Run unit tests only"
	@echo "  make test-verbose      # Run tests with verbose output"
	@echo "  make setup             # Setup development environment"

# Test targets
test: ## Run all tests
	@./tests/run-tests.sh all

test-unit: ## Run unit tests only
	@./tests/run-tests.sh unit

test-integration: ## Run integration tests only
	@./tests/run-tests.sh integration

test-verbose: ## Run all tests with verbose output
	@./tests/run-tests.sh --verbose all

test-tap: ## Run tests with TAP output format
	@./tests/run-tests.sh --tap all

test-junit: ## Run tests and generate JUnit XML report
	@./tests/run-tests.sh --junit all

test-watch: ## Run tests in watch mode (requires entr)
	@echo "Watching for file changes... (Press Ctrl+C to stop)"
	@find lib bin tests -name "*.sh" -o -name "*.bats" | entr -c make test

# Test with specific filters
test-utils: ## Run utility tests only
	@./tests/run-tests.sh --filter "utils"

test-config: ## Run configuration tests only
	@./tests/run-tests.sh --filter "config"

test-logging: ## Run logging tests only
	@./tests/run-tests.sh --filter "logging"

test-cli: ## Run CLI tests only
	@./tests/run-tests.sh --filter "cli"

# Development setup
setup: ## Setup development environment
	@echo "Setting up DJI Video Processor development environment..."
	@echo ""
	@echo "1. Checking BATS installation..."
	@if command -v bats >/dev/null 2>&1; then \
		echo "✅ BATS is installed: $$(bats --version)"; \
	else \
		echo "❌ BATS not found. Installing via Homebrew..."; \
		brew install bats-core; \
	fi
	@echo ""
	@echo "2. Initializing git submodules..."
	@git submodule update --init --recursive
	@echo ""
	@echo "3. Creating test directories..."
	@mkdir -p tests/reports tests/tmp
	@echo ""
	@echo "4. Setting permissions..."
	@chmod +x bin/dji-processor tests/run-tests.sh
	@echo ""
	@echo "✅ Development environment ready!"
	@echo ""
	@echo "Next steps:"
	@echo "  make test              # Run all tests"
	@echo "  make test-unit         # Run unit tests"
	@echo "  ./bin/dji-processor help    # Try the CLI"

install: ## Install BATS and dependencies
	@echo "Installing BATS testing framework..."
	@if command -v brew >/dev/null 2>&1; then \
		brew install bats-core; \
	elif command -v npm >/dev/null 2>&1; then \
		npm install -g bats; \
	else \
		echo "Please install Homebrew or Node.js to install BATS"; \
		exit 1; \
	fi

# Code quality
lint: ## Run shellcheck on shell scripts
	@echo "Running shellcheck on shell scripts..."
	@find . -name "*.sh" -not -path "./tests/test_helper/*" -exec shellcheck {} \; || true
	@echo "Running shellcheck on BATS tests..."
	@find tests -name "*.bats" -exec shellcheck -x {} \; || true

format: ## Format shell scripts (requires shfmt)
	@echo "Formatting shell scripts..."
	@if command -v shfmt >/dev/null 2>&1; then \
		find . -name "*.sh" -not -path "./tests/test_helper/*" -exec shfmt -w -i 4 {} \;; \
		echo "✅ Shell scripts formatted"; \
	else \
		echo "❌ shfmt not found. Install with: brew install shfmt"; \
	fi

# Validation and verification
validate: ## Validate project setup
	@echo "Validating DJI Video Processor setup..."
	@./bin/dji-processor validate

verify: ## Verify installation and run smoke tests
	@echo "Verifying DJI Video Processor installation..."
	@./bin/dji-processor --version
	@./bin/dji-processor validate
	@make test-unit

# Clean up
clean: ## Clean temporary files and test artifacts
	@echo "Cleaning temporary files..."
	@rm -rf tests/tmp/* tests/reports/*
	@rm -f *.log ./*.log
	@echo "✅ Cleanup complete"

clean-all: clean ## Clean everything including dependencies
	@echo "Cleaning git submodules..."
	@git submodule deinit -f tests/test_helper/bats-support || true
	@git submodule deinit -f tests/test_helper/bats-assert || true  
	@git submodule deinit -f tests/test_helper/bats-file || true
	@rm -rf .git/modules/tests/test_helper/*

# Documentation
docs: ## Generate documentation
	@echo "Generating documentation..."
	@echo "📚 Available documentation:"
	@echo "  - README.md           - Main project documentation"
	@echo "  - docs/MODULES.md     - Module architecture"
	@echo "  - docs/CONFIG.md      - Configuration guide"
	@echo "  - tests/              - Test examples and patterns"

# Git helpers
git-setup: ## Setup git hooks and configuration
	@echo "Setting up git hooks..."
	@mkdir -p .git/hooks
	@echo '#!/bin/bash' > .git/hooks/pre-commit
	@echo 'make lint' >> .git/hooks/pre-commit
	@echo 'make test-unit' >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "✅ Git hooks installed"

# Docker support (future)
docker-test: ## Run tests in Docker container
	@echo "Docker testing not implemented yet"
	@echo "Future: docker run --rm -v \$$(pwd):/workspace bats/bats-core:latest test"

# Release helpers
bump-version: ## Bump version in relevant files
	@echo "Version bumping not implemented yet"
	@echo "Would update: bin/dji-processor, docs/README.md"

tag-release: ## Create git tag for release
	@echo "Release tagging not implemented yet"
	@echo "Would create git tag based on version"

# Performance testing
benchmark: ## Run performance benchmarks
	@echo "Performance benchmarks not implemented yet"
	@echo "Future: time make test, memory usage analysis"

# CI/CD helpers
ci: ## Run CI pipeline (tests + linting)
	@echo "Running CI pipeline..."
	@make lint
	@make test
	@echo "✅ CI pipeline completed"

# Quick development workflows
dev: ## Quick development test cycle
	@make lint test-unit

full-test: ## Full comprehensive test suite
	@make lint test verify

# Debug helpers
debug-test: ## Run tests with debug output
	@DEBUG=1 ./tests/run-tests.sh --verbose all

debug-bats: ## Show BATS debugging information
	@echo "BATS Version: $$(bats --version)"
	@echo "BATS Location: $$(which bats)"
	@echo "Helper modules:"
	@ls -la tests/test_helper/