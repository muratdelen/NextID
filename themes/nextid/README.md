# NextId Teması

NextId Core tarafından kullanılan teknik parent temalar:

- Login: `keycloak.v2`
- Account: `keycloak.v3`
- Admin: `keycloak.v2`

Servisi başlatma:

```bash
docker compose up -d
docker compose ps
docker compose logs --tail=100 nextid-core
```

Tema dosyalarını doğrulama:

```bash
docker exec "${COMPOSE_PROJECT_NAME:-nextid}-core" \
  find /opt/keycloak/themes/nextid -maxdepth 5 -type f | sort
```

Yönetim arayüzündeki **Realm settings > Themes** bölümünde Login, Account ve
Admin console temaları için `nextid` seçin.
