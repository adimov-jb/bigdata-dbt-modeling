-- Indicadores do snapshot mais recente, só de países (sem regiões e faixas de renda).
-- Usa um snapshot inteiro, e não a última versão de cada linha, para não misturar
-- revisões publicadas em dias diferentes.
with latest as (

    select max(dt) as dt from {{ source('world_bank', 'indicators') }}

)

select
    i.indicator_id,
    i.indicator_name,
    i.country_iso3,
    i.country_name,
    cast(i.year as integer) as year,
    i.value,
    i.obs_status,
    i.ingested_at
from {{ source('world_bank', 'indicators') }} as i
inner join latest
    on i.dt = latest.dt
inner join {{ ref('stg_world_bank__countries') }} as c
    on i.country_iso3 = c.iso3
