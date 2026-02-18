{%- macro monetisation_metrics() -%}
/* -- Script Name = monetisation_metrics.sql :: BEGIN -- */
    {% set macros_list = [
        non_fee_revenue_per_visit,
        total_visits,
        ads_metrics,
        partnership_booking_dot_com_bookings,
        partnership_booking_dot_com_revenue,
        partnership_booking_dot_com_ga_metrics, 
        transaction_metrics, 
        wbr_metrics 
    ] %}

    {% for macro in macros_list %}
        {% if not loop.first %}
            UNION
        {% endif %}
        {{ macro() }}
    {% endfor %}
/* -- Script Name = monetisation_metrics.sql :: END -- */
{%- endmacro -%}