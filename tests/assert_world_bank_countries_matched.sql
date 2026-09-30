-- Relacionamento: todo país do Banco Mundial precisa ter par na Rest Countries, a menos que
-- a exceção esteja documentada no seed country_code_crosswalk. Falha aqui significa código
-- novo ou alterado numa das APIs: documente no seed ou corrija o mapeamento.
select world_bank_iso3, country_name
from {{ ref('int_countries') }}
where match_status = 'so_world_bank'
    and not has_crosswalk_rule
