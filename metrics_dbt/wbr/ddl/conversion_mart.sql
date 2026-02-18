/*
This CREATE TABLE statement generates the metadata structure for LTV Segment = Conversion

-- INITIAL DRAFT     : 25-Jul-2024
-- MODIFIED ON       : 19-Aug-2024
*/

CREATE TABLE {{schema_wbr_mart}}.{{tbl_conversion}}
(
    date_scope varchar,
    financial_year integer,
    week_number integer,
    year_month_day date,
    last_modified timestamp,
    week_commencing_date date,
    product_pl varchar,
    region varchar,
    category varchar,
    sub_category varchar,
    metric_name varchar,
    metric_value double
)
WITH
(
   format = 'PARQUET',
   format_version = 2,
   location = 's3://{{s3_bucket}}/{{s3_prefix}}/{{schema_wbr_mart}}/tables/{{tbl_conversion}}/parquet',
   partitioning = ARRAY['week_commencing_date'],
   type = 'ICEBERG'
)
