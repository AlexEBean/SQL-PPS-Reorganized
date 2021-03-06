-- 2

WITH InitialData AS (
	SELECT 
		FileNM, 
        SUBSTRING_INDEX(REPLACE(FileNM, "TEST_", ""), "_", 3) AS CompanyName,
		REVERSE(SUBSTRING_INDEX(REPLACE(FileNM, "TEST_", ""), ".", 1)) AS ReversedFileNM,
        ROUND (   
        (
            LENGTH(FileNM)
            - LENGTH( REPLACE (FileNM, "_", "") ) 
        ) / LENGTH("_")        
    ) AS UnderscoreCount    
	FROM loaded_files
),

DataICanUse AS (
	SELECT
    FileNM,
    REPLACE(CompanyName, "_", " ") AS CompanyName,
    CASE
		WHEN FileNM REGEXP "^TEST_"
        THEN SUBSTRING_INDEX(REVERSE(SUBSTRING_INDEX(ReversedFileNM, "_", UnderScoreCount - 3)), "_", 1)
		ELSE SUBSTRING_INDEX(REVERSE(SUBSTRING_INDEX(ReversedFileNM, "_", UnderScoreCount - 2)), "_", 1) 
        END AS DateInfo
	FROM InitialData
),

DateData AS (
	SELECT 
	DISTINCT CompanyName,
    CASE 
		WHEN CHAR_LENGTH(DateInfo) = 8
        THEN SUBSTRING_INDEX(STR_TO_DATE(DateInfo, '%m%d%Y'), "-", 2)
        WHEN CHAR_LENGTH(DateInfo) = 7
        THEN SUBSTRING_INDEX(STR_TO_DATE(DateInfo, '%b%Y'), "-", 2)
	END AS Date
	FROM DataICanUse
),

MinMaxData AS (
	SELECT 
		CompanyName,
		STR_TO_DATE(CONCAT(SUBSTRING_INDEX(MIN(Date), "-", 2), '-01'), '%Y-%m-%d') AS MinimumDate,
        STR_TO_DATE(CONCAT(SUBSTRING_INDEX(MAX(Date), "-", 2), '-01'), '%Y-%m-%d') AS MaximumDate
		FROM DateData
		GROUP BY CompanyName
),

FinalData AS (
	SELECT
	d.CompanyName,
    STR_TO_DATE(CONCAT(d.Date, '-01'), '%Y-%m-%d') AS Date,
    m.MinimumDate,
    m.MaximumDate
	FROM DateData d
    JOIN MinMaxData m
		ON d.CompanyName = m.CompanyName
)

SELECT
	f1.CompanyName,
	DATE_FORMAT(f1.Date + INTERVAL 1 MONTH, '%m/%Y') AS MissingDate
	FROM FinalData f1
    LEFT JOIN FinalData f2
		ON f1.Date = f2.Date - INTERVAL 1 MONTH
			AND f1.CompanyName = f2.CompanyName
            OR f1.Date = f1.MaximumDate
            OR f1.Date = f1.MinimumDate
	WHERE f1.Date BETWEEN f1.MinimumDate AND f1.MaximumDate
		AND f2.Date IS NULL
    ORDER BY f1.CompanyName, f1.Date;


-- 3

WITH InitialData AS (
	SELECT 
		r.customer_id, 
        YEAR(r.rental_date) AS rental_year, 
        c.name, 
        COUNT(*) AS TimesRented
	FROM Rental r
		JOIN inventory i 
			ON r.inventory_id = i.inventory_id
		JOIN film f 
			ON i.film_id = f.film_id
		JOIN film_category fc
			ON f.film_id = fc.film_id
		JOIN category c 
			ON fc.category_id = c.category_id
	GROUP BY r.customer_id, YEAR(r.rental_date), c.name
    ORDER BY COUNT(*) DESC, c.name
),

FavoriteGenreData1 AS (
	SELECT 
		customer_id, 
        rental_year, 
        name AS FavoriteGenre1, 
        MAX(TimesRented) AS FavoriteGenreRentalCount1
	FROM InitialData
    GROUP BY customer_id, rental_year
),

FavoriteGenreData2 AS (
	SELECT 
		i.customer_id, 
        i.rental_year, 
        f1.FavoriteGenre1, 
        i.name AS FavoriteGenre2, 
        f1.FavoriteGenreRentalCount1,
        MAX(i.TimesRented) AS FavoriteGenreRentalCount2
	FROM InitialData i
		JOIN FavoriteGenreData1 f1
			ON i.customer_id = f1.customer_id
				AND i.rental_year = f1.rental_year
			WHERE i.name != f1.FavoriteGenre1
    GROUP BY i.customer_id, i.rental_year
),

FavoriteGenreData3 AS (
	SELECT 
		i.customer_id, 
        i.rental_year, 
        f2.FavoriteGenre1, 
        f2.FavoriteGenre2, 
        i.name AS FavoriteGenre3, 
		f2.FavoriteGenreRentalCount1,
        f2.FavoriteGenreRentalCount2,
        MAX(i.TimesRented) AS FavoriteGenreRentalCount3
	FROM InitialData i
		JOIN FavoriteGenreData2 f2
			ON i.customer_id = f2.customer_id
				AND i.rental_year = f2.rental_year
			WHERE i.name != f2.FavoriteGenre1
				AND i.name != f2.FavoriteGenre2
    GROUP BY i.customer_id, i.rental_year
)

SELECT 
	customer_id, 
	rental_year, 
    FavoriteGenre1, 
    FavoriteGenre2, 
    FavoriteGenre3
	FROM FavoriteGenreData3
    ORDER BY customer_id;