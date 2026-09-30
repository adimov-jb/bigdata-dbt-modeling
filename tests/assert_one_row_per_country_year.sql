-- A fct tem uma linha por país e ano (grade completa, sem duplicatas).
select country_key, year, count(*) as rows_found
from {{ ref('fct_country_indicators_yearly') }}
group by country_key, year
having count(*) > 1
