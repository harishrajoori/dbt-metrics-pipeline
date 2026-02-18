{% test reconcile_booking_dot_com_bookings(model) %}

with booking_dot_com_bookings as (
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

, total_number_of_bookings as (
    select
        year_month_day
        , product_pl
        , region
        , COUNT(distinct booking_id) AS metric_value
    from booking_dot_com_bookings
    where rn = 1
    group by year_month_day, product_pl, region
)

, monetisation_mart_bookings as (
    select
        year_month_day
        , product_pl
        , region
        , category
        , sub_category
        , metric_name
        , metric_value
    from {{ model }}
    where category = 'Non Trx'
    and sub_category = 'Partnerships-booking.com'
    and metric_name = 'No. of Hotel Bookings'
    and date_scope = 'DAY'
    and year_month_day BETWEEN date('{{ env_var("exe_start_date") }}') AND date('{{ env_var("exe_end_date") }}')
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
        , booking.metric_value as booking_metric_value
        , ABS(booking.metric_value - mm.metric_value) AS difference
    FROM total_number_of_bookings booking
    INNER JOIN monetisation_mart_bookings mm
    ON booking.year_month_day = mm.year_month_day
    AND booking.product_pl = mm.product_pl
    AND booking.region = mm.region
)

SELECT *
FROM compare_cte
WHERE difference > 0

{% endtest %}