# bigdata-dbt-modeling — modelagem silver e gold

Transforma a bronze gravada pelo `bigdata-ingestion-python` em tabelas **Iceberg** nas camadas silver e gold, com testes de qualidade em cada etapa. O mesmo SQL roda no Trino (local) e no Athena (AWS).

São dois domínios, cada um com seu seletor em `selectors.yml` e seu próprio build no Airflow:

- **open_meteo**: tempo horário das capitais, consolidado num resumo diário por cidade (detalhes logo abaixo).
- **countries**: relaciona a Rest Countries com o Banco Mundial pelo código ISO e valida nulos e faltantes na gold (detalhes em [Domínio countries](#domínio-countries)).

## A plataforma

Este repositório é uma das quatro partes da plataforma de dados **bigdata**. Ela coleta dados públicos de APIs, organiza tudo num data lake em camadas (bronze → silver → gold) e entrega tabelas analíticas validadas. Tudo roda localmente em Docker, com LocalStack, Hive Metastore e Trino no lugar de S3, Glue e Athena, e está preparado para a AWS.

| Repositório | Papel |
|---|---|
| [bigdata-terraform](https://github.com/adimov-jb/bigdata-terraform) | Infraestrutura (AWS e local), contrato da plataforma, operação (`scripts/platform.sh`) e runbook |
| [bigdata-ingestion-python](https://github.com/adimov-jb/bigdata-ingestion-python) | Ingestão das APIs para a camada bronze (Parquet no S3) |
| **bigdata-dbt-modeling** (este) | Camadas silver e gold (Iceberg), relacionamento entre fontes e validação de qualidade |
| [bigdata-airflow-dags](https://github.com/adimov-jb/bigdata-airflow-dags) | Orquestração diária, alertas por e-mail e monitoramento de freshness |

| Domínio | Fontes | Principais tabelas na gold |
|---|---|---|
| Clima | [Open-Meteo](https://open-meteo.com/): tempo horário de 10 capitais brasileiras | `fct_weather_daily`, `dim_city` |
| Países | [Rest Countries v5](https://restcountries.com/) e [Banco Mundial](https://data.worldbank.org/): atributos dos países e indicadores socioeconômicos (PIB, inflação, expectativa de vida, pobreza, população) | `dim_country`, `fct_country_indicators_yearly`, `dq_indicator_coverage` |

Para subir e operar tudo junto, use o `scripts/platform.sh up` do repositório `bigdata-terraform`. Os problemas conhecidos estão no [RUNBOOK](https://github.com/adimov-jb/bigdata-terraform/blob/main/RUNBOOK.md).

## Domínio open_meteo

```
bronze (Parquet)                  silver (Iceberg)                        gold (Iceberg)
open_meteo_weather_hourly ──> stg_open_meteo__weather_hourly (view) ──> int_weather_hourly ──> fct_weather_daily
                                          seed: weather_codes ──────────────┘
open_meteo_locations ───────> stg_open_meteo__locations (view) ─────────────────────────────> dim_city
```

A lista de cidades vem da ingestão (fonte `open_meteo_locations`). Não existe seed de cidades: para incluir uma cidade, altere só o repositório de ingestão.

| Modelo | Camada | Materialização | O que faz |
|---|---|---|---|
| `stg_open_meteo__weather_hourly` | silver | view | Renomeia colunas para incluir a unidade (`temperature_c`, `precipitation_mm`...) |
| `int_weather_hourly` | silver | incremental (merge), particionada por dia | Deduplica por cidade e hora (fica a ingestão mais recente) e traduz o código WMO |
| `dim_city` | gold | table | Cidade, UF, região e coordenadas |
| `fct_weather_daily` | gold | incremental (merge) | Temperaturas mínima, máxima e média, chuva total, umidade, vento e condição mais severa do dia |

- **Incremental:** cada execução reprocessa os últimos `lookback_days` dias (padrão 3), o que cobre dados que chegam atrasados. O `merge` pela chave evita duplicatas.
- **Janela explícita:** `--vars '{"start_date": "2026-09-01", "end_date": "2026-09-07"}'` substitui o lookback. O Airflow passa sempre o dia do run, então backfills de datas antigas funcionam. Sem `end_date`, processa só o `start_date`.
- **Reprocessar tudo:** `dbt build --full-refresh`.
- **Build por domínio:** os domínios são os seletores de `selectors.yml` (`open_meteo` e `countries`). O Airflow roda um `dbt build --selector <domínio>` por domínio. Cada seletor pega tudo o que vem depois das sources do domínio e também as dependências desses modelos, como os seeds. Assim, um teste que falhe num domínio não impede o build de outro.
- **Testes:** `unique`, `not_null`, `relationships` e `accepted_values`, mais três testes SQL: faixa física dos valores, uma linha por cidade e hora, e dia completo na gold (`assert_gold_days_complete`). Este último falha se algum dia da janela `start_date`..`end_date` não chegou à `fct_weather_daily` ou se alguma cidade não tem as 24 horas. Sem janela, ele confere o dia mais recente. Esse teste fazia o papel da task `validate_gold` do Airflow e agora roda igual no Trino e no Athena. Há também freshness da fonte: aviso depois de 1 dia sem dados e erro depois de 2. O Airflow roda essa checagem todo dia na DAG `bronze_freshness`, e o erro dispara o alerta por e-mail.

## Domínio countries

Relaciona duas fontes: a **Rest Countries v5** (atributos dos países) e o **Banco Mundial** (indicadores por país e ano).

```
bronze (Parquet)                silver (Iceberg)                               gold (Iceberg)
rest_countries ────────> stg_rest_countries__countries ──┐
world_bank_countries ──> stg_world_bank__countries ──────┼──> int_countries ──┬──> dim_country
                         seed country_code_crosswalk ────┘                    ├──> fct_country_indicators_yearly ──> dq_indicator_coverage
world_bank_indicators ─> stg_world_bank__indicators ──────────────────────────┘
                         seed world_bank_indicators (colunas e cobertura mínima)
```

### Relacionamento

- **Chave:** o código ISO 3166-1 alpha-3, que é `codes.alpha_3` na Rest Countries e `countryiso3code` no Banco Mundial.
- **Agregados fora:** o Banco Mundial mistura países com regiões e faixas de renda, como "World" e "High income". O staging usa `world_bank_countries` (`is_aggregate`) para ficar só com os países (217).
- **Territórios sem código ISO fora:** 4 registros da Rest Countries, como Abkhazia e Somalilândia (`iso_status = 'unassigned'`), não têm `alpha_3` e não entram no staging.
- **Exceções documentadas:** o seed `country_code_crosswalk` guarda os códigos que não batem, com o motivo. Hoje são dois: `XKX` → `UNK` (Kosovo) e `CHI` (Ilhas do Canal, sem equivalente).
- **Nenhum país some:** `int_countries` é um *full outer join*, e `match_status` diz se o país está nas duas fontes (`ambas`) ou em só uma (`so_world_bank`, `so_rest_countries`). Hoje são 216 nas duas, 34 territórios só na Rest Countries (Antártida, por exemplo) e 1 só no Banco Mundial (Ilhas do Canal).

### Validação de nulos e faltantes na gold

Um `not_null` simples não serve para os indicadores. O Banco Mundial publica com atraso: no ano mais recente, a expectativa de vida fica em 0% até ser publicada. E a pobreza depende de pesquisas domiciliares, com cerca de 35% de cobertura mesmo nos anos completos. A validação separa o dado que ainda não existe do dado que deveria existir:

| Camada | Como | Onde |
|---|---|---|
| Faltante visível | A `fct` cruza todos os países com todos os anos. Dado não publicado vira célula nula, em vez de a linha sumir. `indicators_available` conta quantos indicadores vieram na linha | `fct_country_indicators_yearly` |
| Cobertura mínima | Nos anos já publicados (janela de 5 anos terminando 2 anos antes da data processada), cada indicador precisa ter valor para uma % mínima de países | `dq_indicator_coverage` + teste `assert_indicator_coverage`. Mínimos no seed `world_bank_indicators` |
| Relacionamento | País do Banco Mundial sem par na Rest Countries e sem exceção no seed faz o build falhar | teste `assert_world_bank_countries_matched` |
| Chaves | `not_null`, `unique` e `relationships` em `country_key` e `year`, e uma linha por país e ano | yml de gold e silver + `assert_one_row_per_country_year` |
| Valores | PIB e população positivos, expectativa de vida entre 10 e 100, pobreza entre 0 e 100, inflação acima de -100% | `assert_country_indicators_in_range` |
| Consistência entre fontes (aviso) | População da Rest Countries x Banco Mundial com diferença acima de 25%. Só avisa: hoje pega Chipre, Ucrânia e três ilhas pequenas, que têm diferença de metodologia | `assert_population_sources_consistent` |

Os mínimos de cobertura foram calibrados com os dados reais de 2020 a 2024: população 99%, expectativa de vida 95%, PIB 90% e inflação 75%. A pobreza fica em 0%, ou seja, só é medida. Para ver a cobertura de cada indicador por ano:

```sql
SELECT indicator_id, year, coverage_pct, min_coverage_pct, countries_missing, status
FROM iceberg.gold.dq_indicator_coverage ORDER BY indicator_id, year;
```

**Incluir um indicador:** acrescente o código em `INDICATORS`, no repositório de ingestão, e uma linha no seed `world_bank_indicators`, com o nome da coluna e a cobertura mínima. A coluna aparece sozinha na `fct`. Um teste da source falha se um indicador for ingerido sem linha no seed.

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

O jeito mais simples de subir e operar os quatro repositórios juntos é o `scripts/platform.sh` do repositório `bigdata-terraform` (`up`, `build`, `status` e `reset`). Problemas comuns e como resolvê-los estão no [RUNBOOK](https://github.com/adimov-jb/bigdata-terraform/blob/main/RUNBOOK.md).

O `scripts/platform.sh build` grava o commit deste repositório na imagem, e toda execução imprime `bigdata-dbt commit <sha>` na primeira linha do log. Um `docker compose build` direto grava `dev`.

**Dependências:** `requirements.in` fixa `dbt-core` e os adapters. `requirements.lock`, gerado por `scripts/lock.sh`, fixa todas as dependências, e é ele que a imagem instala. Para atualizar, edite o `.in` se precisar, rode `scripts/lock.sh`, revise o diff e rode os testes.

```bash
docker compose build                                # imagem bigdata-dbt:local
docker compose run --rm dbt debug                   # testa a conexão com o Trino
docker compose run --rm dbt build                   # seeds + modelos + testes
docker compose run --rm dbt build --selector open_meteo --vars '{"start_date": "2026-09-29"}'  # um domínio, um dia (como o Airflow)
docker compose run --rm dbt build --selector countries                                   # países e indicadores
docker compose run --rm dbt build --full-refresh    # recria as tabelas incrementais
docker compose run --rm dbt source freshness

# Valida o projeto nos targets local e aws, sem conectar a nada (é o que a CI roda)
docker compose run --rm --build tests

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

## CI

O workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda em todo PR e em todo push para a `main`, com `dbt parse` nos targets `local` e `aws` (`docker compose run --rm --build tests`). Isso pega erros de Jinja, `ref`/`source` quebrados e YAML inválido nos dois adapters, mas não executa SQL.

## Variáveis de ambiente

| Variável | Local | AWS |
|---|---|---|
| `DBT_TARGET` | `local` (`.env.local`) | `aws` |
| `TRINO_HOST` / `TRINO_PORT` | `trino` / `8080` (contrato da plataforma) | não usado |
| `SILVER_BUCKET` / `GOLD_BUCKET` | `bigdata-local-silver` / `bigdata-local-gold` (contrato da plataforma) | saídas do Terraform |
| `DBT_SCHEMA_PREFIX` | vazio | `bigdata_dev_` |
| `ATHENA_RESULTS_BUCKET`, `ATHENA_WORKGROUP`, `AWS_REGION` | não usados | saídas do Terraform |

O "contrato da plataforma" é `platform/local.env`, gerado pelo `terraform apply` do repositório `bigdata-terraform`. O `docker-compose.yml` carrega esse arquivo e depois o `.env.local`, que guarda só o que é do dbt.
