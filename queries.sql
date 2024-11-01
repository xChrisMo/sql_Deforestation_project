----Joining all tables to create view 'FORESTATION' as Project Requirements

CREATE VIEW forestation AS
SELECT 
    f_area.country_code AS fa_country_code,
    f_area.country_name AS fa_country_name,
    f_area.year,
    f_area.forest_area_sqkm,
    l_area.country_code AS la_country_code,
    l_area.country_name AS la_country_name,
    l_area.year AS la_year,
    l_area.total_area_sq_mi,
    r.country_code AS r_country_code,
    r.country_name AS r_country_name,
    r.region,
    r.income_group,
    (f_area.forest_area_sqkm / (l_area.total_area_sq_mi * 2.59)) * 100 AS forest_percentage
FROM 
    forest_area AS f_area
JOIN 
    land_area AS l_area 
ON 
    f_area.year = l_area.year
    AND f_area.country_code = l_area.country_code
JOIN 
    regions AS r
ON 
    r.country_code = f_area.country_code;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

1. Global Situation 

---- a. Finding sum of Forest in Km for the entire World as at 1990

SELECT forest_area_sqkm
FROM forestation
WHERE fa_country_name = 'World' and year = 1990;


---- b. Finding sum of Forest in Km for the entire World at 2016

SELECT forest_area_sqkm
FROM forestation
WHERE fa_country_name = 'World' and year = 2016;

----c. The difference in the Forest Square from 1990 to 2016 -> using a Scalar Statement

SELECT    
    (SELECT forest_area_sqkm
        FROM forestation
        WHERE fa_country_name = 'World' and year = 1990)-
    (SELECT forest_area_sqkm
        FROM forestation
        WHERE fa_country_name = 'World' and year = 2016) as forest_area_change;

---- d. Percentage difference in Forest Square in KMs from 1990 to 2016 -> using Common Table Expression

WITH sqkm_1990 as (SELECT forest_area_sqkm as f_a_1990
                   FROM deforestation
                   WHERE fa_country_name = 'World' and year = 1990
                  ),
     sqkm_2016 as (SELECT forest_area_sqkm as f_a_2016
                   FROM deforestation
                   WHERE fa_country_name = 'World' and year = 2016
                  )             
---The above CTE aloen could have been used to answer the previous question even 
SELECT ((f_a_1990 - f_a_2016)/(f_a_1990)*100) as percentage_difference
FROM sqkm_2016, sqkm_1990;


----e. If you compare the amount of forest area lost between 1990 and 2016, to which country's total area in 2016 is it closest to?

SELECT *
FROM forestation
WHERE year = 2016 AND total_area_sq_mi <= 511370.27
ORDER BY total_area_sq_mi DESC
LIMIT 1

---Knowing well 511370.27 is the Square_mile equvalent of our square kilometer answer gotten in C.
    
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

2. Regional Outlook

----Creating perfect_forest_2016 view

CREATE OR REPLACE VIEW new_regional_distribution AS
(SELECT r.region,
       l.year,
       SUM(f.forest_area_sqkm) sum_forest_area_sqkm,
       SUM(l.total_area_sq_mi*2.59) as total_area_sqkm,
       (SUM(f.forest_area_sqkm)/SUM(l.total_area_sq_mi*2.59))*100 AS percent_fa_region
FROM regions r 
JOIN land_area l
ON r.country_code = l.country_code                                    
JOIN forest_area f
ON f.country_code = l.country_code AND f.year = l.year
GROUP BY 1, 2);                                 

---------------------------------------
----What was the percent forest of the entire world in 2016?

SELECT region, ROUND(CAST(percent_fa_region as numeric), 2)
FROM new_regional_distribution
WHERE year = 2016 AND region = 'World'

----Which region had the HIGHEST percent forest in 2016?

SELECT region, ROUND(CAST(percent_fa_region AS numeric), 2)
FROM new_regional_distribution
WHERE year = 2016
ORDER BY 2 DESC, 1
LIMIT 1;

----Which region had the LOWEST percent forest in 2016?

SELECT region, ROUND(CAST(percent_fa_region AS numeric), 2)
FROM new_regional_distribution
WHERE year = 2016
ORDER BY 2 ASC, 1
LIMIT 1;

