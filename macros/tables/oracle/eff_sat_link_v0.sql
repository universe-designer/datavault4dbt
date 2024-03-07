{%- macro oracle__eff_sat_link_v0(link_hashkey, driving_key, secondary_fks, src_ldts, src_rsrc, source_model) -%}

{{- datavault4dbt.check_required_parameters(link_hashkey=link_hashkey, driving_key=driving_key, secondary_fks=secondary_fks,
                                       src_ldts=src_ldts, src_rsrc=src_rsrc,
                                       source_model=source_model) -}}

{%- set source_cols = datavault4dbt.expand_column_list(columns=[link_hashkey, driving_key, src_rsrc, src_ldts]) -%}
{%- set union_cols = datavault4dbt.expand_column_list(columns=[link_hashkey, driving_key, src_rsrc]) -%}
{%- set final_cols = datavault4dbt.expand_column_list(columns=[link_hashkey, driving_key, src_ldts, src_rsrc]) -%}

{%- set source_relation = ref(source_model) -%}
{{ datavault4dbt.prepend_generated_by() }}

WITH

{#
    Get all records from staging layer where driving key and secondary foreign keys are not null.
    Deduplicate over HK+Driving Key unequals the previous (regarding src_ldts) combination.
#}
stage AS 
(
    SELECT *
    FROM (
            SELECT
                {{ datavault4dbt.prefix(source_cols, 'source_model') }},
                CASE WHEN {{ datavault4dbt.prefix([link_hashkey], 'source_model') }} = LAG({{ datavault4dbt.prefix([link_hashkey], 'source_model') }}) OVER (PARTITION BY {{ datavault4dbt.prefix([driving_key], 'source_model') }} ORDER BY {{ datavault4dbt.prefix([src_ldts], 'source_model') }}) THEN 0
                     ELSE 1
                END AS appearance
            FROM {{ source_relation }} source_model
            WHERE {{ datavault4dbt.multikey(driving_key, prefix='source_model', condition='IS NOT NULL') }}
            AND {{ datavault4dbt.multikey(secondary_fks, prefix='source_model', condition='IS NOT NULL') }}
          )
    WHERE appearance = 1
),

{%- if is_incremental() %}

{#
    Get the latest record for each driving key, already existing in eff_sat and included in incoming batch. Only applied if incremental.
#}

latest_record AS 
(
    SELECT *
    FROM (
        SELECT
            {{ datavault4dbt.prefix(source_cols, 'current_records') }},
            ROW_NUMBER() OVER (PARTITION BY {{ datavault4dbt.prefix([driving_key], 'current_records') }} ORDER BY {{ datavault4dbt.prefix([src_ldts], 'current_records') }} DESC) AS rn
        FROM {{ this }} current_records
        INNER JOIN (
            SELECT DISTINCT
                {{ datavault4dbt.prefix([driving_key], 'stage') }}
            FROM stage
        ) source_records
            ON {{ datavault4dbt.multikey(driving_key, prefix=['current_records', 'source_records'], condition='=') }}
        )
    WHERE rn = 1
),
{%- endif %}

{#
    Select only incoming records from the stage, that are newer than the latest record in the eff_sat, or when it does not exist yet.
    Creates the src_ldts_lead for intermediate changes, and a rank column over the driving key, order by the ldts.
#}
stage_new AS 
(
    SELECT
        {{ datavault4dbt.prefix(source_cols, 'stage') }},
        LEAD({{ datavault4dbt.prefix([src_ldts], 'stage') }}) OVER (PARTITION BY {{ datavault4dbt.prefix([driving_key], 'stage') }} ORDER BY {{ datavault4dbt.prefix([src_ldts], 'stage') }}) AS src_ldts_lead,
        ROW_NUMBER() OVER (PARTITION BY {{ datavault4dbt.prefix([driving_key], 'stage') }} ORDER BY {{ datavault4dbt.prefix([src_ldts], 'stage') }}) as stage_rank
    FROM stage
    {%- if is_incremental() %}
    LEFT JOIN latest_record
        ON {{ datavault4dbt.multikey(driving_key, prefix=['stage', 'latest_record'], condition='=') }}
    WHERE {{ datavault4dbt.prefix([src_ldts], 'stage') }} > {{ datavault4dbt.prefix([src_ldts], 'latest_record') }}
        OR {{ datavault4dbt.prefix([src_ldts], 'latest_record') }} IS NULL
    {%- endif %}
),

{%- if is_incremental() -%}

{#
    Disable all latest records in the eff_sat, when there is a new relationship for that driving key in the stage.
#}

deactivated_existing AS 
(
    SELECT {{ datavault4dbt.prefix(union_cols, 'dax') }},
           {{ datavault4dbt.prefix([src_ldts], 'dax') }} AS {{ src_ldts }},
           is_active
    FROM (
            SELECT
                {{ datavault4dbt.prefix(union_cols, 'latest_record') }},
                {{ datavault4dbt.prefix([src_ldts], 'stage_new') }} AS {{ src_ldts }},
                0 AS is_active,
                ROW_NUMBER() OVER (PARTITION BY {{ datavault4dbt.prefix([driving_key], 'stage_new') }} ORDER BY {{ datavault4dbt.prefix([src_ldts], 'stage_new') }}) AS rn
            FROM latest_record
            LEFT JOIN stage_new
                ON {{ datavault4dbt.multikey(driving_key, prefix=['latest_record', 'stage_new'], condition='=') }}
            WHERE {{ datavault4dbt.prefix([link_hashkey], 'latest_record') }} != {{ datavault4dbt.prefix([link_hashkey], 'stage_new') }}
            ) dax
    WHERE rn = 1

),

{%- endif %}

{#
    Activate all rows that have a different relationship for an existing driving key OR where the driving key is not yet existing in the eff_sat
    OR is not the first new one in the incoming data (due to intermediate changes).
#}

activated_new_records AS 
(

    SELECT
        {{ datavault4dbt.prefix(union_cols, 'stage_new') }},
        {{ datavault4dbt.prefix([src_ldts], 'stage_new') }} AS {{ src_ldts }},
        1 AS is_active
    FROM stage_new
    {%- if is_incremental() %}
    LEFT JOIN latest_record
        ON {{ datavault4dbt.multikey(driving_key, prefix=['stage_new', 'latest_record'], condition='=') }}
    WHERE {{ datavault4dbt.prefix([link_hashkey], 'stage_new') }} != {{ datavault4dbt.prefix([link_hashkey], 'latest_record') }}
        OR {{ datavault4dbt.prefix([src_ldts], 'latest_record') }} IS NULL
        OR stage_new.stage_rank != 1
    {%- endif %}

),

{#
    Deactivate all intermediate changes that are not the latest one.
#}

deactivated_intermediates AS 
(
    SELECT {{ datavault4dbt.prefix(union_cols, 'stage_new') }}, src_ldts, is_active
    FROM (
            SELECT
                {{ datavault4dbt.prefix(union_cols, 'stage_new') }},
                stage_new.src_ldts_lead AS src_ldts,
                0 AS is_active,
                ROW_NUMBER() OVER (PARTITION BY {{ datavault4dbt.prefix([driving_key], 'stage_new') }} ORDER BY {{ datavault4dbt.prefix([src_ldts], 'stage_new') }} DESC) AS rn
            FROM stage_new
            {%- if is_incremental() %}
            LEFT JOIN latest_record
                ON {{ datavault4dbt.multikey(driving_key, prefix=['stage_new', 'latest_record'], condition='=') }}
            WHERE {{ datavault4dbt.prefix([link_hashkey], 'stage_new') }} != {{ datavault4dbt.prefix([link_hashkey], 'latest_record') }}
                OR {{ datavault4dbt.prefix([src_ldts], 'latest_record') }} IS NULL
                OR stage_new.stage_rank != 1
            {%- endif %}
        ) stage_new
    WHERE rn != 1
),

{#
    Unionize all three cases for final insertion.
#}

final_columns_to_select AS 
(

    SELECT * FROM activated_new_records

    UNION ALL

    SELECT * FROM deactivated_intermediates

    {% if is_incremental() -%}
    UNION ALL

    SELECT * FROM deactivated_existing
    {%- endif %}
)

SELECT * FROM final_columns_to_select

{% endmacro %}
