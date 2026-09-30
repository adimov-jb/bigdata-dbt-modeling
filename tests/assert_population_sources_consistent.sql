{{ config(severity='warn') }}
-- Consistência entre as fontes: a população atual da Rest Countries e a mais recente do
-- Banco Mundial não deveriam divergir mais que 25%. Só avisa: as fontes têm datas de
-- referência e metodologias diferentes, mas divergência grande costuma indicar par errado.
with latest_world_bank as (

    select country_key, population, year,
        row_number() over (partition by country_key order by year desc) as row_num
    from {{ ref('fct_country_indicators_yearly') }}
    where population is not null

)

select
    d.country_key,
    d.country_name,
    d.population_current as population_rest_countries,
    w.population as population_world_bank,
    w.year as world_bank_year
from {{ ref('dim_country') }} as d
inner join latest_world_bank as w
    on d.country_key = w.country_key
    and w.row_num = 1
where d.population_current > 0
    and abs(d.population_current - w.population) / w.population > 0.25