----What was the percent forest of the entire world in 1990?

SELECT region, ROUND(CAST(percent_fa_region as numeric), 2)
FROM new_regional_distribution
WHERE year = 1990 AND region = 'World';


----Which region had the HIGHEST percent forest in 1990?

SELECT region, ROUND(CAST(percent_fa_region AS numeric), 2)
FROM new_regional_distribution
WHERE year = 1990
ORDER BY 2 DESC, 1
LIMIT 1;

----Which region had the LOWEST percent forest in 1990?

SELECT region, ROUND(CAST(percent_fa_region AS numeric), 2)
FROM new_regional_distribution
WHERE year = 1990
ORDER BY 2 ASC, 1
LIMIT 1;


----Based on the table you created, which regions of the world DECREASED in forest area from 1990 to 2016?

WITH percentage_1990 AS 
    (SELECT * FROM new_regional_distribution WHERE year=1990),
percentage_2016 AS 
    (SELECT * FROM new_regional_distribution WHERE year=2016)
SELECT percentage_2016.region,  
    ROUND(CAST(percentage_1990.percent_fa_region AS numeric), 2) AS percentage_1990_fa,
    ROUND(CAST(percentage_2016.percent_fa_region AS numeric), 2) AS percentage_2016_fa
FROM percentage_2016 
JOIN percentage_1990 ON percentage_2016.region = percentage_1990.region
WHERE percentage_1990.percent_fa_region > percentage_2016.percent_fa_region
ORDER BY 2 DESC;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

3. Country-Level Detail

---MAKING a 'country_division' VIEW

CREATE OR REPLACE VIEW country_division AS
(SELECT r.country_name,
       l.year,
       SUM(f.forest_area_sqkm) sum_forest_area_sqkm,
       SUM(l.total_area_sq_mi*2.59) as total_area_sqkm,
       (SUM(f.forest_area_sqkm)/SUM(l.total_area_sq_mi*2.59))*100 AS percent_fa_region
FROM regions r 
JOIN land_area l
ON r.country_code = l.country_code                                    
JOIN forest_area f
ON f.country_code = l.country_code AND f.year = l.year
GROUP BY 1, 2);


---a. Which 5 countries saw the largest amount decrease in forest area from 1990 to 2016? What was the difference in forest area for each?

WITH forest_area_1990 AS (
    SELECT 
        country_code,
        country_name,
        year,
        forest_area_sqkm AS forest_area_sqkm_1990
    FROM forest_area
    WHERE year = 1990 
        AND forest_area_sqkm IS NOT NULL
        AND country_name != 'World'
),
forest_area_2016 AS (
    SELECT 
        country_code,
        country_name,
        year,
        forest_area_sqkm AS forest_area_sqkm_2016
    FROM forest_area
    WHERE year = 2016 
        AND forest_area_sqkm IS NOT NULL
        AND country_name != 'World'
)
SELECT 
    forest_area_1990.country_code,
    forest_area_1990.country_name,
    r.region,
    forest_area_1990.forest_area_sqkm_1990 AS fa_1990_sqkm,
    forest_area_2016.forest_area_sqkm_2016 AS fa_2016_sqkm,
    forest_area_1990.forest_area_sqkm_1990 - forest_area_2016.forest_area_sqkm_2016 AS diff_fa_sqkm
FROM 
    forest_area_2016
JOIN 
    forest_area_1990
ON 
    forest_area_1990.country_code = forest_area_2016.country_code
    AND (forest_area_sqkm_1990 IS NOT NULL AND forest_area_sqkm_2016 IS NOT NULL)
JOIN 
    regions r
ON 
    r.country_code = forest_area_1990.country_code
ORDER BY
    6 DESC
LIMIT 5;


---b. Which 5 countries saw the largest percent decrease in forest area from 1990 to 2016? What was the percent change to 2 decimal places for each?

WITH forest_area_1990 AS (
    SELECT country_code, country_name, forest_area_sqkm AS forest_area_sqkm_1990
    FROM forest_area
    WHERE year = 1990 AND forest_area_sqkm IS NOT NULL AND country_name != 'World'
),
forest_area_2016 AS (
    SELECT country_code, country_name, forest_area_sqkm AS forest_area_sqkm_2016
    FROM forest_area
    WHERE year = 2016 AND forest_area_sqkm IS NOT NULL AND country_name != 'World'
)

