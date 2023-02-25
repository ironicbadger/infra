#!/usr/bin/env -S just --justfile
# ^ A shebang isn't required, but allows a justfile to be executed
#   like a script, with `./justfile test`, for example.

#alias t := test

#alias c := check

bt := '0'

export RUST_BACKTRACE := bt

log := "warn"

export JUST_LOG := log

run HOST *TAGS:
  ansible-playbook -b run.yaml --limit {{HOST}} {{TAGS}}