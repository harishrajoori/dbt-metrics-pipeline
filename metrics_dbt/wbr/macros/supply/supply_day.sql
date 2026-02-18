-- UPDATED ON 24-Oct-2024

-- DELETE FROM "my_company_data"."dev_data_metrics_layer"."supply_mart" WHERE date_scope = 'DAY';

{%- macro supply_day() -%}
/* -- Script Name = supply_day.sql :: BEGIN -- */
WITH
    /* ---
    below CTE is to extract data from "fm_products" for DAY scope (range = current_date - 1),
    focussing on only the requisite attributes that are needed for LTV Segment = Supply
    --- */
    fm_products_raw_extract AS
    (
        SELECT
            date(year_month_day) AS year_month_day,
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            rm.output_product_pl as product_pl,
            rm.output_region as region,
            /* ------------------------------------------------------------------------------------------------------- -- */
            /* -- bringing in both currency values to allow for GBP projection at UK & EU aggregation level (region = Total) -- */
            m_gross_sales_amount_eur AS gross_sales_eur,
            m_gross_sales_amount_gbp AS gross_sales_gbp,
            m_net_sales_amount_eur AS net_sales_eur,
            m_net_sales_amount_gbp AS net_sales_gbp,
            m_refunded_amount_eur AS total_refunds_eur,
            m_refunded_amount_gbp AS total_refunds_gbp
        FROM
            {{ source("bi_dwh", "fm_products") }}
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        inner join 
            {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
            on (coalesce(product_pl_code,'(null)') = rm.input_product_pl and coalesce(order_region_name, '(null)') = rm.input_region)
        /* ------------------------------------------------------------------------------------------------------- -- */
        WHERE
            date(year_month_day) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND
            order_business_channel_code = '{{ var("supply_mart")["business_channel"] }}'
            AND
            order_managed_group_id IN {{ var("supply_mart")["managed_group_id"] }}
            AND
            UPPER(product_type_code) IN {{ var("supply_mart")["product_type_code"] }}
            AND
            source_system IN {{ var("fm_products")["source_system"] }}
    ),
    /* ---
    below CTE is to aggregate the data from "fm_products" basis of "product_pl" and "region",
    thereby generating all possible combinations of "product_pl" and "region"
    --- */
    fm_products_aggregated AS
    (
        SELECT
            year_month_day AS year_month_day,
			/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
			product_pl,
			region,
			/* ------------------------------------------------------------------------------------------------------- -- */
            'All' AS category,
            'All' AS sub_category,
            /* -- GBP metric values for United Kingdom and Total regions only, and EUR metric values for all other regions -- */
            IF((product_pl IS NULL OR product_pl = 'UK'), SUM(gross_sales_gbp), SUM(gross_sales_eur)) AS gross_sales,
            IF((product_pl IS NULL OR product_pl = 'UK'), SUM(net_sales_gbp), SUM(net_sales_eur)) AS net_sales,
            IF((product_pl IS NULL OR product_pl = 'UK'), SUM(total_refunds_gbp), SUM(total_refunds_eur)) AS total_refunds
        FROM
            fm_products_raw_extract
        GROUP BY
            CUBE -- generate all possible combinations of product_pl and region
            (
                year_month_day,
                product_pl,
                region
            )
    ),
    /* ---
    below CTE is to extract data from "journey_search_summary" for DAY scope (range = current_date - 1),
    focussing on only the requisite attributes that are needed for LTV Segment = Supply
    --- */
    journey_search_summary_raw_extract AS
    (
        SELECT 
            date(jrn.year_month_day) AS year_month_day,
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            rm.output_product_pl as product_pl,
            rm.output_region as region,
            /* ------------------------------------------------------------------------------------------------------- -- */
            COALESCE(jrn.m_search_result_journey_count,0) AS total_journeys,
            jrn.m_search_result_unsellable_journey_count AS unsellable_journeys
        FROM
            {{ source("bi_dwh", "journey_search_summary") }} jrn
        INNER JOIN
            {{ source("data_metrics_layer", "country_codes_lookup") }} ccd
            ON (split(jrn.search_odpair_country_name,' - ')[1] = ccd.country_code)
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        inner join 
            {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
            on (coalesce(ccd.product_pl,'(null)') = rm.input_product_pl and coalesce(ccd.region, '(null)') = rm.input_region)
        /* ------------------------------------------------------------------------------------------------------- -- */
        WHERE
            date(jrn.year_month_day) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND
            (
                jrn.search_managed_group_id IN ('20', '42')
                AND
                lower(jrn.search_result_transport_mode) LIKE '%train%'
            )
    ),
    /* ---
    below CTE is to aggregate the data from "journey_search_summary" basis of "product_pl" and "region",
    thereby generating all possible combinations of "product_pl" and "region"
    --- */
    journey_search_summary_aggregated AS
    (
        SELECT
            year_month_day AS year_month_day,
			/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
			product_pl,
			region,
			/* ------------------------------------------------------------------------------------------------------- -- */
            'All' AS category,
            'All' AS sub_category,
            /* -- GBP metric values for United Kingdom and Total regions only, and EUR metric values for all other regions -- */
            SUM(total_journeys) AS total_journeys,
            SUM(unsellable_journeys) AS unsellable_journeys
        FROM
            journey_search_summary_raw_extract
        GROUP BY
            CUBE -- generate all possible combinations of product_pl and region
            (
                year_month_day,
                product_pl,
                region
            )
    ),
/* ---
deriving metrics for LTV Segment = Supply from CTE tables generated above,
joining with calendar data to add date timeline attributes "financial_year" and "week_number"
--- */
    sup_day as 
    (
        SELECT
            'DAY' AS date_scope,
            calendar.financial_year AS financial_year,
            calendar.week_number AS week_number,
            supply.year_month_day AS year_month_day,
            CAST(current_time AS timestamp) AS last_modified,
            calendar.week_commencing_date AS week_commencing_date,
            supply.product_pl AS product_pl,
            supply.region AS region,
            supply.category AS category,
            supply.sub_category AS sub_category,
            supply.metric_name AS metric_name,
            supply.metric_value AS metric_value
        FROM
        (
            SELECT
                year_month_day
                , product_pl
                , region
                , category
                , sub_category
                , metric_name
                , ROUND(
                    CASE
                        WHEN metric_name = 'WBR Gross Sales' THEN gross_sales
                        WHEN metric_name = 'WBR Net Sales' THEN net_sales
                        WHEN metric_name = 'Total Refunds' THEN total_refunds
                        WHEN metric_name = 'Refunds Ratio' THEN IF(gross_sales > 0, ((total_refunds*1.0000000)/(gross_sales*1.0000000)), 0)
                    END, 4) AS metric_value
            FROM
                fm_products_aggregated
            CROSS JOIN UNNEST(
                    ARRAY[
                        ROW('WBR Gross Sales'),
                        ROW('WBR Net Sales'),
                        ROW('Total Refunds'),
                        ROW('Refunds Ratio')
                    ]
                ) AS t(metric_name)

            UNION ALL

            SELECT
                year_month_day
                , product_pl
                , region
                , category
                , sub_category
                , metric_name
                , ROUND(
                    CASE
                        WHEN metric_name = 'Total Journeys' THEN total_journeys
                        WHEN metric_name = 'Unsellable Journeys' THEN unsellable_journeys
                        WHEN metric_name = 'Unsellable Journey Ratio' THEN IF(total_journeys > 0, ((unsellable_journeys*1.0000000)/(total_journeys*1.0000000)), 0)
                    END, 4) AS metric_value
            FROM
                journey_search_summary_aggregated
            CROSS JOIN UNNEST(
                    ARRAY[
                        ROW('Total Journeys'),
                        ROW('Unsellable Journeys'),
                        ROW('Unsellable Journey Ratio')
                    ]
                ) AS t(metric_name)
        ) supply
        INNER JOIN
            {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
            ON (date(supply.year_month_day) = date(calendar.year_month_day) AND calendar.date_scope = 'DAY')
    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    sup_day 
where 
/* -- filtering out unrequired records -- */
(
  financial_year is not null 
  and 
  week_number is not null 
  and 
  year_month_day is not null
  and 
  week_commencing_date is not null 
  and
  product_pl is not null
  and 
  region is not null 
  and 
  category is not null
  and 
  sub_category is not null
  and 
  metric_name is not null
  and 
  metric_value is not null
)
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
/* -- Script Name = supply_day.sql :: END -- */
{%- endmacro -%}