SELECT 
    fa1990.country_name,
    r.region,
    ROUND(fa1990.forest_area_sqkm_1990::numeric, 2) AS forest_area_sqkm_1990,
    ROUND(fa2016.forest_area_sqkm_2016::numeric, 2) AS forest_area_sqkm_2016,
    ROUND(((fa1990.forest_area_sqkm_1990 - fa2016.forest_area_sqkm_2016) * 100.0 / fa1990.forest_area_sqkm_1990)::numeric, 2) AS percent_decrease
FROM 
    forest_area_1990 fa1990
JOIN 
    forest_area_2016 fa2016
ON 
    fa1990.country_code = fa2016.country_code
JOIN 
    regions r
ON 
    r.country_code = fa1990.country_code
WHERE 
    fa1990.forest_area_sqkm_1990 > fa2016.forest_area_sqkm_2016
ORDER BY 
    percent_decrease DESC
LIMIT 5;


---c. If countries were grouped by percent forestation in quartiles, which group had the most countries in it in 2016?

WITH count AS (
    SELECT 
        fa_country_name,
        year,
        forest_percentage,
        CASE 
            WHEN forest_percentage >= 75 THEN 4
            WHEN forest_percentage < 75 AND forest_percentage >= 50 THEN 3
            WHEN forest_percentage < 50 AND forest_percentage >= 25 THEN 2
            ELSE 1
        END AS percentile
    FROM forestation
    WHERE year = 2016 
    AND forest_percentage IS NOT NULL
    AND fa_country_name != 'World'
)
SELECT 
    percentile,
    COUNT(percentile) as percentile_count
FROM count
GROUP BY percentile
ORDER BY COUNT(percentile) DESC;


---d. List all of the countries that were in the 4th quartile (percent forest > 75%) in 2016.

WITH count AS (
    SELECT 
        fa_country_name as Country,
        year,
        region,
        forest_percentage,
        CASE 
            WHEN forest_percentage >= 75 THEN 4
            WHEN forest_percentage < 75 AND forest_percentage >= 50 THEN 3
            WHEN forest_percentage < 50 AND forest_percentage >= 25 THEN 2
            ELSE 1
        END AS percentile
    FROM forestation
  JOIN
    WHERE year = 2016 
    AND forest_percentage IS NOT NULL
    AND fa_country_name != 'World'
)
SELECT 
    Country, 
    region,
    percentile,
    ROUND(CAST(forest_percentage AS numeric), 2) as forest_percentage
FROM count
WHERE percentile = 4
ORDER BY 1 ASC;

---e. How many countries had a percent forestation higher than the United States in 2016?

WITH count AS (
    SELECT 
        fa_country_name as Country,
        year,
        forest_percentage,
        CASE 
            WHEN forest_percentage >= 75 THEN 4
            WHEN forest_percentage < 75 AND forest_percentage >= 50 THEN 3
            WHEN forest_percentage < 50 AND forest_percentage >= 25 THEN 2
            ELSE 1
        END AS percentile
    FROM forestation
    WHERE year = 2016 
    AND forest_percentage IS NOT NULL
    AND fa_country_name != 'World'
)
SELECT 
    Country, 
    percentile,
    ROUND(CAST(forest_percentage AS numeric), 2) as forest_percentage
FROM count
WHERE forest_percentage > (SELECT forest_percentage FROM count WHERE Country = 'United States') 
ORDER BY ROUND(CAST(forest_percentage AS numeric), 2) desc;


** EXTRA **
--- Region and Percentage forestation for both 1990 and 2016

WITH percentage_1990 AS 
    (SELECT * FROM new_regional_distribution WHERE year=1990),
percentage_2016 AS 
    (SELECT * FROM new_regional_distribution WHERE year=2016)
SELECT percentage_2016.region,  
    ROUND(CAST(percentage_1990.percent_fa_region AS numeric), 2) AS percentage_1990_fa,
    ROUND(CAST(percentage_2016.percent_fa_region AS numeric), 2) AS percentage_2016_fa
FROM percentage_2016 
JOIN percentage_1990 ON percentage_2016.region = percentage_1990.region
ORDER BY 2 DESC;
