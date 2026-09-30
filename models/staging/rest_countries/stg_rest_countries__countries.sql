-- Países e territórios do snapshot mais recente da Rest Countries.
-- Territórios sem código ISO (iso_status = 'unassigned', como Abkhazia e Somalilândia)
-- ficam de fora: sem alpha_3 não há como ligá-los ao Banco Mundial.
with latest as (

    select max(dt) as dt from {{ source('rest_countries', 'countries') }}

)

select
    c.alpha_3,
    c.alpha_2,
    c.numeric_code,
    c.name_common,
    c.name_official,
    c.region,
    c.subregion,
    c.population,
    c.area_km2,
    c.capital,
    c.currencies,
    c.languages,
    c.timezones,
    c.un_member,
    c.sovereign,
    c.disputed,
    c.iso_status,
    c.latitude,
    c.longitude
from {{ source('rest_countries', 'countries') }} as c
inner join latest
    on c.dt = latest.dt
where c.alpha_3 is not null
