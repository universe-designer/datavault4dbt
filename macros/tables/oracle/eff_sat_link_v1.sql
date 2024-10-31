{%- macro oracle__eff_sat_link_v1(eff_sat_link_v0, link_hashkey, src_ldts, src_rsrc, eff_from_alias, eff_to_alias, add_is_current_flag) -%}

{%- set source_cols = datavault4dbt.expand_column_list(columns=[link_hashkey, src_rsrc, src_ldts, 'is_active']) -%}
{%- set final_cols = datavault4dbt.expand_column_list(columns=[link_hashkey, src_rsrc, eff_from_alias, eff_to_alias]) -%}

{%- set end_of_all_times = datavault4dbt.end_of_all_times() -%}
{%- set timestamp_format = datavault4dbt.timestamp_format() -%}
{%- set is_current_col_alias = var('datavault4dbt.is_current_col_alias', 'IS_CURRENT') -%}

{%- set hash = var('datavault4dbt.hash', 'MD5') -%}
{%- set hash_dtype = var('datavault4dbt.hash_datatype', 'HASHTYPE') -%}
{%- set hash_default_values = fromjson(datavault4dbt.hash_default_values(hash_function=hash,hash_datatype=hash_dtype)) -%}
{%- set hash_alg = hash_default_values['hash_alg'] -%}
{%- set unknown_key = hash_default_values['unknown_key'] -%}
{%- set error_key = hash_default_values['error_key'] -%}

{%- set source_relation = ref(eff_sat_link_v0) -%}

{{ datavault4dbt.prepend_generated_by() }}

WITH

source_data AS (

    SELECT
        {{ datavault4dbt.prefix(source_cols, 'sat_v0') }}
    FROM {{ source_relation }} sat_v0

),

eff_ranges AS (

    SELECT
        {{ link_hashkey }},
        {{ src_rsrc }},
        is_active,
        {{ src_ldts }} AS {{ eff_from_alias }},
        COALESCE(LEAD({{ src_ldts }} - INTERVAL '0.001' SECOND) OVER (PARTITION BY {{ link_hashkey }} ORDER BY {{ src_ldts }}),{{ datavault4dbt.string_to_timestamp( timestamp_format , end_of_all_times) }}) as {{ eff_to_alias }}
    FROM source_data

),

records_to_select AS (

    SELECT
        {{ datavault4dbt.print_list(final_cols) }}
        {%- if add_is_current_flag %},
            CASE WHEN {{ eff_to_alias }} = {{ datavault4dbt.string_to_timestamp(timestamp_format, end_of_all_times) }}
            THEN 1
            ELSE 0
            END AS {{ is_current_col_alias }}
        {% endif %}
    FROM eff_ranges
    WHERE is_active = 1

)

SELECT * FROM records_to_select

{%- endmacro -%}
