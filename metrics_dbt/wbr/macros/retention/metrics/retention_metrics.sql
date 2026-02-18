{%- macro retention_metrics() -%}
/* -- Script Name = retention_metrics.sql :: BEGIN -- */
{% set category_list = ['Volume', 'Sales GBP', 'Sales EUR', 'Retention', 'Churn'] %}
{% set sub_category_list = ['Early Life', 'Retained', 'Resurrected'] %}
{% set active_category_list = ['Volume', 'Sales GBP', 'Sales EUR', 'Churn'] %}

WITH metric_maps AS
(    
    SELECT
         date_scope
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        , rm.output_product_pl as product_pl
        , rm.output_region as region
        /* ------------------------------------------------------------------------------------------------------- -- */
        ,CASE upper('{{ env_var("exe_type") }}')
              WHEN 'WEEK' THEN date_add('day', -1, year_month_day)
         ELSE year_month_day END AS year_month_day
        ,array[
        row(CAST('Volume' AS VARCHAR),
            map(
               array['Early Life', 'Retained', 'Resurrected'],
              array[el_volume, ret_volume, res_volume]
             )
        ),
        row(CAST('Sales GBP' AS VARCHAR),
         map(
            array['Early Life', 'Retained', 'Resurrected'],
            array[el_nts_gbp, ret_nts_gbp, res_nts_gbp]
            )
        ),
        row('Sales EUR',
        map(
            array['Early Life', 'Retained', 'Resurrected'],
            array[el_nts_eur, ret_nts_eur, res_nts_eur]
            )
        ),
        row('Retention',
        map(
            array['Early Life', 'Retained', 'Resurrected'],
            array[el_retention, ret_retention, res_retention]
          )
        ),
        row('Churn',
        map(
            array['Early Life', 'Retained', 'Resurrected'],
            array[el_churned, ret_churned, res_churned]
            )
        )
        ] AS category_map
    FROM {{ source("bi_dwh_users", "growth_accounting_summary") }}
    /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
    inner join 
        {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
        on (coalesce(product_pl,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
    /* ------------------------------------------------------------------------------------------------------- -- */
    where date_scope=upper('{{ env_var("exe_type") }}')
    AND date_add('day', -1, year_month_day)
    BETWEEN CASE upper('{{ env_var("exe_type") }}')
              WHEN 'WEEK' THEN date_add('day', -7, date('{{ env_var("exe_start_date") }}') )
              WHEN 'DAY' THEN date_add('day', -1, date('{{ env_var("exe_start_date") }}') )
              END
    AND date('{{ env_var("exe_end_date") }}')
)
, retention_pivoted AS
(
    SELECT
        date_scope,
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        product_pl,
        region,
        /* ------------------------------------------------------------------------------------------------------- -- */
        year_month_day,
        category,
        sub_category,
        metric_value
    FROM metric_maps
    CROSS JOIN UNNEST(category_map) AS t (category, category_data)
    CROSS JOIN UNNEST(category_data) AS t1 (sub_category, metric_value)
)
, retention_cubed AS
(
    {% for category in category_list %}
            {% if not loop.first %}
                UNION ALL
            {% endif %}
        {% for sub_category in sub_category_list %}
            {% if not loop.first %}
                UNION ALL
            {% endif %}
            select year_month_day,
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            product_pl,
            region,
            /* ------------------------------------------------------------------------------------------------------- -- */
                '{{ category }}' AS category,
                '{{ sub_category }}' AS sub_category,
                sum(ret.metric_value) AS metric_value
            from retention_pivoted ret
            where category='{{ category }}'
            and sub_category='{{ sub_category }}'
            group by CUBE
                        (
                            ret.year_month_day,
                            ret.product_pl,
                            ret.region
                        )
        {% endfor %}
    {% endfor %}
        {% for active_category in active_category_list %}
                UNION ALL
        select year_month_day,
                /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
                product_pl,
                region,
                /* ------------------------------------------------------------------------------------------------------- -- */
                '{{ active_category }}' AS category,
                'Active' AS sub_category,
                sum(ret.metric_value) AS metric_value
            from retention_pivoted ret
            where category='{{ active_category }}'
            and sub_category in ('Early Life', 'Retained', 'Resurrected')
            group by CUBE
                        (
                            ret.year_month_day,
                            ret.product_pl,
                            ret.region
                        )
        {% endfor %}
)
select *
from   retention_cubed
/* -- Script Name = retention_metrics.sql :: END -- */
{%- endmacro -%}