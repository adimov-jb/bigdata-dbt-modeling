-- Dimensão de países: atributos da Rest Countries, classificação do Banco Mundial e
-- de onde cada país veio (match_status), para o consumidor saber o que esperar dele.
select
    country_key,
    country_name,
    name_official,
    alpha_2,
    numeric_code,
    region,
    subregion,
    world_bank_region,
    income_level,
    population_current,
    area_km2,
    capital,
    currencies,
    languages,
    timezones,
    un_member,
    sovereign,
    latitude,
    longitude,
    match_status,
    rest_countries_alpha_3 is not null as in_rest_countries,
    world_bank_iso3 is not null as in_world_bank
from {{ ref('int_countries') }}
