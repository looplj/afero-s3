.DEFAULT_GOAL := help

ifneq (,$(wildcard .env))
include .env
export $(shell sed -n 's/^\([^#= ][^=]*\)=.*/\1/p' .env)
endif

CLI_ARGS ?=
MINIO_IMAGE ?= minio/minio:latest

.PHONY: help bingo pre-test post-test lint test run-test run-example

help:
	@echo "Available targets:"
	@echo "  bingo        Install build dependencies"
	@echo "  pre-test     Start MinIO test server"
	@echo "  post-test    Stop MinIO test server"
	@echo "  lint         Run golangci-lint"
	@echo "  test         Run tests with pre/post hooks"
	@echo "  run-test     Run go test"
	@echo "  run-example  Run example CLI"

bingo:
	@$(MAKE) -s -f .bingo/Variables.mk

pre-test:
	@echo "Starting test minio server"
	@if docker ps --format '{{.Names}}' | grep -q '^miniotest$$'; then \
		echo "miniotest container already running"; \
	else \
		docker run --rm -d --name miniotest \
			-p 9000:9000 \
			$(MINIO_IMAGE) server /data; \
	fi

post-test:
	@echo "Stopping test minio server"
	@docker kill miniotest >/dev/null 2>&1 || true

lint: bingo
	@$(GOBIN)/golangci-lint-v1.45.2 run ./...

run-test:
	@go test -cover -covermode=atomic -v ./... $(CLI_ARGS)

run-test-without-coverage:
	@go test -v ./... $(CLI_ARGS)

run-example:
	@go run ./example/main.go $(CLI_ARGS)

test: pre-test
	@set -euo pipefail; \
	cleanup() { $(MAKE) --no-print-directory post-test; }; \
	trap cleanup EXIT INT TERM; \
	$(MAKE) --no-print-directory run-test CLI_ARGS="$(CLI_ARGS)"; \
	trap - EXIT INT TERM; \
	cleanup
