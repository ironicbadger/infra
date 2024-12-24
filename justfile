#!/usr/bin/env -S just --justfile


# Ansible playbook against specific host
run HOST *TAGS:
  ansible-playbook -b run.yaml --limit {{HOST}} {{TAGS}}

# docker compose against remote host via Ansible
compose HOST:
  ansible-playbook run.yaml --limit {{HOST}} --tags compose

##########
## repo stuff

# git submodule - repo URL + optional local folder name
add-submodule URL *NAME:
    #!/usr/bin/env sh
    if [ -z "{{NAME}}" ]; then
        # Extract repo name from URL if no name provided
        basename=$(basename "{{URL}}" .git)
        git submodule add {{URL}} "roles/${basename}"
    else
        git submodule add {{URL}} "roles/{{NAME}}"
    fi

gitinit:
  sh scripts/git-init.sh

# optionally use --force to force reinstall all requirements
reqs *FORCE:
	ansible-galaxy install -r requirements.yaml {{FORCE}}

# just vault (encrypt/decrypt/edit)
vault ACTION:
    EDITOR='code --wait' ansible-vault {{ACTION}} vars/secrets.yaml