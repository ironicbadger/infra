bastion:
	ansible-playbook -b run.yaml --limit bastion --ask-become-pass 

bcomp:
	ansible-playbook run.yaml --limit bastion  --tags compose

c:
	ansible-playbook -b run.yaml --limit cartman --ask-become-pass 

ccomp:
	ansible-playbook run.yaml --limit cartman  --tags compose

h:
	ansible-playbook -b run.yaml --limit helios64 --ask-become-pass 

hcomp:
	ansible-playbook run.yaml --limit helios64  --tags compose

m:
	ansible-playbook -b run.yaml --limit morpheus --ask-become-pass 

mcomp:
	ansible-playbook run.yaml --limit morpheus --tags compose

q:
	ansible-playbook -b run.yaml --limit quassel --ask-become-pass 

cloud:
	ansible-playbook -b run.yaml --limit cloud --ask-become-pass 

cloudcomp:
	ansible-playbook run.yaml --limit cloud --tags compose 

fancontrol:
	ansible-playbook -b run.yaml --limit fancontrol 

devbox:
	ansible-playbook -b run.yaml --limit dev 

dhcp:
	ansible-playbook -b run.yaml --limit dhcp 

backup:
	ansible-playbook -b run.yaml --limit backup 

update:
	ansible-playbook update.yaml --limit servers 

reqs:
	ansible-galaxy install -r requirements.yaml

forcereqs:
	ansible-galaxy install -r requirements.yaml --force

decrypt:
	ansible-vault decrypt  vars/vault.yaml

encrypt:
	ansible-vault encrypt  vars/vault.yaml

# cloud:
# 	cd terraform/cloud; terraform apply

# cloud-destroy:
# 	cd terraform/cloud; terraform destroy

gitinit:
	@./git-init.sh
	@echo "ansible vault pre-commit hook installed"
	@echo "don't forget to create a .vault-password too"