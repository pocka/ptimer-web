# SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0

.SUFFIXES:


.PHONY: default
default: ptimer.app/Contents/MacOS/ptimer


GO_FILES = $(shell find . -type f -name "*.go")

ptimer.app/Contents/MacOS/ptimer: $(GO_FILES) go.mod go.sum
	CGO_LDFLAGS="-Wl,-no_warn_duplicate_libraries" go build -o $@


.PHONY: clean
clean: ptimer.app/Contents/MacOS/ptimer
	rm $<
