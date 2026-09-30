FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DBT_PROFILES_DIR=/usr/app/dbt

WORKDIR /usr/app/dbt

# Versões exatas de todas as dependências (scripts/lock.sh a partir de requirements.in).
COPY requirements.lock ./
# A pasta do projeto precisa ser do usuário app: o dbt cria target/ e logs/ nela.
RUN pip install -r requirements.lock \
    && pip check \
    && useradd --system --uid 10001 --create-home app \
    && chown app /usr/app/dbt

# Fora da pasta do projeto: o docker-compose.yml monta o projeto por cima dela.
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/bigdata-dbt

COPY --chown=app . .
USER app

# Commit do código na imagem: aparece no log de toda execução e no label OCI.
# scripts/platform.sh (repositório Terraform) passa o SHA no build; sem ele, fica "dev".
ARG GIT_SHA=dev
LABEL org.opencontainers.image.source="https://github.com/adimov-jb/bigdata-dbt-modeling" \
      org.opencontainers.image.revision="${GIT_SHA}"
ENV BIGDATA_VERSION="${GIT_SHA}"

# Imagem executada pelo Airflow (DockerOperator localmente, ECS na AWS).
ENTRYPOINT ["bigdata-dbt"]
CMD ["--help"]
