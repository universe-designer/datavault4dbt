{%- macro delete_tables() -%}
    {% if execute %}
      {% for node in graph.nodes.values()
         | selectattr("resource_type", "equalto", "model") %}
        {% if not node.name.startswith("META_") and node.config.materialized == "table"%}
DELETE {{node.config.schema}}.{{node.name}};
        {%- endif -%}
      {% endfor %}
    {% endif %}
{%- endmacro -%}