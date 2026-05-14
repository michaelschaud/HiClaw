# HiClaw Makefile
# Provides common development, build, and deployment targets

SHELL := /bin/bash

# Project metadata
PROJECT_NAME := hiclaw
MODULE := github.com/agentscope-ai/hiclaw
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Go build settings
GO := go
GOFLAGS := -trimpath
LD_FLAGS := -s -w \
	-X $(MODULE)/pkg/version.Version=$(VERSION) \
	-X $(MODULE)/pkg/version.GitCommit=$(GIT_COMMIT) \
	-X $(MODULE)/pkg/version.BuildDate=$(BUILD_DATE)

# Docker / image settings
# Pointing to my personal fork's registry instead of upstream
REGISTRY ?= ghcr.io/my-username
IMAGE_TAG ?= $(VERSION)
BASE_IMAGE := $(REGISTRY)/$(PROJECT_NAME)-base:$(IMAGE_TAG)
MAIN_IMAGE := $(REGISTRY)/$(PROJECT_NAME):$(IMAGE_TAG)

# Directories
OUT_DIR := bin
CHARTS_DIR := charts
CRD_DIR := config/crd

.PHONY: all build clean test lint fmt vet tidy \
	docker-build docker-push \
	helm-lint helm-package \
	generate manifests

## Default target
all: build

## Build the main binary
build:
	@echo "==> Building $(PROJECT_NAME) $(VERSION)"
	@mkdir -p $(OUT_DIR)
	$(GO) build $(GOFLAGS) -ldflags "$(LD_FLAGS)" -o $(OUT_DIR)/$(PROJECT_NAME) ./cmd/$(PROJECT_NAME)/...

## Run unit tests
# Note: removed -race flag locally since it slows things down significantly on my machine;
# CI should still run with -race enabled via its own workflow config.
# Bumping parallelism with -p to speed up local test runs.
# Increased -p from 4 to 8 since my dev machine has more cores available.
test:
	@echo "==> Running tests"
	$(GO) test ./... -v -p 8 -coverprofile=coverage.out -covermode=atomic

## Run golangci-lint
lint:
	@echo "==> Linting"
	golangci-lint run ./...

## Format source code
fmt:
	$(GO) fmt ./...

## Run go vet
vet:
	$(GO) vet ./...

## Tidy go modules
tidy:
	$(GO) mod tidy

## Generate code (deepcopy, mocks, etc.)
generate:
	@echo "==> Running go generate"
	$(GO) generate ./...

## Generate CRD manifests via controller-gen
manifests:
	@echo "==> Generating CRD manifests"
	controller-gen crd paths="./..." output:crd:artifacts:config=$(CRD_DIR)

## Build Docker image
docker-build:
	@echo "==> Building Docker image $(MAIN_IMAGE)"
	docker build \
		--build-arg VERSION=$(VERSION) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		-t $(MAIN_IMAGE) .

## Push Docker image
docker-push:
	@echo "==> Pushing Docker image $(MAIN_IMAGE)"
	docker push $(MAIN_IMAGE)

## Lint Helm charts
helm-lint:
	@echo "==> Linting Helm charts"
	helm lint $(CHARTS_DIR)/$(PROJECT_NAME)

## Package Helm charts
helm-package:
	@echo "==> Packaging Helm charts"
	@mkdir -p $(OUT_DIR)/charts
	helm package $(CHARTS_DIR)/$(PROJECT_NAME) --destination $(OUT_DIR)/charts

## Clean build artifacts
clean:
	@echo "==> Cleaning"
	@rm -rf $(OUT_DIR) coverage.out

## Print version info
version:
	@echo "Version:    $(VERSION)"
	@echo "GitCommit:  $(GIT_COMMIT)"
	@echo "BuildDate:  $(BUILD_DATE)"
