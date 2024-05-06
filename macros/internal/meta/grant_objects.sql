{%- macro grant_objects(user) -%}
    {% if execute %}
      {% for node in graph.nodes.values()
         | selectattr("resource_type", "equalto", "model") %}
        {% if node.path.startswith("stage") %}
GRANT SELECT ON {{node.config.schema}}.{{node.name}} TO {{user}} WITH GRANT OPTION;
        {%- endif -%}
      {% endfor %}
    {% endif %}
{%- endmacro -%}