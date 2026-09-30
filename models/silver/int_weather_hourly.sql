{{
    config(
        incremental_strategy='merge',
        unique_key=['city', 'observed_at'],
        on_schema_change='append_new_columns',
        properties={"partitioning": "ARRAY['day(observed_at)']"} if target.type == 'trino' else none,
        partitioned_by=['day(observed_at)'] if target.type == 'athena' else none,
    )
}}

-- Silver: uma linha por cidade e hora, sem duplicatas, com a descrição do tempo.
with source as (

    select * from {{ ref('stg_open_meteo__weather_hourly') }}
    where observed_at is not null
    {% if is_incremental() %}
        -- dt é 'YYYY-MM-DD' (texto): filtrar por ele aproveita a partição da bronze.
        {% if var('start_date') %}
            -- Janela explícita (Airflow, backfill).
            and dt between '{{ var("start_date") }}' and '{{ var("end_date") or var("start_date") }}'
        {% else %}
            and dt >= cast(
                date_add('day', -{{ var('lookback_days') }}, (select max(observed_date) from {{ this }}))
                as varchar
            )
        {% endif %}
    {% endif %}

),

deduplicated as (

    -- Reingestões do mesmo dia: fica a leitura mais recente.
    select
        *,
        row_number() over (partition by city, observed_at order by ingested_at desc) as row_num
    from source

)

select
    d.city,
    d.latitude,
    d.longitude,
    cast(d.observed_at as timestamp(6)) as observed_at,
    cast(d.observed_at as date) as observed_date,
    d.temperature_c,
    d.relative_humidity_pct,
    d.precipitation_mm,
    d.wind_speed_kmh,
    d.weather_code,
    wc.description as weather_description,
    cast(d.ingested_at as timestamp(6)) as ingested_at
from deduplicated as d
left join {{ ref('weather_codes') }} as wc
    on d.weather_code = wc.weather_code
where d.row_num = 1
