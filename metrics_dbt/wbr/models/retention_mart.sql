{% set exe_type = env_var("exe_type") %}

{% do exceptions.warn("exe_type Got: " ~ exe_type) %}
{% do exceptions.warn("date scope Got: " ~ env_var("exe_start_date")) %}
{% if exe_type == 'day' %}
    {{ retention_day() }}
{% elif exe_type == 'week' %}
    {{ retention_week() }}
{% elif exe_type == 'fytd' %}
    {{ retention_fytd() }}
{% else %}
    {{ exceptions.raise_compiler_error("Invalid exe_type provided: " ~ exe_type ) }}
{% endif %}