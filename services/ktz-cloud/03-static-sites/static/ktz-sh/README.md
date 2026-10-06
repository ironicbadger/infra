# Chrome bookmark separator

`separator/` is served at <https://sh.ktz.me/separator> by the existing `ktz-sh` nginx container. The slashless URL returns the page directly; the trailing-slash URL also remains available.
The favicon is a transparent SVG with a narrow gray vertical line, with a multi-resolution ICO fallback (16, 32, 48, 64, 128, and 256px). Versioned icon URLs let browsers fetch updated assets. The SVG stays sharp at any display scale.
The page title contains a zero-width space so new bookmarks have no visible label.
Users can also clear the bookmark name manually.

Deploy the directory from this folder:

```sh
scp -r separator ironicbadger@ktz-cloud:/opt/appdata/ktz-sh/data/
```

No container restart is required. The root directory listing and existing shell scripts are preserved.
These binary static assets are deployed separately from the compose generator's text templates.

The server's `/opt/appdata/ktz-sh/config/default.conf` includes this scoped location because the global nginx configuration intentionally defaults to plain text:

```nginx
location = /separator {
    alias /usr/share/nginx/html/separator/index.html;
    default_type text/html;
}

location /separator/ {
    root /usr/share/nginx/html;
    index index.html;
    include /etc/nginx/mime.types;
}
```

After adding this location for the first deployment, validate with `docker exec ktz-sh nginx -t` and reload with `docker exec ktz-sh nginx -s reload`. Later asset updates need no reload.

To remove the feature, remove only `/opt/appdata/ktz-sh/data/separator/` on the server.
