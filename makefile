bastion:
	ansible-playbook -b run.yaml --limit bastion --ask-become-pass --vault-password-file .vault-password

c:
	ansible-playbook -b run.yaml --limit cartman --ask-become-pass --vault-password-file .vault-password

ccomp:
	ansible-playbook -b run.yaml --limit cartman --ask-become-pass --vault-password-file .vault-password --tags compose

q:
	ansible-playbook -b run.yaml --limit quassel --ask-become-pass --vault-password-file .vault-password

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

cloud:
	cd terraform/cloud; terraform apply

cloud-destroy:
	cd terraform/cloud; terraform destroy

gitinit:
	@./git-init.sh
	@echo "ansible vault pre-commit hook installed"
	@echo "don't forget to create a .vault-password too"