-- UPDATED ON 18-Sep-2024 || DQ VERIFIED || CODE REVIEWED

-- DELETE FROM "my_company_data"."stg_wbr_mart"."monetisation_mart" WHERE date_scope = 'WEEK';

{%- macro monetisation_week() -%}
/* -- Script Name = monetisation_week.sql :: BEGIN -- */
WITH
    /* ---
    below CTE generates WEEK level aggregations for other (non-customer) metrics
    --- */
    week_aggregation_others AS 
    (
        SELECT
            week_commencing_date,
            product_pl,
            region,
            category,
            sub_category,
            metric_name,
            SUM(metric_value) AS metric_value
        FROM {{ this }}
        WHERE metric_name IN (
            'Total Revenue',
            'Fee Revenue',
            'Non-Fee Revenue',
            'Gross Transactions',
            'Total Visits',
            'Revenue',
            'Net Sale',
            'Impressions',
            'Monetised Impressions',
            'Clicks',
            'No. of Hotel Bookings',
            'Number of Tickets',
            'Total Number of Tickets'
            )
        AND date_scope = 'DAY'
        AND financial_year IN
        (
            SELECT DISTINCT financial_year
            FROM {{ this }}
            WHERE date_scope = 'DAY'
            AND date(year_month_day) BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
        )
        GROUP BY 1,2,3,4,5,6
    ),
    mnt_week as 
    (
        SELECT
            'WEEK' AS date_scope,
            calendar.financial_year AS financial_year,
            calendar.week_number AS week_number,
            monetisation.week_commencing_date AS year_month_day,
            CAST(current_time AS timestamp) AS last_modified,
            monetisation.week_commencing_date AS week_commencing_date,
            monetisation.product_pl AS product_pl,
            monetisation.region AS region,
            monetisation.category AS category,
            monetisation.sub_category AS sub_category,
            monetisation.metric_name AS metric_name,
            monetisation.metric_value AS metric_value
        FROM
        (
            SELECT
                week_commencing_date,
                product_pl,
                region,
                category,
                sub_category,
                metric_name,
                metric_value
            FROM
                week_aggregation_others
            UNION ALL

            SELECT
                impr.week_commencing_date,
                impr.product_pl,
                impr.region,
                impr.category,
                impr.sub_category,
                'CTR' AS metric_name,
                IF(impr.metric_value > 0, CAST(clicks.metric_value AS DOUBLE) / CAST(impr.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others clicks
            INNER JOIN week_aggregation_others impr
                ON date(clicks.week_commencing_date) = date(impr.week_commencing_date)
                AND clicks.product_pl = impr.product_pl
                AND clicks.region = impr.region
                AND clicks.category = impr.category
                AND clicks.sub_category = impr.sub_category
                AND clicks.sub_category = 'Partnerships-booking.com'
                AND clicks.metric_name = 'Clicks'
                AND impr.metric_name = 'Impressions'

            UNION ALL

            SELECT
                impr.week_commencing_date,
                impr.product_pl,
                impr.region,
                impr.category,
                impr.sub_category,
                'CTR' AS metric_name,
                IF(impr.metric_value > 0, CAST(clicks.metric_value AS DOUBLE) / CAST(impr.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others clicks
            INNER JOIN week_aggregation_others impr
                ON date(clicks.week_commencing_date) = date(impr.week_commencing_date)
                AND clicks.product_pl = impr.product_pl
                AND clicks.region = impr.region
                AND clicks.category = impr.category
                AND clicks.sub_category = impr.sub_category
                AND clicks.sub_category = 'Ads'
                AND clicks.metric_name = 'Clicks'
                AND impr.metric_name = 'Impressions'

            UNION ALL

            SELECT
                rev.week_commencing_date,
                rev.product_pl,
                rev.region,
                rev.category,
                rev.sub_category,
                'CPM' AS metric_name,
                IF(mon_impr.metric_value > 0, CAST(rev.metric_value AS DOUBLE) / (CAST(mon_impr.metric_value AS DOUBLE) / 1000), 0) AS metric_value
            FROM week_aggregation_others rev
            INNER JOIN week_aggregation_others mon_impr
                ON date(rev.week_commencing_date) = date(mon_impr.week_commencing_date)
                AND rev.product_pl = mon_impr.product_pl
                AND rev.region = mon_impr.region
                AND rev.category = mon_impr.category
                AND rev.sub_category = mon_impr.sub_category
                AND rev.sub_category = 'Ads'
                AND rev.metric_name = 'Revenue'
                AND mon_impr.metric_name = 'Monetised Impressions'

            UNION ALL

            SELECT
                bft.week_commencing_date,
                bft.product_pl,
                bft.region,
                bft.category,
                bft.sub_category,
                'Percent of Tickets' AS metric_name,
                IF(tt.metric_value > 0, CAST(bft.metric_value AS DOUBLE) / CAST(tt.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others bft
            INNER JOIN week_aggregation_others tt
                ON date(bft.week_commencing_date) = date(tt.week_commencing_date)
                AND bft.product_pl = tt.product_pl
                AND bft.region = tt.region
                AND bft.category = tt.category
                AND bft.sub_category = 'Booking Fee'
                AND bft.metric_name = 'Number of Tickets'
                AND tt.metric_name = 'Total Number of Tickets'

            UNION ALL

            SELECT
                rft.week_commencing_date,
                rft.product_pl,
                rft.region,
                rft.category,
                rft.sub_category,
                'Percent of Tickets' AS metric_name,
                IF(tt.metric_value > 0, CAST(rft.metric_value AS DOUBLE) / CAST(tt.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others rft
            INNER JOIN week_aggregation_others tt
                ON date(rft.week_commencing_date) = date(tt.week_commencing_date)
                AND rft.product_pl = tt.product_pl
                AND rft.region = tt.region
                AND rft.category = tt.category
                AND rft.sub_category = 'Refund Fee'
                AND rft.metric_name = 'Number of Tickets'
                AND tt.metric_name = 'Total Number of Tickets'

            UNION ALL

            SELECT
                cft.week_commencing_date,
                cft.product_pl,
                cft.region,
                cft.category,
                cft.sub_category,
                'Percent of Tickets' AS metric_name,
                IF(tt.metric_value > 0, CAST(cft.metric_value AS DOUBLE) / CAST(tt.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others cft
            INNER JOIN week_aggregation_others tt
                ON date(cft.week_commencing_date) = date(tt.week_commencing_date)
                AND cft.product_pl = tt.product_pl
                AND cft.region = tt.region
                AND cft.category = tt.category
                AND cft.sub_category = 'COJ Fee'
                AND cft.metric_name = 'Number of Tickets'
                AND tt.metric_name = 'Total Number of Tickets'

            UNION ALL

            SELECT
                mcpt.week_commencing_date,
                mcpt.product_pl,
                mcpt.region,
                mcpt.category,
                mcpt.sub_category,
                'Percent of Tickets' AS metric_name,
                IF(tt.metric_value > 0, CAST(mcpt.metric_value AS DOUBLE) / CAST(tt.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others mcpt
            INNER JOIN week_aggregation_others tt
                ON date(mcpt.week_commencing_date) = date(tt.week_commencing_date)
                AND mcpt.product_pl = tt.product_pl
                AND mcpt.region = tt.region
                AND mcpt.category = tt.category
                AND mcpt.sub_category = 'MCP'
                AND mcpt.metric_name = 'Number of Tickets'
                AND tt.metric_name = 'Total Number of Tickets'

            UNION ALL

            SELECT
                bfr.week_commencing_date,
                bfr.product_pl,
                bfr.region,
                bfr.category,
                bfr.sub_category,
                'Take Rate' AS metric_name,
                IF(ns.metric_value > 0, CAST(bfr.metric_value AS DOUBLE) / CAST(ns.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others bfr
            INNER JOIN week_aggregation_others ns
                ON date(bfr.week_commencing_date) = date(ns.week_commencing_date)
                AND bfr.product_pl = ns.product_pl
                AND bfr.region = ns.region
                AND bfr.category = ns.category
                AND bfr.sub_category = 'Booking Fee'
                AND bfr.metric_name = 'Revenue'
                AND ns.metric_name = 'Net Sale'

            UNION ALL

            SELECT
                rr.week_commencing_date,
                rr.product_pl,
                rr.region,
                rr.category,
                rr.sub_category,
                'Take Rate' AS metric_name,
                IF(ns.metric_value > 0, CAST(rr.metric_value AS DOUBLE) / CAST(ns.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others rr
            INNER JOIN week_aggregation_others ns
                ON date(rr.week_commencing_date) = date(ns.week_commencing_date)
                AND rr.product_pl = ns.product_pl
                AND rr.region = ns.region
                AND rr.category = ns.category
                AND rr.sub_category = 'Refund Fee'
                AND rr.metric_name = 'Revenue'
                AND ns.metric_name = 'Net Sale'

            UNION ALL

            SELECT
                cojr.week_commencing_date,
                cojr.product_pl,
                cojr.region,
                cojr.category,
                cojr.sub_category,
                'Take Rate' AS metric_name,
                IF(ns.metric_value > 0, CAST(cojr.metric_value AS DOUBLE) / CAST(ns.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others cojr
            INNER JOIN week_aggregation_others ns
                ON date(cojr.week_commencing_date) = date(ns.week_commencing_date)
                AND cojr.product_pl = ns.product_pl
                AND cojr.region = ns.region
                AND cojr.category = ns.category
                AND cojr.sub_category = 'COJ Fee'
                AND cojr.metric_name = 'Revenue'
                AND ns.metric_name = 'Net Sale'

            UNION ALL

            SELECT
                cr.week_commencing_date,
                cr.product_pl,
                cr.region,
                cr.category,
                cr.sub_category,
                'Take Rate' AS metric_name,
                IF(ns.metric_value > 0, CAST(cr.metric_value AS DOUBLE) / CAST(ns.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others cr
            INNER JOIN week_aggregation_others ns
                ON date(cr.week_commencing_date) = date(ns.week_commencing_date)
                AND cr.product_pl = ns.product_pl
                AND cr.region = ns.region
                AND cr.category = ns.category
                AND cr.sub_category = 'Commission'
                AND cr.metric_name = 'Revenue'
                AND ns.metric_name = 'Net Sale'

            UNION ALL

            SELECT
                ar.week_commencing_date,
                ar.product_pl,
                ar.region,
                ar.category,
                ar.sub_category,
                'Take Rate' AS metric_name,
                IF(ns.metric_value > 0, CAST(ar.metric_value AS DOUBLE) / CAST(ns.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others ar
            INNER JOIN week_aggregation_others ns
                ON date(ar.week_commencing_date) = date(ns.week_commencing_date)
                AND ar.product_pl = ns.product_pl
                AND ar.region = ns.region
                AND ar.category = ns.category
                AND ar.sub_category = 'Ancillary'
                AND ar.metric_name = 'Revenue'
                AND ns.metric_name = 'Net Sale'

            UNION ALL

            SELECT
                mcpr.week_commencing_date,
                mcpr.product_pl,
                mcpr.region,
                mcpr.category,
                mcpr.sub_category,
                'Take Rate' AS metric_name,
                IF(ns.metric_value > 0, CAST(mcpr.metric_value AS DOUBLE) / CAST(ns.metric_value AS DOUBLE), 0) AS metric_value
            FROM week_aggregation_others mcpr
            INNER JOIN week_aggregation_others ns
                ON date(mcpr.week_commencing_date) = date(ns.week_commencing_date)
                AND mcpr.product_pl = ns.product_pl
                AND mcpr.region = ns.region
                AND mcpr.category = ns.category
                AND mcpr.sub_category = 'MCP'
                AND mcpr.metric_name = 'Revenue'
                AND ns.metric_name = 'Net Sale'

            UNION ALL

            SELECT
                fr.week_commencing_date,
                fr.product_pl,
                fr.region,
                fr.category,
                fr.sub_category,
                'Fee Revenue / Transaction' AS metric_name,
                IF(gt.metric_value > 0, ((fr.metric_value*1.0000000)/(gt.metric_value*1.0000000)), 0) AS metric_value
            FROM week_aggregation_others fr
            INNER JOIN week_aggregation_others gt
                ON date(fr.week_commencing_date) = date(gt.week_commencing_date)
                AND fr.product_pl = gt.product_pl
                AND fr.region = gt.region
                AND fr.category = gt.category
                AND fr.sub_category = gt.sub_category
                AND fr.sub_category = 'All'
                AND fr.metric_name = 'Fee Revenue'
                AND gt.metric_name = 'Gross Transactions'

            UNION ALL

            SELECT
                nfr.week_commencing_date,
                nfr.product_pl,
                nfr.region,
                nfr.category,
                nfr.sub_category,
                'Non-Fee Revenue / Visit' AS metric_name,
                IF(tv.metric_value > 0, ((nfr.metric_value*1.0000000)/(tv.metric_value*1.0000000)), 0) AS metric_value
            FROM week_aggregation_others nfr
            INNER JOIN week_aggregation_others tv
                ON date(nfr.week_commencing_date) = date(tv.week_commencing_date)
                AND nfr.product_pl = tv.product_pl
                AND nfr.region = tv.region
                AND nfr.category = tv.category
                AND nfr.sub_category = tv.sub_category
                AND nfr.sub_category = 'All'
                AND nfr.metric_name = 'Non-Fee Revenue'
                AND tv.metric_name = 'Total Visits'

        ) monetisation
        INNER JOIN
            {{ source("data_metrics_layer", "calendar_dates_lookup") }} calendar
            ON (date(monetisation.week_commencing_date) = date(calendar.week_commencing_date) AND calendar.date_scope = 'WEEK')
    )
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select distinct
    *
from 
    mnt_week
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
/* -- Script Name = monetisation_week.sql :: END -- */
{%- endmacro -%}
