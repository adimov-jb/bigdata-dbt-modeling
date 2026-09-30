{#
    Usa o schema configurado (silver/gold) como nome final, em vez do padrão do dbt
    <schema_do_target>_<schema_custom>. Na AWS aplica o prefixo dos databases do Glue.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ env_var('DBT_SCHEMA_PREFIX', '') ~ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
