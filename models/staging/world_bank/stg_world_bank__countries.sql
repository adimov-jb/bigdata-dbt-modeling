-- Países do snapshot mais recente. Regiões e faixas de renda (agregados) ficam de fora:
-- não são países e não têm correspondente na Rest Countries.
with latest as (

    select max(dt) as dt from {{ source('world_bank', 'countries') }}

)

select
    c.iso3,
    c.iso2,
    c.name,
    c.region,
    c.income_level,
    c.lending_type,
    c.capital_city,
    c.latitude,
    c.longitude
from {{ source('world_bank', 'countries') }} as c
inner join latest
    on c.dt = latest.dt
where not c.is_aggregate
