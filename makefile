all:
	echo blah

mb:
	ansible-playbook -b run.yaml --limit mb --ask-become-pass --vault-password-file .vault-password

c:
	ansible-playbook -b run.yaml --limit cartman --ask-become-pass --vault-password-file .vault-password

ccomp:
	ansible-playbook -b run.yaml --limit cartman --ask-become-pass --vault-password-file .vault-password --tags compose

adguard:
	ansible-playbook -b run.yaml --limit adguard --ask-become-pass --vault-password-file .vault-password

awesomo:
	ansible-playbook -b run.yaml --limit awesomo --ask-become-pass --vault-password-file .vault-password

q:
	ansible-playbook -b run.yaml --limit quassel --ask-become-pass --vault-password-file .vault-password

hass:
	ansible-playbook -b run.yaml --user bootstrap --limit hassio --ask-become-pass --become-method su --vault-password-file .vault-password

db:
	ansible-playbook -b run.yaml --user bootstrap --limit db --ask-become-pass --become-method su --vault-password-file .vault-password

reqs:
	ansible-galaxy install -r requirements.yaml

forcereqs:
	ansible-galaxy install -r requirements.yaml --force

decrypt:
	ansible-vault decrypt --vault-password-file .vault-password vars/vault.yaml

encrypt:
	ansible-vault encrypt --vault-password-file .vault-password vars/vault.yaml