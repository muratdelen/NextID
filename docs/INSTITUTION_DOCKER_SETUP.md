# NextId Kurumsal Docker Kurulumu

Bu paket, NextId Core ve PostgreSQL servislerini Docker Compose ile çalıştırır.

## Gereksinimler

- Docker Engine
- Docker Compose
- GitHub Container Registry erişimi

NextId Core image'ı:

```text
ghcr.io/muratdelen/nextid-core
```

## Yapılandırma

Örnek ortam dosyasını kopyalayın:

```bash
cp .env.institution.example .env
```

`.env` içindeki veritabanı ve NextId yönetici hesabı parolalarını değiştirin.
Gerçek parolaları kaynak kod deposuna eklemeyin.

## Image Erişimi

Image herkese açık değilse GitHub Container Registry'ye giriş yapın:

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u GITHUB_KULLANICI_ADI --password-stdin
```

Token'ın package okuma yetkisi bulunmalıdır.

## Başlatma

```bash
docker compose --env-file .env pull
docker compose --env-file .env up -d
```

Servis durumunu görüntülemek için:

```bash
docker compose --env-file .env ps
docker compose --env-file .env logs -f nextid-core
```

Varsayılan adres `http://localhost:8080` değeridir.

## Güncelleme

`.env` içindeki `NEXTID_CORE_IMAGE_TAG` değerini yayınlanan sürüme ayarlayın:

```env
NEXTID_CORE_IMAGE_TAG=26.6.3-nextid
```

Ardından image'ı çekip servisi yeniden oluşturun:

```bash
docker compose --env-file .env pull nextid-core
docker compose --env-file .env up -d nextid-core
docker compose --env-file .env logs -f nextid-core
```

Son komut NextId Core başlangıç loglarını canlı olarak gösterir. Log takibinden
çıkmak container'ı durdurmaz; terminalde `Ctrl+C` kullanabilirsiniz.

## Runtime Değişkenleri

NextId-Core, Keycloak tabanlı bir fork olduğu için bazı düşük seviyeli runtime
değişkenlerinde `KC_` prefix'i kullanılmaya devam eder. Kurum tarafından
yönetilen `.env` arayüzünde mümkün olduğunca `NEXTID_` prefix'i kullanılır ve
Compose dosyası bu değerleri NextId Core runtime değişkenlerine aktarır.

Health ve metrics özellikleri NextId Core image oluşturulurken etkinleştirilir.
Yönetim endpoint'leri varsayılan olarak container içindeki `9000` portundadır.

## Durdurma

Tüm NextId container'larını verileri koruyarak durdurmak için:

```bash
docker compose --env-file .env stop
```

Yalnızca NextId Core container'ını durdurmak için:

```bash
docker compose --env-file .env stop nextid-core
```

Yalnızca veritabanı container'ını durdurmak için:

```bash
docker compose --env-file .env stop nextid-db
```

Durdurulan container'ları tekrar başlatmak için:

```bash
docker compose --env-file .env start
```

Container'ları ve oluşturulan ağı kaldırmak, ancak veritabanı volume'unu
korumak için:

```bash
docker compose --env-file .env down
```

Container'larla birlikte veritabanı volume'unu da silmek için:

```bash
docker compose --env-file .env down -v
```

`down -v` kalıcı veritabanı verilerini siler. Bu komutu yalnızca bilinçli bir
tam sıfırlama işleminde kullanın.
