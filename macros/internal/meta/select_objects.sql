{%- macro select_objects() -%}
    {% if execute %}
      {% for node in graph.nodes.values()
         | selectattr("resource_type", "equalto", "model") %}
        {% if not node.name.startswith("META_") %}
SELECT * FROM {{node.config.schema}}.{{node.name}};
        {%- endif -%}
      {% endfor %}
    {% endif %}
{%- endmacro -%}