{#
    Local (Trino): cria cada schema no bucket da sua camada, lido de <SCHEMA>_BUCKET
    (ex.: silver -> SILVER_BUCKET). Sem isso o Trino usaria o warehouse padrão do metastore.
    Na AWS os databases já existem no Glue (Terraform) e o adapter Athena não usa esta macro.
#}
{% macro trino__create_schema(relation) -%}
    {%- set bucket = env_var(relation.schema | upper ~ '_BUCKET', '') -%}
    {%- call statement('create_schema') -%}
        create schema if not exists {{ relation.without_identifier() }}
        {%- if bucket %} with (location = 's3://{{ bucket }}/'){% endif %}
    {%- endcall -%}
{%- endmacro %}
