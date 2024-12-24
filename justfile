#!/usr/bin/env -S just --justfile

run HOST *TAGS:
  ansible-playbook -b run.yaml --limit {{HOST}} {{TAGS}}

compose HOST:
  ansible-playbook run.yaml --limit {{HOST}} --tags compose

## repo stuff
# optionally use --force to force reinstall all requirements
reqs *FORCE:
	ansible-galaxy install -r requirements.yaml {{FORCE}}

# just vault (encrypt/decrypt/edit)
vault ACTION:
    EDITOR='code --wait' ansible-vault {{ACTION}} vars/vault.yaml