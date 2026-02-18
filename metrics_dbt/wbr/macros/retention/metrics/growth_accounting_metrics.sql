{%- macro growth_accounting_metrics() -%}
/* -- Script Name = growth_accounting_metrics.sql :: BEGIN -- */
{% set category_list = ['Volume', 'Net Sales Amount', 'Retention', 'Churn'] %}
{% set sub_category_list = ['Early Life', 'Retained', 'Resurrected'] %}
{% set active_category_list = ['Volume', 'Net Sales Amount', 'Churn'] %}
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
WITH 
    growth_acct_data as
    (
/* ------------------------------------------------------------------------------------------------------- -- */
        SELECT
            ret.date_scope
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            , product_pl
            , region
            /* ------------------------------------------------------------------------------------------------------- -- */
            ,ret.year_month_day
            ,category
            ,sub_category
            ,ROUND(
                CASE
                    -- Volume Metrics
                    WHEN category = 'Volume' AND sub_category = 'Early Life' THEN SUM(el_volume)
                    WHEN category = 'Volume' AND sub_category = 'Retained' THEN SUM(ret_volume)
                    WHEN category = 'Volume' AND sub_category = 'Resurrected' THEN SUM(res_volume)
                    WHEN category = 'Volume' AND sub_category = 'Active' THEN SUM(el_volume) + SUM(ret_volume) + SUM(res_volume)

                    -- Net Sales Amount Metrics
                    WHEN category = 'Net Sales Amount' AND sub_category = 'Early Life' THEN SUM(el_nts_amount)
                    WHEN category = 'Net Sales Amount' AND sub_category = 'Retained' THEN SUM(ret_nts_amount)
                    WHEN category = 'Net Sales Amount' AND sub_category = 'Resurrected' THEN SUM(res_nts_amount)
                    WHEN category = 'Net Sales Amount' AND sub_category = 'Active' THEN SUM(el_nts_amount + ret_nts_amount + res_nts_amount)

                    -- Retention Metrics
                    WHEN category = 'Retention' AND sub_category = 'Early Life' THEN SUM(el_retention)
                    WHEN category = 'Retention' AND sub_category = 'Retained' THEN SUM(ret_retention)
                    WHEN category = 'Retention' AND sub_category = 'Resurrected' THEN SUM(res_retention)

                    -- Churned Metrics
                    WHEN category = 'Churn' AND sub_category = 'Early Life' THEN SUM(el_churned)
                    WHEN category = 'Churn' AND sub_category = 'Retained' THEN SUM(ret_churned)
                    WHEN category = 'Churn' AND sub_category = 'Resurrected' THEN SUM(res_churned)
                    WHEN category = 'Churn' AND sub_category = 'Active' THEN SUM(el_churned) + SUM(ret_churned) + SUM(res_churned)

                END, 4) AS metric_value
        FROM
        (    SELECT
                date_scope
                /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
                , rm.output_product_pl as product_pl
                , rm.output_region as region
                /* ------------------------------------------------------------------------------------------------------- -- */
                ,CASE upper('{{ env_var("exe_type") }}')
                    WHEN 'WEEK' THEN date_add('day', -1, year_month_day)
                    ELSE year_month_day
                END AS year_month_day
                --Early Life--
                ,el_volume
                ,IF((product_pl = 'UK' OR product_pl IS NULL), el_nts_gbp, el_nts_eur) AS el_nts_amount
                ,el_retention
                ,el_churned
                --Retained--
                ,ret_volume
                ,IF((product_pl = 'UK' OR product_pl IS NULL), ret_nts_gbp, ret_nts_eur) AS ret_nts_amount
                ,ret_retention
                ,ret_churned
                --Resurrected--
                ,res_volume
                ,IF((product_pl = 'UK' OR product_pl IS NULL), res_nts_gbp, res_nts_eur) AS res_nts_amount
                ,res_retention
                ,res_churned
            FROM {{ source("bi_dwh_users", "growth_accounting_summary") }}
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            inner join 
                {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
                on (coalesce(product_pl,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
            /* ------------------------------------------------------------------------------------------------------- -- */
            where date_scope=upper('{{ env_var("exe_type") }}')
            AND date_add('day', -1, year_month_day)
            BETWEEN CASE upper('{{ env_var("exe_type") }}')
            --we want to take previous week data also to compare previous metric value
            --date_add is done twice since exe_start_date and exe_end_date coming as same date instead of beginning and end of week
                    WHEN 'WEEK' THEN date_add('day', -7, date('{{ env_var("exe_start_date") }}'))
                    WHEN 'DAY' THEN date_add('day', -1, date('{{ env_var("exe_start_date") }}') )
                    END
            AND date('{{ env_var("exe_end_date") }}')
        ) ret
        CROSS JOIN UNNEST(
                ARRAY[
                    ROW('Volume', 'Early Life'),
                    ROW('Volume', 'Retained'),
                    ROW('Volume', 'Resurrected'),
                    ROW('Volume', 'Active'),
                    ROW('Net Sales Amount', 'Early Life'),
                    ROW('Net Sales Amount', 'Retained'),
                    ROW('Net Sales Amount', 'Resurrected'),
                    ROW('Net Sales Amount', 'Active'),
                    ROW('Retention', 'Early Life'),
                    ROW('Retention', 'Retained'),
                    ROW('Retention', 'Resurrected'),
                    ROW('Churn', 'Early Life'),
                    ROW('Churn', 'Retained'),
                    ROW('Churn', 'Resurrected'),
                    ROW('Churn', 'Active')
                ]
            ) AS t(category, sub_category)
        GROUP BY CUBE(date_scope, year_month_day, product_pl, region, category, sub_category)
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
    )
select
    *
from 
    growth_acct_data
where 
    date_scope is not null 
    and product_pl is not null 
    and region is not null
    and year_month_day is not null
    and category is not null 
    and sub_category is not null
    and metric_value is not null
/* ------------------------------------------------------------------------------------------------------- -- */
/* -- Script Name = growth_accounting_metrics.sql :: END -- */
{%- endmacro -%}