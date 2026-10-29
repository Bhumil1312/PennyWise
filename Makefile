GO ?= go
BUF ?= buf

.PHONY: help proto proto-lint proto-generate test lint build tidy fmt

help:
	@echo "PennyWise monorepo targets:"
	@echo "  proto          - lint + generate Go code from protos"
	@echo "  proto-lint     - buf lint + breaking check"
	@echo "  proto-generate - buf generate into gen/go"
	@echo "  test           - go test ./... (all modules)"
	@echo "  lint           - go vet ./... (all modules)"
	@echo "  build          - go build ./... (all modules)"
	@echo "  tidy           - go mod tidy for every module"
	@echo "  fmt            - gofmt -w on all Go sources"

proto-lint:
	cd protos && $(BUF) lint && $(BUF) breaking --against .git#branch=main,subdir=protos

proto-generate:
	cd protos && $(BUF) generate

proto: proto-lint proto-generate

test:
	$(GO) build ./...
	$(GO) test ./...

lint:
	$(GO) vet ./...

build:
	$(GO) build ./...

tidy:
	$(GO) mod tidy -diff
	find libs services gen -name go.mod -execdir $(GO) mod tidy \;

fmt:
	gofmt -w $$(find libs services gen -name '*.go' -not -name '*.pb.go')