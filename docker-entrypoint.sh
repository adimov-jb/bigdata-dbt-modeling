#!/bin/sh
# Primeira linha do log de toda execução: identifica o código que rodou.
echo "bigdata-dbt commit ${BIGDATA_VERSION:-dev}"
exec dbt "$@"
