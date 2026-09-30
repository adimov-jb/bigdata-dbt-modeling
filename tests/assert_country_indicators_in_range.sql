-- Valores impossíveis nos indicadores. Nulos não entram aqui: são tratados pela cobertura.
select country_key, year, gdp_usd, population, life_expectancy_years, poverty_pct, inflation_pct
from {{ ref('fct_country_indicators_yearly') }}
where gdp_usd <= 0
    or population <= 0
    or life_expectancy_years not between 10 and 100
    or poverty_pct not between 0 and 100
    -- Deflação abaixo de -100% é impossível; hiperinflação alta é real (sem limite superior).
    or inflation_pct < -100
