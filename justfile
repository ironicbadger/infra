#!/usr/bin/env -S just --justfile

core *TAGS:
  ansible-playbook -b playbooks/core.yaml {{TAGS}}

test *TAGS:
  ansible-playbook -b playbooks/test-network.yaml {{TAGS}}
