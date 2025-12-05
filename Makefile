.PHONY: build deps format test

build: deps format test

deps:
	mix deps.get

format:
	mix format

test:
	mix test
