#!/usr/bin/env bash
set -e

export BUSTED_ARGS="-o gtest -v --exclude-tags=flaky"
export TEST_CMD="bin/busted $BUSTED_ARGS"

createuser --createdb kong
createdb -U kong kong_tests

if [ "$TEST_SUITE" == "lint" ]; then
    make lint
fi