bastion:
	ansible-playbook -b run.yaml --limit bastion --ask-become-pass --vault-password-file .vault-password

bcomp:
	ansible-playbook run.yaml --limit bastion --vault-password-file .vault-password --tags compose

c:
	ansible-playbook -b run.yaml --limit cartman --ask-become-pass --vault-password-file .vault-password

ccomp:
	ansible-playbook run.yaml --limit cartman --vault-password-file .vault-password --tags compose

h:
	ansible-playbook -b run.yaml --limit helios64 --ask-become-pass --vault-password-file .vault-password

hcomp:
	ansible-playbook run.yaml --limit helios64 --vault-password-file .vault-password --tags compose

m:
	ansible-playbook -b run.yaml --limit morpheus --ask-become-pass --vault-password-file .vault-password

mcomp:
	ansible-playbook run.yaml --limit morpheus --vault-password-file .vault-password --tags compose

q:
	ansible-playbook -b run.yaml --limit quassel --ask-become-pass --vault-password-file .vault-password

cloud:
	ansible-playbook -b run.yaml --limit cloud --ask-become-pass --vault-password-file .vault-password

cloudcomp:
	ansible-playbook run.yaml --limit cloud --tags compose --vault-password-file .vault-password

fancontrol:
	ansible-playbook -b run.yaml --limit fancontrol --vault-password-file .vault-password

devbox:
	ansible-playbook -b run.yaml --limit dev --vault-password-file .vault-password

backup:
	ansible-playbook -b run.yaml --limit backup --vault-password-file .vault-password

update:
	ansible-playbook update.yaml --limit servers --vault-password-file .vault-password

reqs:
	ansible-galaxy install -r requirements.yaml

forcereqs:
	ansible-galaxy install -r requirements.yaml --force

decrypt:
	ansible-vault decrypt --vault-password-file .vault-password vars/vault.yaml

encrypt:
	ansible-vault encrypt --vault-password-file .vault-password vars/vault.yaml

# cloud:
# 	cd terraform/cloud; terraform apply

# cloud-destroy:
# 	cd terraform/cloud; terraform destroy

gitinit:
	@./git-init.sh
	@echo "ansible vault pre-commit hook installed"
	@echo "don't forget to create a .vault-password too"