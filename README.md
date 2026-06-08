# NextId

NextId, NextLife uygulamaları için merkezi kimlik ve erişim yönetimi
dağıtımıdır. Paket; NextId Core, PostgreSQL, özel tema ve Docker Compose
yapılandırmalarını içerir.

## Bileşenler

- `nextid-core`: Kimlik, oturum ve yetkilendirme servisi
- `nextid-db`: PostgreSQL veritabanı
- `themes/nextid`: NextId kullanıcı arayüzü teması

## Yerel Çalıştırma

```bash
cp .env.example .env
docker compose up -d
```

Servis varsayılan olarak `http://localhost:8080` adresinde çalışır.

## Kurumsal Kurulum

Kurumsal ortamlar için
[`docs/INSTITUTION_DOCKER_SETUP.md`](docs/INSTITUTION_DOCKER_SETUP.md)
belgesini kullanın.

Dağıtım doğrudan aşağıdaki NextId Core image'ını kullanır:

```text
ghcr.io/muratdelen/nextid-core:${NEXTID_CORE_IMAGE_TAG:-latest}
```

NextId-Core, Keycloak tabanlı bir fork olduğu için bazı düşük seviyeli runtime
değişkenlerinde `KC_` prefix'i korunur.
