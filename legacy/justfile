#!/usr/bin/env -S just --justfile

# Ansible playbook against specific host
run HOST *TAGS:
  ansible-playbook -b run.yaml --limit {{HOST}} {{TAGS}}

# docker compose against remote host via Ansible
compose HOST *V:
  ansible-playbook run.yaml --limit {{HOST}} --tags compose {{V}}

##########
## secrets management (SOPS/age)

# Edit secrets file with SOPS
sops FILE='group_vars/all.sops.yaml':
    EDITOR='code --wait' sops {{FILE}}

# View decrypted secrets (read-only)
sops-show FILE='group_vars/all.sops.yaml':
    sops --decrypt {{FILE}}

##########
## repo stuff

# updates submodules
sub-update:
  #git submodule update --init --recursive
  git submodule update --remote --recursive

# git submodule - repo URL + optional local folder name
sub-add URL *NAME:
    #!/usr/bin/env sh
    if [ -z "{{NAME}}" ]; then
        # Extract repo name from URL if no name provided
        basename=$(basename "{{URL}}" .git)
        git submodule add {{URL}} "roles/${basename}"
        git submodule update --init --recursive
        git add .gitmodules "roles/${basename}"
        git commit -m "Adds ${basename} as a submodule"
    else
        git submodule add {{URL}} "roles/{{NAME}}"
        git submodule update --init --recursive
        git add .gitmodules "roles/{{NAME}}"
        git commit -m "Adds {{NAME}} as a submodule"
    fi

# optionally use --force to force reinstall all requirements
reqs *FORCE:
	ansible-galaxy install -r requirements.yaml {{FORCE}}