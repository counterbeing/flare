#!/usr/bin/env bash
# Trigger a flare based on CI result.
# Usage: ./ci-trigger.sh pass|fail

STATUS="${1:?Usage: ci-trigger.sh pass|fail}"

if [[ "$STATUS" == "pass" ]]; then
  flare success
else
  flare error
fi
