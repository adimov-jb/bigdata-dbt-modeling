-- depends_on: {{ ref('world_bank_indicators') }}
-- Indicadores do Banco Mundial por país e ano, uma coluna por indicador.
-- A grade país x ano é completa: se a API não trouxe a linha ou trouxe o valor nulo,
-- a célula fica nula aqui, em vez de a linha sumir. Faltantes ficam visíveis e contáveis.
-- As colunas vêm do seed world_bank_indicators: indicador novo = linha nova no seed.
{%- set indicators = [] -%}
{%- if execute -%}
    {%- set result = run_query(
        "select indicator_id, column_name from " ~ ref('world_bank_indicators') ~ " order by column_name"
    ) -%}
    {%- set indicators = result.rows -%}
{%- endif %}

with countries as (

    select country_key, world_bank_iso3
    from {{ ref('int_countries') }}
    where world_bank_iso3 is not null

),

years as (

    select distinct year from {{ ref('stg_world_bank__indicators') }}

),

grid as (

    select c.country_key, c.world_bank_iso3, y.year
    from countries as c
    cross join years as y

),

pivoted as (

    select
        country_iso3,
        year
        {%- for indicator in indicators %},
        max(case when indicator_id = '{{ indicator[0] }}' then value end) as {{ indicator[1] }}
        {%- endfor %}
    from {{ ref('stg_world_bank__indicators') }}
    group by country_iso3, year

)

select
    g.country_key,
    g.year
    {%- for indicator in indicators %},
    p.{{ indicator[1] }}
    {%- endfor %},
    -- Derivado: nulo se faltar PIB ou população.
    p.gdp_usd / nullif(p.population, 0) as gdp_per_capita_usd,
    0
    {%- for indicator in indicators %}
    + case when p.{{ indicator[1] }} is not null then 1 else 0 end
    {%- endfor %} as indicators_available,
    {{ indicators | length }} as indicators_expected
from grid as g
left join pivoted as p
    on g.world_bank_iso3 = p.country_iso3
    and g.year = p.year
