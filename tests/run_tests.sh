#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only

set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

for test in test_builder.sh test_updater.sh; do
	printf '==> %s\n' "$test"
	"$ROOT/$test"
done
