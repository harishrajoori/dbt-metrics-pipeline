{%- macro payback_months() -%}
/* -- Script Name = payback_months.sql :: BEGIN -- */
WITH
    payback_data as
    (
        SELECT
            activity_date
            , region
            , category
            , sub_category
            , m1_multiplier
            , m2_m3_multiplier
            , m4_m6_multiplier
            , m7_m12_multiplier
            , m13_m24_multiplier
            , m25_36_multiplier
            , m37_48_multiplier
            , m49_60_multiplier
            , m61_72_multiplier
            , m73_84_multiplier
            , m85_96_multiplier
            , m97_108_multiplier
            , m109_120_multiplier
            , sum(marketing_spend_gbp) marketing_spend_gbp
            , sum(marketing_spend_eur) marketing_spend_eur
            , sum(new_customer_count) new_customer_count
            , sum(total_first_trx_gm_gbp) total_first_trx_gm_gbp
            , sum(total_first_trx_gm_eur) total_first_trx_gm_eur
        FROM
        (
            /* -- data extract for payback web; comes from "marketing_payback" -- */
            select
                activity_date
                , region
                , channel_0
                , channel_1
                , channel_2
                , CASE
                    WHEN channel_0 = 'Organic Search' THEN 'Organic Last Click'
                    WHEN channel_0 IN ('App Organic','Web Direct', 'Email','Other','Paid Display','Referral', 'Paid Other') THEN 'Organic Last Click'
                    ELSE 'Paid Last Click'
                END AS category
                , CASE
                    WHEN channel_0 = 'App Organic' THEN 'App - Organic'
                    WHEN channel_0 = 'Web Direct' THEN 'Web - Direct'
                    WHEN channel_0 = 'Organic Search' THEN channel_1
                    WHEN channel_0 IN ('Web - Paid Search','Web - Paid Social','App - Paid Search','App - Paid Social',
                                  'Affiliates')
                    THEN channel_0
                    WHEN channel_0 IN ('Email','Other','Paid Display','Referral', 'Paid Other') THEN 'Other'
                    ELSE 'Others'
                END AS sub_category
                , m1_multiplier
                , m2_m3_multiplier
                , m4_m6_multiplier
                , m7_m12_multiplier
                , m13_m24_multiplier
                , m25_36_multiplier
                , m37_48_multiplier
                , m49_60_multiplier
                , m61_72_multiplier
                , m73_84_multiplier
                , m85_96_multiplier
                , m97_108_multiplier
                , m109_120_multiplier
                , marketing_spend_gbp
                , marketing_spend_eur
                , new_customer_count
                , total_first_trx_gm_gbp
                , total_first_trx_gm_eur
            from
                bi_dwh.marketing_payback p
            WHERE date (activity_date) BETWEEN date ('{{ env_var("exe_start_date") }}')
                                                AND date ('{{ env_var("exe_end_date") }}')
                AND p.original_attribution = false
                AND p.multiplier_level = 'Campaign'
        )
        GROUP BY
            1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17
    ),
    payback_aggregated AS
    (
        SELECT
            activity_date AS year_month_day
            , case
                when region = 'United Kingdom' then 'UK'
                else 'EU'
            end as product_pl
            , region
            , category
            , sub_category
            ,SUM(COALESCE(new_customer_count, 0)) new_customer_count
            ,SUM(marketing_spend_gbp) marketing_spend_gbp
            ,SUM(COALESCE(marketing_spend_gbp, 0)) / NULLIF(SUM(COALESCE(new_customer_count, 0)), 0) AS cpa
            -- GM per user for each month range
            ,SUM(total_first_trx_gm_gbp * m1_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m1
            ,SUM(total_first_trx_gm_gbp * m2_m3_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m2_3
            ,SUM(total_first_trx_gm_gbp * m4_m6_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m4_6
            ,SUM(total_first_trx_gm_gbp * m7_m12_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m7_12
            ,SUM(total_first_trx_gm_gbp * m13_m24_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m13_24
            ,SUM(total_first_trx_gm_gbp * m25_36_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m25_36
            ,SUM(total_first_trx_gm_gbp * m37_48_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m37_48
            ,SUM(total_first_trx_gm_gbp * m49_60_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m49_60
            ,SUM(total_first_trx_gm_gbp * m61_72_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m61_72
            ,SUM(total_first_trx_gm_gbp * m73_84_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m73_84
            ,SUM(total_first_trx_gm_gbp * m85_96_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m85_96
            ,SUM(total_first_trx_gm_gbp * m97_108_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m97_108
            ,SUM(total_first_trx_gm_gbp * m109_120_multiplier) / NULLIF(SUM(new_customer_count), 0) AS gm_m109_120
        FROM
            payback_data
        group by
            activity_date
            , region
            , category
            , sub_category
    ),
    payback_months AS 
    (
        SELECT
            year_month_day
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            , rm.output_product_pl as product_pl
            , rm.output_region as region
            /* ------------------------------------------------------------------------------------------------------- -- */
            , category
            , sub_category
            , new_customer_count
            , marketing_spend_gbp
            , cpa
            , gm_m1
            , gm_m2_3
            , gm_m4_6
            , gm_m7_12
            , gm_m13_24
            , gm_m25_36
            , gm_m37_48
            , gm_m49_60
            , gm_m61_72
            , gm_m73_84
            , gm_m85_96
            , gm_m97_108
            , gm_m109_120
            , CASE
                WHEN gm_m1 > cpa THEN 1

                WHEN gm_m1 + (gm_m2_3 * 2) > cpa THEN
                    1 + ((cpa - gm_m1) / gm_m2_3)

                WHEN gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) > cpa THEN
                    3 + ((cpa - (gm_m1 + (gm_m2_3 * 2))) / gm_m4_6)

                WHEN gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) > cpa THEN
                    6 + ((cpa - (gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3))) / gm_m7_12)

                WHEN gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) > cpa THEN
                    12 + ((cpa - (gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6))) / gm_m13_24)

                WHEN gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) > cpa THEN
                    24 + ((cpa - (gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12))) / gm_m25_36)

                WHEN gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) > cpa THEN
                    36 + ((cpa - (gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12))) / gm_m37_48)

                WHEN gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) + (gm_m49_60 * 12) > cpa THEN
                    48 + ((cpa - (gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12))) / gm_m49_60)

                WHEN gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) + (gm_m49_60 * 12) + (gm_m61_72 * 12) > cpa THEN
                    60 + ((cpa - (gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) + (gm_m49_60 * 12))) / gm_m61_72)

                WHEN gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) + (gm_m49_60 * 12) + (gm_m61_72 * 12) + (gm_m73_84 * 12) > cpa THEN
                    72 + ((cpa - (gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) + (gm_m49_60 * 12) + (gm_m61_72 * 12))) / gm_m73_84)

                WHEN gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) + (gm_m49_60 * 12) + (gm_m61_72 * 12) + (gm_m73_84 * 12) + (gm_m85_96 * 12) > cpa THEN
                    84 + ((cpa - (gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) + (gm_m49_60 * 12) + (gm_m61_72 * 12) + (gm_m73_84 * 12))) / gm_m85_96)

                WHEN gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) + (gm_m49_60 * 12) + (gm_m61_72 * 12) + (gm_m73_84 * 12) + (gm_m85_96 * 12) + (gm_m97_108 * 12) > cpa THEN
                    96 + ((cpa - (gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) + (gm_m49_60 * 12) + (gm_m61_72 * 12) + (gm_m73_84 * 12) + (gm_m85_96 * 12))) / gm_m97_108)

                ELSE
                    108 + ((cpa - (gm_m1 + (gm_m2_3 * 2) + (gm_m4_6 * 3) + (gm_m7_12 * 6) + (gm_m13_24 * 12) + (gm_m25_36 * 12) + (gm_m37_48 * 12) + (gm_m49_60 * 12) + (gm_m61_72 * 12) + (gm_m73_84 * 12) + (gm_m85_96 * 12) + (gm_m97_108 * 12)))) / gm_m109_120
            END AS payback_months
        FROM
            payback_aggregated
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        inner join
            my_company_data.prod_data_metrics_layer.product_pl_region_map rm
            on (coalesce(product_pl,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
        /* ------------------------------------------------------------------------------------------------------- -- */
    ),
    payback_final AS 
    (
        SELECT distinct
            year_month_day
            , product_pl
            , region
            , COALESCE(category, 'All') AS category
            , COALESCE(sub_category, 'All') AS sub_category
            , 'Payback Months' as metric_name
            , sum(payback_months) as metric_value
        from
            payback_months
        GROUP BY 
        CUBE 
        (
            year_month_day,
            product_pl,
            region,
            category,
            sub_category
        )
    )
SELECT 
    *
FROM 
    payback_final
WHERE 
    product_pl IS NOT NULL 
    AND region IS NOT NULL 
    AND category IS NOT NULL 
    AND sub_category IS NOT NULL 
    AND metric_value IS NOT NULL
    AND year_month_day IS NOT NULL
    AND metric_value > 0
/* -- Script Name = payback_months.sql :: END -- */
{%- endmacro -%}