# SPDX-FileCopyrightText: 2024 Shota FUJI <pockawoooh@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0

.SUFFIXES:


.PHONY: default
default: ptimer.app/Contents/MacOS/ptimer


ptimer.app/Contents/MacOS/ptimer: *.go go.mod go.sum
	CGO_LDFLAGS="-Wl,-no_warn_duplicate_libraries" go build -o $@


.PHONY: clean
clean: ptimer.app/Contents/MacOS/ptimer
	rm $<
