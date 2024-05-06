{%- macro create_partitions(first_partition_date) -%}
    {% if execute %}
      {% for node in graph.nodes.values()
         | selectattr("resource_type", "equalto", "model") %}
        {% if not node.name.startswith("META_") %}
ALTER TABLE {{node.config.schema}}.{{node.name}} MODIFY
PARTITION  BY RANGE (cdwh_load_ts) INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
 (PARTITION VALUES LESS THAN (TO_DATE('{{ first_partition_date }}', 'YYYY-MM-DD', 'NLS_CALENDAR=GREGORIAN')))
ONLINE
UPDATE INDEXES;
        {%- endif -%}
      {% endfor %}
    {% endif %}
{%- endmacro -%}