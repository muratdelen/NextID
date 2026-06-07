# NextId themes

Keycloak 26.6.3 parent themes:

- Login: `keycloak.v2`
- Account: `keycloak.v3`
- Admin: `keycloak.v2`

Build and start:

```bash
docker compose down
docker compose build --no-cache nextid
docker compose up -d
docker compose ps
docker compose logs --tail=100 nextid
```

Verify the installed theme files:

```bash
docker exec nextid find /opt/keycloak/themes/nextid -maxdepth 5 -type f | sort
```

In **Realm settings > Themes**, select `nextid` for Login theme,
Account theme, and Admin console theme.
