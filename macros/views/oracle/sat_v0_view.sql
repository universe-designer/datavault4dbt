{%- macro oracle__sat_v0_view(parent_hashkey, src_hashdiff, src_payload, src_ldts, src_rsrc, source_model) -%}

{%- set beginning_of_all_times = datavault4dbt.beginning_of_all_times() -%}
{%- set end_of_all_times = datavault4dbt.end_of_all_times() -%}
{%- set timestamp_format = datavault4dbt.timestamp_format() -%}

{%- set ns=namespace(src_hashdiff="", hdiff_alias="") %}

{%- if  src_hashdiff is mapping and src_hashdiff is not none -%}
    {% set ns.src_hashdiff = src_hashdiff["source_column"] %}
    {% set ns.hdiff_alias = src_hashdiff["alias"] %}
{% else %}
    {% set ns.src_hashdiff = src_hashdiff %}
    {% set ns.hdiff_alias = src_hashdiff  %}
{%- endif -%}

{%- set source_cols = datavault4dbt.expand_column_list(columns=[src_rsrc, src_ldts, src_payload]) -%}

{%- set source_relation = ref(source_model) -%}

{{ datavault4dbt.prepend_generated_by() }}

WITH

{# Selecting all source data, that is newer than latest data in sat if incremental #}
source_data AS (

    SELECT
        {{ parent_hashkey }},
        {{ ns.src_hashdiff }} as {{ ns.hdiff_alias }},
        {{ datavault4dbt.print_list(source_cols) }}
    FROM {{ source_relation }}


    WHERE {{ src_ldts }} > (
        SELECT
            MAX({{ src_ldts }}) FROM {{ this | replace("_VI","") }}
        WHERE {{ src_ldts }} != {{ datavault4dbt.string_to_timestamp(timestamp_format, end_of_all_times) }}
    )
    OR  NVL((SELECT COUNT(*)
             FROM {{ source_relation }} ),0) = 0

),

{# Get the latest record for each parent hashkey in existing sat, if incremental. #}

latest_entries_in_sat AS (
    SELECT *
    FROM (
            SELECT
                {{ parent_hashkey }},
                ROW_NUMBER() OVER(PARTITION BY {{ parent_hashkey|lower }} ORDER BY {{ src_ldts }} DESC) AS latest,
                {{ ns.hdiff_alias }}
            FROM
                {{ this | replace("_VI","") }}

         )
    WHERE latest = 1
),

{# 
    Deduplicate source by comparing each hashdiff to the hashdiff of the previous record, for each hashkey. 
#}
deduplicate_qualify as (
    SELECT *
    FROM (
            SELECT
                {{ parent_hashkey }},
                {{ ns.hdiff_alias }},
                CASE
                    WHEN {{ ns.hdiff_alias }} = LAG({{ ns.hdiff_alias }}) OVER(PARTITION BY {{ parent_hashkey|lower }} ORDER BY {{ src_ldts }}) THEN 0
                    ELSE 1
                END AS latest,
                {{ datavault4dbt.print_list(source_cols) }}
            FROM source_data
         )
    WHERE latest = 1
),
{#
    Adding a row number based on the order of appearance in the stage (load date), if incremental.
#}
deduplicated_numbered_source AS (

    SELECT
        {{ parent_hashkey }},
        {{ ns.hdiff_alias }},
        {{ datavault4dbt.print_list(source_cols) }}
    , ROW_NUMBER() OVER(PARTITION BY {{ parent_hashkey }} ORDER BY {{ src_ldts }}) as rn
    FROM deduplicate_qualify
),
{#
    Select all records from the previous CTE. If incremental, compare the oldest incoming entry to
    the existing records in the satellite.
#}
records_to_insert AS (

    SELECT
    {{ parent_hashkey }},
    {{ ns.hdiff_alias }},
    {{ datavault4dbt.print_list(source_cols) }}
    FROM deduplicated_numbered_source
    WHERE NOT EXISTS (
        SELECT 1
        FROM latest_entries_in_sat
        WHERE {{ datavault4dbt.multikey(parent_hashkey, prefix=['latest_entries_in_sat', 'deduplicated_numbered_source'], condition='=') }}
            AND {{ datavault4dbt.multikey(ns.hdiff_alias, prefix=['latest_entries_in_sat', 'deduplicated_numbered_source'], condition='=') }}
            AND deduplicated_numbered_source.rn = 1)

    )

SELECT * FROM records_to_insert

{%- endmacro -%}
