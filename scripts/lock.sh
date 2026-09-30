#!/usr/bin/env bash
# Regenera requirements.lock (todas as dependências, com versão exata) a partir de
# requirements.in, que fixa só dbt-core e os adapters. Roda no mesmo Python da imagem.
# Uso: scripts/lock.sh   (depois: docker compose run --rm --build tests)
set -euo pipefail
cd "$(dirname "$0")/.."

MSYS_NO_PATHCONV=1 docker run --rm -v "$PWD:/app" -w /app python:3.12-slim sh -c '
  pip install --quiet --disable-pip-version-check pip-tools==7.5.1 &&
  pip-compile --quiet --upgrade --strip-extras --no-emit-index-url \
    --output-file requirements.lock requirements.in
'
echo "Lock atualizado. Revise o diff e rode os testes."
