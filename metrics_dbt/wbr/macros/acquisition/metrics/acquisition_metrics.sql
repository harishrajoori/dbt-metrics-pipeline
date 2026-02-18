{%- macro acquisition_metrics() -%}
/* -- Script Name = acquisition_metrics.sql :: BEGIN -- */
SELECT DISTINCT year_month_day
         , product_pl
         , region
         , category
         , sub_category
         , metrics_unpivot.metric_name  AS metric_name
         , metrics_unpivot.metric_value AS metric_value
    FROM (select year_month_day,
                 product_pl,
                 region,
                 category,
                 sub_category,
                 total_clicks,
                 total_impressions,
                 total_installs,
                 total_visits,
                 incremental_new_customers,
                 incremental_gross_sales,
                 incremental_gross_sales_eur,
                 incremental_spend_eur,
                 IF(incremental_spend_eur > 0,
                    ((incremental_gross_sales_eur * 1.0000000) / (incremental_spend_eur * 1.0000000)),
                    0) as incremental_roas,
                 marketing_spend,
                 last_click_new_customers,
                 last_click_total_transactions,
                 last_click_transactions_tracked,
                 last_click_net_sales,
                 last_click_marketing_spend,
                 last_click_gross_sales,
                 IF(last_click_new_customers > 0 , ( last_click_marketing_spend / last_click_new_customers)) as lc_cost_per_acquisition,
                 IF(last_click_new_customers > 0 , ( marketing_spend / last_click_new_customers)) as cost_per_acquisition,
                 IF(total_visits > 0 , ( last_click_transactions_tracked / total_visits )) as conversion_rate
          from (
                   (SELECT mm.year_month_day,
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
                           product_pl,
                           region,
        /* ------------------------------------------------------------------------------------------------------- -- */
                           COALESCE(category, 'All')                    AS  category,
                           COALESCE(sub_category, 'All')                AS  sub_category,
                           SUM(total_clicks)                            AS  total_clicks,
                           SUM(total_impressions)                       AS  total_impressions,
                           SUM(total_installs)                          AS  total_installs,
                           SUM(total_visits)                            AS  total_visits,
                           SUM(incremental_new_customers)               AS  incremental_new_customers,
                           SUM(incremental_gross_sales_eur)             AS  incremental_gross_sales_eur,
                           SUM(incremental_gross_sales_gbp)             AS  incremental_gross_sales_gbp,
                           SUM(incremental_spend_eur)                   AS  incremental_spend_eur,
                           SUM(last_click_new_customers)                AS  last_click_new_customers,
                           SUM(last_click_total_transactions)           AS  last_click_total_transactions,
                           SUM(last_click_transactions_tracked)         AS  last_click_transactions_tracked,
                           IF((product_pl IS NULL OR product_pl = 'UK'),
                                SUM(incremental_gross_sales_gbp),
                                SUM(incremental_gross_sales_eur))       AS  incremental_gross_sales,
                           IF((product_pl IS NULL OR product_pl = 'UK'),
                                SUM(marketing_spend_gbp),
                                SUM(marketing_spend_eur))               AS  marketing_spend,
                           IF((product_pl IS NULL OR product_pl = 'UK'),
                                SUM(last_click_net_sales_gbp),
                                SUM(last_click_net_sales_eur))          AS  last_click_net_sales,
                           IF((product_pl IS NULL OR product_pl = 'UK'),
                                SUM(last_click_marketing_spend_gbp),
                                SUM(last_click_marketing_spend_eur))    AS  last_click_marketing_spend,
                           IF((product_pl IS NULL OR product_pl = 'UK'),
                                SUM(last_click_gross_sales_gbp),
                                SUM(last_click_gross_sales_eur))        AS  last_click_gross_sales
                    FROM (
                SELECT date (activity_date) AS year_month_day
                    /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
                    , rm.output_product_pl as product_pl
                    , rm.output_region as region
                    /* ------------------------------------------------------------------------------------------------------- -- */
        ,      CASE
               WHEN channel IN ('App Organic','Web Direct', 'Email','Other','Paid Display','Referral', 'Paid Other') THEN 'Organic Last Click'
               WHEN kpi NOT IN  ('Installs','New Customers','Clicks','Sales')
                    AND channel = 'Organic Search' THEN 'Organic Last Click'
               WHEN kpi IN ('Incremental Gross Sales EUR', 'Incremental Gross Sales GBP', 'Incremental Gross Sales',
                            'Incremental New Customers', 'Incremental Spend EUR') THEN 'Paid Incremental'

               WHEN kpi IN ('Spend', 'Spend GBP', 'Spend EUR', 'Impressions', 'Visits', 'Last Click New Customers',
                            'Last Click Total Transactions', 'Last Click Net Sales GBP','Last Click Net Sales EUR',
                            'Last Click Marketing Spend GBP','Last Click Marketing Spend EUR',
                            'Last Click Gross Sales GBP','Last Click Gross Sales EUR','Last Click Transactions Tracked'
                            ) THEN 'Paid Last Click'

               ELSE 'Other'
               END AS category

        ,      CASE
                /* -- As part of New Channel mapping, channel values changed in MM logic --------------------------------------- -- */
               WHEN kpi NOT IN ('Installs'  ,'New Customers','Clicks','Sales')
                    AND channel = 'Organic Search' THEN sub_channel
               WHEN channel = 'App Organic' THEN 'App - Organic'
               WHEN channel = 'Web Direct' THEN 'Web - Direct'
              WHEN channel IN ('Email','Other','Paid Display','Referral', 'Paid Other') THEN 'Other'
               WHEN channel IN ('Web - Paid Search','Web - Paid Social','App - Paid Search','App - Paid Social',
                                'Affiliates')
                    THEN channel

                /* ------------------------------------------------------------------------------------------------------- -- */

               WHEN ( lower(device) = 'app' OR lower(channel) = 'app')  and  (sub_channel IN ('Apple Search', 'Google', 'Google UAC')
                     OR channel_source IN ('apple_search', 'adwords'))
                          THEN 'Paid App Lower Funnel'
               WHEN (lower(device) = 'app' OR lower(channel) = 'app') and (coalesce(sub_channel, 'Unknown') NOT  IN ('Apple Search', 'Google', 'Google UAC')
                    AND coalesce(channel_source, 'Unknown') NOT IN ('apple_search', 'adwords'))
                          THEN 'Paid App Mid Funnel'
               WHEN kpi = 'Installs' and channel = 'Paid Search' THEN 'Paid App Lower Funnel'
               WHEN kpi = 'Installs' and channel in ('Display', 'Social', 'Paid Display','Paid Social')  THEN 'Paid App Mid Funnel'
               WHEN kpi<> 'Installs' AND channel = 'Paid Search'
                          THEN 'Web Lower Funnel'
               WHEN kpi<> 'Installs' AND channel IN ('Paid Display','Paid Social', 'Display','Social')
                          THEN 'Web Mid Funnel'
               WHEN channel = 'Affiliates'
                          THEN 'Other Paid'
                WHEN channel = 'Brand'
                          THEN 'Brand'
               ELSE 'Other'
               END sub_category

        ,      SUM( IF(kpi IN ('Spend'), value)) AS marketing_spend
        ,      SUM( IF(kpi IN ('Spend EUR'), value)) AS marketing_spend_eur
        ,      SUM( IF(kpi IN ('Spend GBP'), value)) AS marketing_spend_gbp
        ,      SUM( IF(kpi = 'Clicks', value)) AS total_clicks
        ,      SUM( IF(kpi = 'Impressions', value)) AS total_impressions
        ,      SUM( IF(kpi = 'Sales', value)) AS gross_sales
        ,      SUM( IF(kpi = 'New Customers', value)) AS new_customers
        ,      SUM( IF(kpi = 'Installs', value)) AS total_installs
        ,      SUM( IF(kpi = 'Visits', value)) total_visits
        ,      SUM( IF(kpi = 'Incremental New Customers', value)) AS incremental_new_customers
        ,      SUM( IF(kpi = 'Incremental Gross Sales EUR', value)) AS incremental_gross_sales_eur
        ,      SUM( IF(kpi = 'Incremental Gross Sales GBP', value)) AS incremental_gross_sales_gbp
        ,      SUM( IF(kpi = 'Incremental Spend EUR', value)) incremental_spend_eur
        ,      SUM( IF(kpi = 'Last Click New Customers', value)) last_click_new_customers
        ,      SUM( IF(kpi = 'Last Click Total Transactions', value)) last_click_total_transactions
        ,      SUM( IF(kpi = 'Last Click Net Sales GBP', value)) last_click_net_sales_gbp
        ,      SUM( IF(kpi = 'Last Click Net Sales EUR', value)) last_click_net_sales_eur
        ,      SUM( IF(kpi = 'Last Click Marketing Spend GBP', value)) last_click_marketing_spend_gbp
        ,      SUM( IF(kpi = 'Last Click Marketing Spend EUR', value)) last_click_marketing_spend_eur
        ,      SUM( IF(kpi = 'Last Click Gross Sales GBP', value)) last_click_gross_sales_gbp
        ,      SUM( IF(kpi = 'Last Click Gross Sales EUR', value)) last_click_gross_sales_eur
        ,      SUM( IF(kpi = 'Last Click Transactions Tracked', value)) last_click_transactions_tracked

                    FROM {{ source("bi_dwh", "marketing_mart") }} -- change to prod when pushed to master branch
                    /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
                    inner join 
                      {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
                      on (coalesce(pnl_segment,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
                    /* ------------------------------------------------------------------------------------------------------- -- */

                    WHERE date (activity_date) BETWEEN date ('{{ env_var("exe_start_date") }}')
                      AND date ('{{ env_var("exe_end_date") }}')
                      AND kpi IN ('Spend'
                        , 'Spend GBP'
                        , 'Spend EUR'
                        , 'Clicks'
                        , 'Impressions'
                        , 'New Customers'
                        , 'Sales'
                        , 'Installs'
                        , 'Visits'
                        , 'Incremental New Customers'
                        , 'Incremental Gross Sales EUR'
                        , 'Incremental Gross Sales GBP'
                        , 'Incremental Spend EUR'
                        , 'Last Click New Customers'
                        , 'Last Click Total Transactions'
                        , 'Last Click Net Sales GBP'
                        , 'Last Click Net Sales EUR'
                        , 'Last Click Marketing Spend GBP'
                        , 'Last Click Marketing Spend EUR'
                        , 'Last Click Gross Sales GBP'
                        , 'Last Click Gross Sales EUR'
                        , 'Last Click Transactions Tracked')
                      AND channel NOT IN ('TOC','Brand')
                    GROUP BY 1, 2, 3, 4, 5) mm
    GROUP BY
        CUBE -- generate all possible combinations of product_pl and region
        ( year_month_day,
          product_pl,
          region,
          category,
          sub_category
        )
                   )) )
    CROSS JOIN UNNEST(
            array['Marketing Spend', 'Total Clicks', 'Total Impressions', 'Total Installs',
            'Total Visits', 'Incremental New Customers', 'Incremental Gross Sales',
            'Incremental ROAS', 'Incremental Gross Sales EUR', 'Incremental Spend EUR','Last Click New Customers',
            'Last Click Total Transactions','Last Click Transactions Tracked','Last Click Net Sales',
            'Last Click Marketing Spend','Last Click Gross Sales', 'LC_CPA', 'CPA', 'CVR'
                ],
            array[marketing_spend, total_clicks, total_impressions, total_installs,
            total_visits, incremental_new_customers, incremental_gross_sales,  incremental_roas,
            incremental_gross_sales_eur, incremental_spend_eur, last_click_new_customers,
            last_click_total_transactions, last_click_transactions_tracked, last_click_net_sales,
            last_click_marketing_spend, last_click_gross_sales, lc_cost_per_acquisition, cost_per_acquisition, conversion_rate
                ]
               ) metrics_unpivot (metric_name, metric_value) WHERE metrics_unpivot.metric_name IS NOT NULL
AND   metrics_unpivot.metric_value > 0
/* -- Script Name = acquisition_metrics.sql :: END -- */
{%- endmacro -%}

