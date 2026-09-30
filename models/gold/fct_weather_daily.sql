{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key=['city', 'observed_date'],
        on_schema_change='append_new_columns',
    )
}}

-- Gold: resumo diário por cidade.
with hourly as (

    select * from {{ ref('int_weather_hourly') }}
    {% if is_incremental() %}
        where observed_date >= date_add(
            'day', -{{ var('lookback_days') }}, (select max(observed_date) from {{ this }})
        )
    {% endif %}

),

daily as (

    select
        city,
        observed_date,
        count(*) as hours_observed,
        round(min(temperature_c), 1) as temperature_min_c,
        round(max(temperature_c), 1) as temperature_max_c,
        round(avg(temperature_c), 1) as temperature_avg_c,
        round(sum(precipitation_mm), 1) as precipitation_total_mm,
        count_if(precipitation_mm > 0) as hours_with_precipitation,
        round(avg(relative_humidity_pct), 1) as humidity_avg_pct,
        round(max(wind_speed_kmh), 1) as wind_speed_max_kmh,
        -- Códigos WMO maiores indicam condições mais severas.
        max(weather_code) as most_severe_weather_code
    from hourly
    group by city, observed_date

)

select
    d.*,
    wc.description as most_severe_weather_description
from daily as d
left join {{ ref('weather_codes') }} as wc
    on d.most_severe_weather_code = wc.weather_code
