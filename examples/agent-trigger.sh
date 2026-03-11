#!/usr/bin/env bash
# Trigger a flare via HTTP when an agent task completes.
# Use this from any process that can reach the workstation.

curl -s -X POST http://localhost:5050/trigger \
  -H "Content-Type: application/json" \
  -d '{"preset":"alert"}'
