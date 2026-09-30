-- Cidades monitoradas: último snapshot de cada cidade gravado pela ingestão.
with ranked as (

    select
        city,
        state,
        region,
        latitude,
        longitude,
        row_number() over (partition by city order by dt desc, ingested_at desc) as row_num
    from {{ source('open_meteo', 'locations') }}

)

select
    city,
    state,
    region,
    latitude,
    longitude
from ranked
where row_num = 1
