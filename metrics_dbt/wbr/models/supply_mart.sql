{% set exe_type = env_var("exe_type") %}

{% do exceptions.warn("exe_type Got: " ~ exe_type) %}
{% do exceptions.warn("date scope Got: " ~ env_var("exe_start_date")) %}
{% if exe_type == 'day' %}
    {{ supply_day() }}
{% elif exe_type == 'week' %}
    {{ supply_week() }}
{% elif exe_type == 'fytd' %}
    {{ supply_fytd() }}
{% else %}
    {{ exceptions.raise_compiler_error("Invalid exe_type provided: " ~ exe_type ) }}
{% endif %}