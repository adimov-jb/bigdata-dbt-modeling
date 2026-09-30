-- Faltantes: na janela de anos já publicados, cada indicador precisa ter valor para pelo
-- menos min_coverage_pct % dos países (seed world_bank_indicators). Detalhes por ano e
-- quantidade de países sem valor em dq_indicator_coverage.
select indicator_id, year, coverage_pct, min_coverage_pct, countries_missing
from {{ ref('dq_indicator_coverage') }}
where status = 'abaixo_do_minimo'
