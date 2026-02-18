{%- macro partnership_booking_dot_com_revenue() -%}
/* -- Script Name = 202_partnership_booking_dot_com_revenue.sql :: BEGIN -- */
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
select 
    year_month_day as year_month_day,
    map.output_product_pl as product_pl,
    map.output_region as region,
    category as category,
    sub_category as sub_category,
    metric_name as metric_name,
    sum(metric_value) as metric_value
from    
(   
/* ------------------------------------------------------------------------------------------------------- -- */
    SELECT DISTINCT
        year_month_day
        /* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
        , product_pl
        , region
        /* ------------------------------------------------------------------------------------------------------- -- */
        , 'Non Trx' AS category
        , 'Partnerships-booking.com' AS sub_category
        , 'Revenue' AS metric_name
        , SUM(commission_gbp) AS metric_value
    FROM 
    (
        select DATE(event_created) AS year_month_day
            , country.product_pl AS product_pl
            , country.region AS region
            , event_booking_orders_id AS booking_id
            , round((COALESCE(ccr.rate_gbp, 1) * COALESCE(booking.event_commission_actual_amount_orders, booking.event_commission_estimated_amount_booker_currency, 0)), 10) commission_gbp
        from 
        (
            select * from (
                SELECT
                    event_created
                    , event_booking_orders_id
                    , event_accommodation_details_location_country
                    , event_currency_booker
                    , event_commission_estimated_amount_booker_currency
                    , event_commission_actual_amount_orders
                    , row_number() OVER (PARTITION BY event_id ORDER BY event_time DESC) rn
                FROM
                    data_lake_private_prod.bookingapidatafeeds
                WHERE (date(event_created) >= date('2024-08-01'))
                and date('{{ env_var("exe_end_date") }}') >= date('2024-08-01')
            )
            where rn = 1
        ) booking
        LEFT JOIN (
            SELECT
                c1.valid_from
                , c1.valid_to
                , c1.base_currency
                , avg((CASE WHEN (c1.target_currency = 'GBP') THEN c1.rate END)) rate_gbp
                , avg((CASE WHEN (c1.target_currency = 'EUR') THEN c1.rate END)) rate_eur
            FROM bi_dwh.currency_conversion_rates c1
            WHERE c1.target_currency IN ('GBP', 'EUR')
            GROUP BY 1, 2, 3
        )  ccr
            ON booking.event_currency_booker = ccr.base_currency
            AND booking.event_created BETWEEN ccr.valid_from AND ccr.valid_to
        LEFT JOIN (
            select country_code
                , product_pl
                , region
            from prod_data_metrics_layer.country_codes_lookup
            GROUP BY 1, 2, 3
        ) country
            ON CASE WHEN UPPER(booking.event_accommodation_details_location_country) = 'XY' THEN 'CY'
                ELSE UPPER(booking.event_accommodation_details_location_country) END = country.country_code

        UNION

        SELECT
            DATE(booking.booking_date) AS year_month_day
            , country.product_pl AS product_pl
            , country.region AS region
            , cast(booking.booking_number as varchar) AS booking_id
            , booking.your_commission_in_your_currency AS commission_gbp
        FROM (
            SELECT
                booking_date
                , booking_number
                , booker_country
                , your_commission_in_your_currency
                , row_number() OVER (PARTITION BY booking_number ORDER BY event_time DESC) rn
            FROM
                data_lake_private_prod.bookingmanualdatafeeds
            WHERE date(booking_date) < date('2024-08-01')
            and date('{{ env_var("exe_start_date") }}') < date('2024-08-01')
            ) booking
            LEFT JOIN bi_dwh_ref_data.bi_d_country_code_names l
                ON (case when lower(booking.booker_country) = 'korea, south' then 'korea, republic of'
                    when lower(booking.booker_country) = 'abkhazia' then 'georgia'
                    when lower(booking.booker_country) = 'congo (brazzaville)' then 'congo - brazzaville'
                    when lower(booking.booker_country) = 'bonaire, saint eustatius and saba' then 'caribbean netherlands'
                    when lower(booking.booker_country) = 'wallis and futuna islands' then 'france'
                    when lower(booking.booker_country) = 'united states minor outlying islands' then 'united states'
                    when lower(booking.booker_country) = 'congo (kinshasa)' then 'congo - kinshasa'
                    when lower(booking.booker_country) = 'svalbard and jan mayen islands' then 'svalbard & jan mayen'
                    else lower(booking.booker_country) end) = lower(l.country_lookup_value)
            LEFT JOIN prod_data_metrics_layer.country_codes_lookup country
                ON l.country_code = country.country_code
            where rn = 1
    )
    GROUP BY CUBE(year_month_day, product_pl, region)
) qry 
/* -- Changes For DAT-1715 (Addition Of New FOREIGN TRAVEL Region) --------------------------------------- -- */
inner join 
    {{ source("data_metrics_layer", "product_pl_region_map") }} map 
    on ((qry.product_pl = map.input_product_pl) and (qry.region = map.input_region))
where 
    qry.year_month_day is not null
    and qry.product_pl is not null
    and qry.region is not null
group by 
    1,2,3,4,5,6
/* ------------------------------------------------------------------------------------------------------- -- */
/* -- Script Name = 202_partnership_booking_dot_com_revenue.sql :: END -- */
{%- endmacro -%}

