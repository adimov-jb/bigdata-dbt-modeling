-- Falha se a deduplicação deixar mais de uma leitura por cidade e hora.
select city, observed_at, count(*) as rows_found
from {{ ref('int_weather_hourly') }}
group by city, observed_at
having count(*) > 1
