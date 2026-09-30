# dbt — modelagem silver e gold

Transforma a bronze gravada pelo `bigdata-ingestion-python` em tabelas **Iceberg** nas camadas silver e gold.

```
bronze (Parquet)                  silver (Iceberg)                        gold (Iceberg)
open_meteo_weather_hourly ──> stg_open_meteo__weather_hourly (view) ──> int_weather_hourly ──┬──> fct_weather_daily
                                        seeds: cities, weather_codes ─────────────────────────┴──> dim_city
```

| Modelo | Camada | Materialização | O que faz |
|---|---|---|---|
| `stg_open_meteo__weather_hourly` | silver | view | Renomeia colunas para incluir a unidade (`temperature_c`, `precipitation_mm`...) |
| `int_weather_hourly` | silver | incremental (merge), particionada por dia | Deduplica por cidade e hora (fica a ingestão mais recente) e traduz o código WMO |
| `dim_city` | gold | table | Cidade, UF, região e coordenadas |
| `fct_weather_daily` | gold | incremental (merge) | Temperaturas mínima, máxima e média, chuva total, umidade, vento e condição mais severa do dia |

- **Incremental:** cada execução reprocessa os últimos `lookback_days` dias (padrão 3), o que cobre dados que chegam atrasados. O `merge` pela chave evita duplicatas.
- **Reprocessar tudo:** `dbt build --full-refresh`.
- **Testes:** `unique`, `not_null`, `relationships` e `accepted_values`, mais dois testes SQL: faixa física dos valores e uma linha por cidade e hora. Há também freshness da fonte: aviso depois de 2 dias sem dados, erro depois de 7.

## Dois targets, o mesmo SQL

| | `local` (padrão) | `aws` |
|---|---|---|
| Adapter | dbt-trino | dbt-athena |
| Catálogo | Hive Metastore (`hive` para a bronze, `iceberg` para silver e gold) | Glue (`awsdatacatalog`) |
| Schemas | `bronze`, `silver`, `gold` | `bigdata_dev_bronze`, `bigdata_dev_silver`, `bigdata_dev_gold` (via `DBT_SCHEMA_PREFIX`) |
| Localização dos dados | Cada schema aponta para o bucket da sua camada (`macros/trino__create_schema.sql`) | `s3_data_dir` do profile (silver) e da pasta `gold/` |

O Athena usa o motor do Trino, então os modelos usam apenas funções que existem nos dois, como `date_add` e `count_if`. O target `aws` compila (`dbt parse`), mas ainda não foi executado: falta a conta AWS.

## Comandos

A plataforma local (`bigdata-terraform`) precisa estar no ar, e a bronze precisa ter dados (`bigdata-ingestion-python`).

```bash
docker compose build                                # imagem bigdata-dbt:local
docker compose run --rm dbt debug                   # testa a conexão com o Trino
docker compose run --rm dbt build                   # seeds + modelos + testes
docker compose run --rm dbt build --full-refresh    # recria as tabelas incrementais
docker compose run --rm dbt source freshness

# Documentação e linhagem em http://localhost:8082 (Ctrl+C para parar)
docker compose run --rm --service-ports --entrypoint sh dbt -c "dbt docs generate && dbt docs serve --host 0.0.0.0 --port 8082 --no-browser"
```

O `docker-compose.yml` monta a pasta do projeto no container. Por isso, depois de editar um modelo, basta rodar de novo, sem rebuild. A imagem só precisa ser reconstruída para o Airflow usar a versão nova.

### Consultar os resultados

```sql
-- no Trino (docker compose exec trino trino, na pasta Terraform) ou no DBeaver
SELECT f.observed_date, d.region, city, f.temperature_max_c, f.precipitation_total_mm, f.most_severe_weather_description
FROM iceberg.gold.fct_weather_daily f
JOIN iceberg.gold.dim_city d USING (city)
ORDER BY 1 DESC, 2, 3;
```

## Variáveis de ambiente

| Variável | Local (`.env.local`) | AWS |
|---|---|---|
| `DBT_TARGET` | `local` | `aws` |
| `TRINO_HOST` / `TRINO_PORT` | `trino` / `8080` | não usado |
| `SILVER_BUCKET` / `GOLD_BUCKET` | `bigdata-local-silver` / `bigdata-local-gold` | saídas do Terraform |
| `DBT_SCHEMA_PREFIX` | vazio | `bigdata_dev_` |
| `ATHENA_RESULTS_BUCKET`, `ATHENA_WORKGROUP`, `AWS_REGION` | não usados | saídas do Terraform |
