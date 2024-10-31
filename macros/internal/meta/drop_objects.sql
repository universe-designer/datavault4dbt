{%- macro drop_objects() -%}
    {% if execute %}
      {% for node in graph.nodes.values()
         | selectattr("resource_type", "equalto", "model") %}
        {% if not node.name.startswith("META_") %}
DROP {{node.config.materialized.upper()}} {{node.config.schema}}.{{node.name}}
            {%- if node.config.materialized == "table" %} CASCADE CONSTRAINTS
            {%- endif -%}
;
        {%- endif -%}
      {% endfor %}
    {% endif %}
{%- endmacro -%}