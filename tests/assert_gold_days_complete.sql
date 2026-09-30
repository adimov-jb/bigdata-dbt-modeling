-- Falha se um dia da janela não chegou à gold ou se alguma cidade não tem as 24 horas.
-- Janela: start_date..end_date (Airflow e backfill). Sem janela, confere o dia mais recente.
-- Substitui a validação que ficava no Airflow; roda igual no Trino e no Athena.
{% set start_date = var('start_date') %}
{% set end_date = var('end_date') or var('start_date') %}

with expected_days as (

    {% if start_date %}
        select observed_date
        from unnest(
            sequence(date '{{ start_date }}', date '{{ end_date }}', interval '1' day)
        ) as t (observed_date)
    {% else %}
        select max(observed_date) as observed_date
        from {{ ref('fct_weather_daily') }}
    {% endif %}

),

daily as (

    select f.observed_date, f.city, f.hours_observed
    from {{ ref('fct_weather_daily') }} as f
    inner join expected_days as d
        on f.observed_date = d.observed_date

)

select
    d.observed_date,
    'dia sem dados na gold' as problem,
    cast(null as varchar) as city,
    cast(null as bigint) as hours_observed
from expected_days as d
where not exists (
    select 1 from daily where daily.observed_date = d.observed_date
)

union all

select
    observed_date,
    'cidade sem as 24 horas' as problem,
    city,
    hours_observed
from daily
where hours_observed <> 24
