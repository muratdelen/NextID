# NextId

NextId is a Keycloak-based identity and access management distribution customized for NextLife applications.

## Türkçe

NextId, NextLife ekosistemi için özelleştirilmiş Keycloak tabanlı merkezi kimlik ve erişim yönetimi dağıtımıdır.

Tek oturum açma, merkezi kullanıcı yönetimi, rol tabanlı yetkilendirme, özel giriş teması ve ileride özel provider eklentileri için temel yapı sağlar.

## Features

- Keycloak-based authentication
- Centralized identity management
- Single Sign-On
- Role-based access control
- Custom NextId login theme
- Docker-based deployment
- PostgreSQL support

## Local Development

```bash
docker compose up -d --build
cat > .github/workflows/docker-publish.yml <<'EOF'
name: Build NextId Docker Image

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  docker-build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t nextid:local .
