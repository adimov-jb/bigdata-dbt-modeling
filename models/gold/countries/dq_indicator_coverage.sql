-- depends_on: {{ ref('world_bank_indicators') }}
-- depends_on: {{ ref('fct_country_indicators_yearly') }}
-- (os ref dentro do laço não são vistos no parse; sem estas linhas o modelo e o teste
-- assert_indicator_coverage ficariam fora do seletor countries.)
-- Qualidade da gold de países: cobertura de cada indicador por ano.
-- coverage_pct = % dos países do Banco Mundial com valor publicado naquele ano.
-- Só os anos da janela de referência são cobrados (status 'abaixo_do_minimo' faz o teste
-- assert_indicator_coverage falhar): o ano corrente e o anterior quase sempre estão
-- incompletos, porque o Banco Mundial publica com atraso (a expectativa de vida, por
-- exemplo, fica em 0% no ano mais recente até ser publicada).
{%- set indicators = [] -%}
{%- if execute -%}
    {%- set result = run_query(
        "select indicator_id, column_name from " ~ ref('world_bank_indicators') ~ " order by column_name"
    ) -%}
    {%- set indicators = result.rows -%}
{%- endif -%}
{%- set reference_date = "date '" ~ var('start_date') ~ "'" if var('start_date') else 'current_date' -%}
{%- set last_year = "(year(" ~ reference_date ~ ") - " ~ var('countries_publication_lag_years') ~ ")" -%}
{%- set first_year = "(" ~ last_year ~ " - " ~ var('countries_coverage_window_years') ~ " + 1)" %}

with coverage as (

    {%- for indicator in indicators %}
    select
        '{{ indicator[0] }}' as indicator_id,
        year,
        count(*) as countries_expected,
        count({{ indicator[1] }}) as countries_with_value
    from {{ ref('fct_country_indicators_yearly') }}
    group by year
    {%- if not loop.last %}

    union all
    {%- endif %}
    {%- endfor %}

),

measured as (

    select
        i.indicator_id,
        i.column_name,
        i.description,
        c.year,
        c.countries_expected,
        c.countries_with_value,
        c.countries_expected - c.countries_with_value as countries_missing,
        round(100.0 * c.countries_with_value / c.countries_expected, 1) as coverage_pct,
        i.min_coverage_pct,
        c.year between {{ first_year }} and {{ last_year }} as in_reference_window
    from coverage as c
    inner join {{ ref('world_bank_indicators') }} as i
        on c.indicator_id = i.indicator_id

)

select
    *,
    case
        when not in_reference_window then 'fora_da_janela'
        when coverage_pct < min_coverage_pct then 'abaixo_do_minimo'
        else 'ok'
    end as status
from measured
