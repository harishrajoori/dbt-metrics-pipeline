-- UPDATED ON 18-Sep-2024 || DQ VERIFIED || CODE REVIEWED

-- DELETE FROM "my_company_data"."stg_wbr_mart"."conversion_mart" WHERE date_scope = 'DAY';

{%- macro conversion_day() -%}
/* -- Script Name = conversion_day.sql :: BEGIN -- */
WITH
    /* ---
    below CTE is to extract data from "fm_products" for DAY scope (range = current_date - 1),
    focussing on only the requisite attributes that are needed for LTV Segment = Conversion
    --- */
    fm_products_raw_extract AS
    (
        SELECT
            date(year_month_day) AS year_month_day,
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            rm.output_product_pl as product_pl,
            rm.output_region as region,
            /* ------------------------------------------------------------------------------------------------------- -- */
            'Journey Type' AS category,
            coalesce(case
            	when product_pl_code = 'UK' then fare_train_classification_name_longest_duration
            	when order_region_name = 'UK' then fare_train_classification_name_longest_duration
            	else product_train_speed_code
           	end, 'unknown') AS sub_category,
            order_id AS transaction_order_id,
            /* -- bringing in both currency values to allow for GBP projection at UK & EU aggregation level (region = Total) -- */
            m_gross_sales_amount_eur AS gross_sales_eur,
            m_gross_sales_amount_gbp AS gross_sales_gbp
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
            order_business_channel_code = '{{ var("conversion_mart")["business_channel"] }}'
            AND
            order_managed_group_id IN {{ var("conversion_mart")["managed_group_id"] }} -- include transactions made for both MyCompany as well as PartnerCompany
            AND
            UPPER(product_type_code) IN {{ var("conversion_mart")["product_type_code"] }}
            AND
            source_system IN {{ var("fm_products")["source_system"] }}
            AND
            product_gross_sales_flag = 'Y' -- as suggested by Brandon B in discussion with Toby V
            AND
            record_type = 'SALES' -- as suggested by Brandon B post data review
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
            COALESCE(category, 'All') AS category,
            COALESCE(sub_category, 'All') AS sub_category,
            COUNT(DISTINCT transaction_order_id) AS gross_transactions,
            /* -- GBP metric values for United Kingdom and Total regions only, and EUR metric values for all other regions -- */
            IF((product_pl IS NULL OR product_pl = 'UK'), SUM(gross_sales_gbp), SUM(gross_sales_eur)) AS gross_sales
        FROM
            fm_products_raw_extract
        GROUP BY
            CUBE -- generate all possible combinations of product_pl and region
            (
                year_month_day,
                product_pl,
                region,
                category,
                sub_category
            )
    ),
    /* ---
    below CTE is to extract data from "marketing_mart" DAY scope (range = current_date - 1),
    focussing on only the requisite attributes that are needed for LTV Segment = Conversion
    --- */
    marketing_mart_raw_extract AS
    (
        SELECT
            date(activity_date) AS year_month_day,
            /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
            rm.output_product_pl as product_pl,
            rm.output_region as region,
            /* ------------------------------------------------------------------------------------------------------- -- */
            /* -- will be extended going forward, as per future business case requirements -- */
            'Platform' AS category,
            platform AS sub_category,
            IF(kpi = 'Visits', value) AS total_visits,
            IF(kpi = 'Transactions Tracked', value) AS transactions_tracked
        FROM
            {{ source("bi_dwh", "marketing_mart") }}
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        inner join 
            {{ source("data_metrics_layer", "product_pl_region_map") }} rm 
            on (coalesce(pnl_segment,'(null)') = rm.input_product_pl and coalesce(region, '(null)') = rm.input_region)
        /* ------------------------------------------------------------------------------------------------------- -- */
        WHERE
            date(activity_date) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
            AND
            (
                kpi IN ('Visits', 'Transactions Tracked')
            )
        AND platform IS NOT NULL
    ),
    /* ---
    below CTE is to aggregate the data from "marketing_mart" basis of "product_pl" and "region",
    thereby generating all possible combinations of "product_pl" and "region"
    --- */
    marketing_mart_aggregated AS
    (
        SELECT
            year_month_day,
			/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
			product_pl,
			region,
			/* ------------------------------------------------------------------------------------------------------- -- */
            COALESCE(category, 'All') AS category,
            COALESCE(sub_category, 'All') AS sub_category,
            SUM(total_visits) AS total_visits,
            SUM(transactions_tracked) AS transactions_tracked
        FROM
            marketing_mart_raw_extract
        GROUP BY
            CUBE -- generate all possible combinations of product_pl and region
            (
                year_month_day,
                product_pl,
                region,
                category,
                sub_category
            )
    )

,
fm_agg
AS
(
SELECT distinct year_month_day, product_pl, region, category, sub_category, gross_transactions, gross_sales
, IF(gross_transactions > 0, ((gross_sales*1.0000000)/(gross_transactions*1.0000000)), 0) AS avg_trans_value
FROM   fm_products_aggregated
),
mm_agg AS
(
select distinct year_month_day, product_pl, region, category, sub_category, total_visits, transactions_tracked,
     IF(total_visits > 0, ((transactions_tracked*1.0000000)/(total_visits*1.0000000)), 0) conversion_ratio
FROM  marketing_mart_aggregated
)


/* ---
deriving metrics for LTV Segment = Conversion from CTE tables generated above,
joining with calendar data to add date timeline attributes "financial_year" and "week_number"
--- */
,
cnv_day
AS
(
    SELECT DISTINCT 
        'DAY' AS date_scope,
        calendar.financial_year AS financial_year,
        calendar.week_number AS week_number,
        conversion.year_month_day AS year_month_day,
        CAST(current_time AS timestamp) AS last_modified,
        calendar.week_commencing_date AS week_commencing_date,
        conversion.product_pl AS product_pl,
        conversion.region AS region,
        conversion.category AS category,
        conversion.sub_category AS sub_category,
        conversion.metric_name AS metric_name,
        conversion.metric_value AS metric_value
    FROM
    (
        SELECT distinct t1.year_month_day, t1.product_pl, t1.region,
                t1.category,
                t1.sub_category, t2.metric_name, t2.metric_value
        FROM fm_agg t1
        CROSS JOIN unnest (
        array['WBR Gross Transactions', 'Gross Sales', 'Avg Trans Value'],
        array[gross_transactions, gross_sales, avg_trans_value]
        ) t2 (metric_name, metric_value)
        union all
        SELECT distinct t1.year_month_day, t1.product_pl, t1.region,
                t1.category,
                t1.sub_category, t2.metric_name, t2.metric_value
        FROM mm_agg t1
        CROSS JOIN unnest (
        array['Total Visits', 'Transactions Tracked', 'Conversion Ratio'],
        array[total_visits, transactions_tracked, conversion_ratio]
        ) t2 (metric_name, metric_value)
    ) conversion
    INNER JOIN
        {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
        ON (date(conversion.year_month_day) = date(calendar.year_month_day) AND calendar.date_scope = 'DAY')
    WHERE
        conversion.year_month_day IS NOT NULL
        AND
        conversion.category IS NOT NULL
        AND
        conversion.sub_category IS NOT NULL
        AND
        metric_value IS NOT NULL
        AND region IS NOT NULL
)
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    cnv_day
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
/* -- Script Name = conversion_day.sql :: BEGIN -- */
{%- endmacro -%}