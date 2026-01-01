# ansible-role-docker-compose-generator

This role is designed to ingest directories of `compose.yaml` files and output a sanitised version to a remote host using Ansible.

> ⚠️ **Warning:** v1 of this role used a completely different data structure. See [v1 vs v2 of this role](#v1-of-this-role-vs-v2)

I wrote the following [blog post](https://blog.ktz.me/docker-compose-generator-v2-release/) on the v2 release for more info.

## Usage

Import this role into your Ansible setup either as a [git submodule](https://blog.ktz.me/git-submodules-for-fun-and-profit-with-ansible/) or via Ansible Galaxy.

In the root of your git repo create a `services` directory and populate it as follows:

```
.
└── services
    ├── ansible-hostname1
    │   ├── librespeed
    │   │   └── compose.yaml
    │   ├── jellyfin
    │   │   └── compose.yaml
    └── ansible-hostname2
        └── uptime-kuma
            └── compose.yaml
```

Each `compose.yaml` file is a standard format file, for example librespeed looks like this:

```
services:
  librespeed:
    image: lscr.io/linuxserver/librespeed
    container_name: librespeed
    ports:
      - 8008:80
    environment:
      - "TZ={{ host_timezone }}"
      - "PASSWORD={{ testpass }}"
    restart: unless-stopped
```

Notice that variable interpolation is supported. The source of these variables can be either an encryped secrets file via Ansible vault (read more about that [here](https://blog.ktz.me/secret-management-with-docker-compose-and-ansible/) - or see [ironicbadger/infra](https://github.com/ironicbadger/infra) for an implemented example), an `env` file you manually place alongside the `compose.yaml` on the remote host (see [docker compose variable interpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/#interpolation-syntax)), or any other standard Ansible variable source.

Multiple services per compose file are also supported. Useful to run a database alongside an app, for example.

By default, if a `compose.yaml` file is found it will be included in the automation, and placed into the output `compose.yaml` on the remote host. This file is placed under the `docker_compose_generator_output_path` which is the home folder of the ssh user. The role also supports disabling specific compose files by matching the name of the file against a `host_var` or `group_var` file with the following variable:

```
disabled_compose_files:
  - jellyfin
```

## Custom hostnames

By default, the role is looking for a directory structure under `services/` which matches your Ansible hostname. If your hostname doesn't match the name of this directory for some reason (maybe it's an IP address, rather than a hostname), you can override the name with the variable:

```
docker_compose_hostname: my-custom-hostname
```

## Override services directory location

By default, the role is looking for services by determining where the `playbook_dir` is and appending `services/`. 
If your playbooks are for example inside a dedicated playbooks directory you can overwrite the services location by setting `services_directory` either in a task var, group_vars or host_vars.

## Config File Deployment

The role supports deploying configuration files alongside your services using `config-*` directories. This is useful for apps that require config files (like Glance, Prometheus, etc.) that should be managed alongside the compose definition.

### Directory Structure

```
services/
└── ansible-hostname1
    └── monitoring
        ├── compose.yaml
        └── config-glance/
            ├── .dest
            └── glance.yml
```

### How It Works

1. Create a `config-<appname>` directory alongside your compose files
2. Add a `.dest` file containing the destination path on the remote host (supports Ansible variable interpolation)
3. Add your config files - they will be copied as-is (no templating)

Example `.dest` file:
```
{{ appdata_path }}/apps/glance
```

The role will:
- Find all `config-*` directories recursively
- Read the `.dest` file to determine where to copy files
- Create the destination directory with proper ownership
- Copy all files (except `.dest`) to the destination

### Optional: ZFS Dataset Creation

If your target host uses ZFS, you can enable automatic dataset creation for config directories:

```yaml
# group_vars or host_vars
docker_compose_generator_zfs_enabled: true
```

When enabled, the role will:
1. Detect the parent ZFS dataset of the destination path
2. Create a child dataset for the config directory
3. The directory is then auto-mounted by ZFS

This provides snapshot and replication benefits for your app configs.

## v1 of this role vs v2

v1 of this role used a large custom data structure and an ever more complex jinja2 based templating approach. The custom nature of this approach added friction when adding new services and made it difficult to copy/paste from upstream repositories to try things out quickly.

v2 supports using standalone, native compose files. This makes it much more straightforward to try out new software without needing to 'convert' it to work with the v1 custom data structures.

If you find any edge cases I've missed for v2, please open an issue or PR. I'd be happy to review.

Special thanks goes to [u/fuzzymistborn](https://github.com/fuzzymistborn) for the spark for the idea to make this change. As ever, you can find a full working example of my usage of this role over at [ironicbadger/infra](https://github.com/ironicbadger/infra).
