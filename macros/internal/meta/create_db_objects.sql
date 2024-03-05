{%- macro create_db_objects() -%}

    {% if execute %}
SET DDL SIZE_BYTE_KEYWORD OFF;
SET DDL SEGMENT_ATTRIBUTES OFF;
SET DDL SIZE_BYTE_KEYWORD OFF;
SET DDL STORAGE OFF;
SET DDL TABLESPACE OFF;
SET DDL SPECIFICATION OFF;
SET DDL REF_CONSTRAINTS ON;
      {% for node in graph.nodes.values()
         | selectattr("resource_type", "equalto", "model") %}
        {% if not node.name.startswith("META_") %}
DDL {{node.config.schema}}.{{node.name}};
        {%- endif -%}
      {% endfor %}
    {% endif %}
{%- endmacro -%}