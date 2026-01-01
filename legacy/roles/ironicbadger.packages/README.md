# ansible-role-packages

A generic role to install packages on Debian (deb) based systems, specifically targeting Proxmox environments.

You can enable full system package upgrades to latest by enabling 

```
full_update_apt_packages: False
```

To provide a list of packages to install use:

```
package_list:
  - "package1"
  - "package2"
```

## Declarative Mode

Declarative mode keeps track of packages installed by this role and can remove packages that are no longer in your list:

```
packages_declarative_mode: True   # Track packages installed by this role
packages_perform_cleanup: False   # When true, removes packages no longer in list
packages_state_file: "/root/.installed-packages.txt"  # State file location
```

## Example Playbook

```yaml
- hosts: proxmox
  roles:
    - role: ansible-role-packages
      vars:
        package_list:
          - nginx
          - postgresql
        packages_declarative_mode: True
        packages_perform_cleanup: True
```