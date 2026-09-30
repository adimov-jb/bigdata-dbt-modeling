-- Dimensão de cidades: atributos do seed + coordenadas usadas na ingestão.
with coordinates as (

    select
        city,
        max(latitude) as latitude,
        max(longitude) as longitude
    from {{ ref('int_weather_hourly') }}
    group by city

)

select
    c.city,
    c.state,
    c.region,
    co.latitude,
    co.longitude
from {{ ref('cities') }} as c
left join coordinates as co
    on c.city = co.city
