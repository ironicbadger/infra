dhcpdns:
	ansible-playbook -b run.yaml --limit pihole --tags dhcpdns

m1:
	ansible-playbook -b run.yaml --limit m1 --ask-become-pass 

pi8:
	ansible-playbook -b run.yaml --limit pi8

g:
	ansible-playbook -b run.yaml --limit galgatebst --ask-become-pass 

gcomp:
	ansible-playbook run.yaml --limit galgatebst --tags compose

elrond:
	ansible-playbook -b run.yaml --limit elrond --ask-become-pass

elcomp:
	ansible-playbook -b run.yaml --limit elrond --tags compose --ask-become-pass

m:
	ansible-playbook -b run.yaml --limit morpheus

mrepl:
	ansible-playbook -b run.yaml --limit morpheus --tags replication

mcomp:
	ansible-playbook run.yaml --limit morpheus --tags compose

p:
	ansible-playbook -b run.yaml --limit pennywise

pcomp:
	ansible-playbook run.yaml --limit pennywise --tags compose

cloud:
	ansible-playbook -b run.yaml --limit cloud --ask-become-pass 

cloudcomp:
	ansible-playbook run.yaml --limit cloud --tags compose 

fancontrol:
	ansible-playbook -b run.yaml --limit fancontrol 

proxmox:
	ansible-playbook -b playbooks/proxmox-nag.yaml --limit proxmox --ask-become-pass 

dhcp:
	ansible-playbook -b run.yaml --limit dhcp 

anton:
	ansible-playbook -b run.yaml --limit anton --ask-become-pass

opnsensewd:
	ansible-playbook -b run.yaml --limit opnsensewd --ask-become-pass

caddy:
	ansible-playbook -b run.yaml --limit caddy

updatez:
	ansible-playbook playbooks/zoidberg-updates.yaml --limit zoidbergskids -b --ask-become-pass

reqs:
	ansible-galaxy install -r requirements.yaml

forcereqs:
	ansible-galaxy install -r requirements.yaml --force

decrypt:
	ansible-vault decrypt vars/vault.yaml

encrypt:
	ansible-vault encrypt vars/vault.yaml

# cloud:
# 	cd terraform/cloud; terraform apply

# cloud-destroy:
# 	cd terraform/cloud; terraform destroy

gitinit:
	@./git-init.sh
	@echo "ansible vault pre-commit hook installed"
	@echo "don't forget to create a .vault-password too"