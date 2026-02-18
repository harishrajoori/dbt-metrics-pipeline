{%- macro partnership_booking_dot_com_bookings() -%}
/* -- Script Name = 201_partnership_booking_dot_com_bookings.sql :: BEGIN -- */
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
        , 'No. of Hotel Bookings' AS metric_name
        , COUNT(distinct booking_id) AS metric_value
    FROM 
    (
        SELECT
            DATE(booking.event_created) AS year_month_day
            , country.product_pl AS product_pl
            , country.region AS region
            , booking.event_booking_orders_id AS booking_id
            , ROW_NUMBER() OVER (PARTITION BY booking.event_booking_orders_id ORDER BY booking.event_created DESC) AS rn
        FROM data_lake_private_prod.bookingapidatafeeds booking
        LEFT JOIN {{ source("data_metrics_layer", "country_codes_lookup") }} country
        -- For Booking.com API data, they are using the country code 'XY' for Northern Cyprus.
        -- In the country_codes table, we have 'CY' for Cyprus. Mapped the correct value
            ON CASE WHEN UPPER(booking.event_accommodation_details_location_country) = 'XY' THEN 'CY'
                ELSE UPPER(booking.event_accommodation_details_location_country) END = country.country_code
        WHERE date(booking.event_created) >= date('2024-08-01')
            and date('{{ env_var("exe_end_date") }}') >= date('2024-08-01')

        UNION

        SELECT
            DATE(booking_date) as year_month_day
            , country.product_pl AS product_pl
            , country.region AS region
            , cast(booking_number as varchar) AS booking_id
            , ROW_NUMBER() OVER (PARTITION BY booking_number ORDER BY event_time DESC) rn
        FROM
            data_lake_private_prod.bookingmanualdatafeeds booking
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

        WHERE date(booking_date) < date('2024-08-01')
        and date('{{ env_var("exe_start_date") }}') < date('2024-08-01')
    )
    WHERE rn = 1
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
/* -- Script Name = 201_partnership_booking_dot_com_bookings.sql :: END -- */
{%- endmacro -%}
