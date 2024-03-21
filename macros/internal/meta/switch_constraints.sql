{%- macro switch_constraints(switch) -%}
    {% if execute %}


SELECT 'ALTER TABLE '||OWNER||'.'||TABLE_NAME||' {{switch}} CONSTRAINT '|| CONSTRAINT_NAME||';'
FROM all_constraints
WHERE CONSTRAINT_TYPE = 'R' AND UPPER(owner||'.'||table_name)  IN (


      {% for node in graph.nodes.values()
         | selectattr("resource_type", "equalto", "model") %}
        {% if not node.name.startswith("META_") %}

            UPPER('{{node.config.schema}}.{{node.name}}'),

        {%- endif -%}
      {% endfor %}
      '');
    {% endif %}
{%- endmacro -%}