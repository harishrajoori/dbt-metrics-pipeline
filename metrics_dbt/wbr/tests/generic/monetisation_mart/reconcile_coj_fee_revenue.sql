{% test reconcile_coj_fee_revenue(model) %}

with coj_fee_revenue as (
    SELECT
        DATE(year_month_day) AS year_month_day
        , product_pl_code AS product_pl
        , CASE
            WHEN (product_pl_code = 'EU' AND order_region_name = 'United Kingdom') THEN 'UK>EU'
            WHEN (product_pl_code = 'EU' AND order_region_name = 'Unknown') THEN 'France'
            WHEN (product_pl_code = 'UK') THEN 'United Kingdom'
            ELSE order_region_name
        END AS region
        , m_revenue_coj_admin_fee_eur AS coj_fee_revenue_eur
        , m_revenue_coj_admin_fee_gbp AS coj_fee_revenue_gbp
    FROM {{ source("bi_dwh", "fm_products") }}
    WHERE
        DATE(year_month_day) BETWEEN DATE('{{ env_var("exe_start_date") }}') AND DATE('{{ env_var("exe_end_date") }}')
        AND order_business_channel_code = '{{ var("monetisation_mart")["business_channel"] }}'
        AND order_managed_group_id IN {{ var("monetisation_mart")["managed_group_id"] }} -- include transactions made for both MyCompany as well as PartnerCompany
        AND UPPER(product_type_code) IN {{ var("monetisation_mart")["product_type_code"] }}
        AND source_system IN {{ var("fm_products")["source_system"] }}
)

, total_coj_fee_revenue as (
    select
        year_month_day
        , product_pl
        , region
        , ROUND(IF(product_pl = 'UK' OR product_pl IS NULL, SUM(coj_fee_revenue_gbp), SUM(coj_fee_revenue_eur)), 4) AS metric_value
    from coj_fee_revenue
    group by year_month_day, product_pl, region
)

, monetisation_mart_coj_fee_revenue as (
    select
        year_month_day
        , product_pl
        , region
        , category
        , sub_category
        , metric_name
        , metric_value
    from {{ model }}
    where category = 'Trx'
    and sub_category = 'COJ Fee'
    and metric_name = 'Revenue'
    and date_scope = 'DAY'
    and year_month_day BETWEEN DATE('{{ env_var("exe_start_date") }}') AND DATE('{{ env_var("exe_end_date") }}')
)

, compare_cte AS (
    SELECT
        mm.year_month_day
        , mm.product_pl
        , mm.region
        , category
        , sub_category
        , metric_name
        , mm.metric_value as mm_metric_value
        , fmp.metric_value as fmp_metric_value
        , ABS(fmp.metric_value - mm.metric_value) AS difference
    FROM total_coj_fee_revenue fmp
    INNER JOIN monetisation_mart_coj_fee_revenue mm
    ON fmp.year_month_day = mm.year_month_day
    AND fmp.product_pl = mm.product_pl
    AND fmp.region = mm.region
)

SELECT *
FROM compare_cte
WHERE difference > 0.001

{% endtest %}