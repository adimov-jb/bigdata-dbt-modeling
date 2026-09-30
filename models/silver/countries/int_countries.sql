-- Relacionamento entre as duas fontes de países, pelo código ISO 3166-1 alpha-3.
-- Full outer join de propósito: país sem par não some, vira linha com match_status
-- 'so_world_bank' ou 'so_rest_countries', e os testes decidem se isso é esperado.
-- Exceções de código (Banco Mundial x ISO) ficam documentadas no seed country_code_crosswalk.
with world_bank as (

    select
        wb.*,
        cw.world_bank_iso3 is not null as has_crosswalk_rule,
        cw.reason as crosswalk_reason,
        -- Com regra no seed, vale o código de lá (vazio = sem equivalente na Rest Countries).
        case
            when cw.world_bank_iso3 is not null then nullif(trim(cw.rest_countries_alpha_3), '')
            else wb.iso3
        end as rest_countries_key
    from {{ ref('stg_world_bank__countries') }} as wb
    left join {{ ref('country_code_crosswalk') }} as cw
        on wb.iso3 = cw.world_bank_iso3

),

rest_countries as (

    select * from {{ ref('stg_rest_countries__countries') }}

)

select
    -- Chave do país na gold: o código ISO da Rest Countries, ou o do Banco Mundial sem par.
    coalesce(rc.alpha_3, wb.iso3) as country_key,
    rc.alpha_3 as rest_countries_alpha_3,
    wb.iso3 as world_bank_iso3,
    case
        when rc.alpha_3 is not null and wb.iso3 is not null then 'ambas'
        when wb.iso3 is not null then 'so_world_bank'
        else 'so_rest_countries'
    end as match_status,
    coalesce(wb.has_crosswalk_rule, false) as has_crosswalk_rule,
    wb.crosswalk_reason,

    coalesce(rc.name_common, wb.name) as country_name,
    rc.name_official,
    coalesce(rc.alpha_2, wb.iso2) as alpha_2,
    rc.numeric_code,
    rc.region,
    rc.subregion,
    wb.region as world_bank_region,
    wb.income_level,
    wb.lending_type,
    rc.population as population_current,
    rc.area_km2,
    coalesce(rc.capital, wb.capital_city) as capital,
    rc.currencies,
    rc.languages,
    rc.timezones,
    rc.un_member,
    rc.sovereign,
    coalesce(rc.latitude, wb.latitude) as latitude,
    coalesce(rc.longitude, wb.longitude) as longitude
from world_bank as wb
full outer join rest_countries as rc
    on wb.rest_countries_key = rc.alpha_3
