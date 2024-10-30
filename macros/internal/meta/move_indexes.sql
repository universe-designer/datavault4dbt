{%- macro move_indexes(schema, tablespace) -%}
    {% if execute %}


SELECT 'ALTER INDEX '||OWNER||'.'||INDEX_NAME||' REBUILD TABLESPACE {{ tablespace }} ; ' AS SQL_COMMAND
FROM all_indexes
WHERE owner = UPPER('{{ schema }}')
  AND tablespace_name != '{{ tablespace }}'
  AND UPPER(owner||'.'||table_name)  IN (

      {% for node in graph.nodes.values()
         | selectattr("resource_type", "equalto", "model") %}
        {% if not node.name.startswith("META_") %}

            UPPER('{{node.config.schema}}.{{node.name}}'),

        {%- endif -%}
      {% endfor %}
      '');
    {% endif %}
{%- endmacro -%}