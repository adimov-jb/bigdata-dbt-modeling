-- Dimensão de cidades: UF, região e coordenadas vêm da ingestão (fonte única).
select
    city,
    state,
    region,
    latitude,
    longitude
from {{ ref('stg_open_meteo__locations') }}
