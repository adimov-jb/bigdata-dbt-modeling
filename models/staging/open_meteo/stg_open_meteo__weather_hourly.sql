-- Padroniza nomes e unidades da bronze. Sem regras de negócio.
select
    city,
    latitude,
    longitude,
    observed_at,
    temperature_2m as temperature_c,
    relative_humidity_2m as relative_humidity_pct,
    precipitation as precipitation_mm,
    wind_speed_10m as wind_speed_kmh,
    cast(weather_code as integer) as weather_code,
    ingested_at,
    dt
from {{ source('open_meteo', 'weather_hourly') }}
