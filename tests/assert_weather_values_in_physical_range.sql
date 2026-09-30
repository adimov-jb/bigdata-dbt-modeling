-- Falha se houver leituras fisicamente impossíveis na silver.
select *
from {{ ref('int_weather_hourly') }}
where relative_humidity_pct not between 0 and 100
    or temperature_c not between -60 and 60
    or precipitation_mm < 0
    or wind_speed_kmh < 0
