FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DBT_PROFILES_DIR=/usr/app/dbt

WORKDIR /usr/app/dbt

COPY requirements.txt ./
# A pasta do projeto precisa ser do usuário app: o dbt cria target/ e logs/ nela.
RUN pip install -r requirements.txt \
    && useradd --system --uid 10001 --create-home app \
    && chown app /usr/app/dbt

COPY --chown=app . .
USER app

# Imagem executada pelo Airflow (DockerOperator localmente, ECS na AWS).
ENTRYPOINT ["dbt"]
CMD ["--help"]
