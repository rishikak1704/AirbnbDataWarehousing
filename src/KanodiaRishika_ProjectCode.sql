
--Drop Table HostDim
CREATE TABLE HostDim(
    host_dim_id INT IDENTITY(1,1), 
    host_id INT,
    host_name VARCHAR(255),
    host_in_months INT,
    host_is_superhost INT,
    host_listings_count	INT,
    host_identity_verified INT,
    PRIMARY KEY(host_dim_id)
  );
GO
SELECT COUNT(*)FROM HostDim   --2280 rows


--DROP TABLE ListingDim
CREATE TABLE ListingDim(
    listing_dim_id INT IDENTITY(1,1), 
    listing_id INT,
    property_type VARCHAR(255),
    room_type VARCHAR(255),
    num_accommodates INT,
    num_bedrooms INT,
    num_bathrooms INT,
    listing_price INT,
    current_flag INT,
    effective_timestamp DATE,
    expire_timestamp DATE
    PRIMARY KEY (listing_dim_id)
  );
GO
SELECT COUNT(*) FROM ListingDim   ---3162 rows


-- Drop Table LocationDim
CREATE TABLE LocationDim(
    location_dim_id INT IDENTITY(1,1),
    neighbourhood VARCHAR(255),
    district VARCHAR (255),
    city VARCHAR(25),
    state VARCHAR(25),
    country VARCHAR(25),
    PRIMARY KEY (location_dim_id)
);

SELECT COUNT(*) FROM LocationDim  ---87 rows


--DROP TABLE CrimeTypeDim
CREATE TABLE CrimeTypeDim(
    crimeType_dim_id INT IDENTITY(1,1),
    crime_category VARCHAR(255),
    prior_crime_category VARCHAR(255),
    offense_group VARCHAR(255),
    offense VARCHAR(255),
    offense_code VARCHAR(4),
    is_violent_crime INT,
    PRIMARY KEY(crimeType_dim_id)
);
SELECT COUNT(*) FROM CrimeTypeDim  --- 39 rows

-- DROP TABLE DateDim
CREATE TABLE DateDim(
    date_dim_id INT IDENTITY(1,1),
    date DATE,
    year INT,
    month INT,
    year_month VARCHAR(255),
    quarter INT, 
    week INT, 
    day VARCHAR(25),
    is_public_holiday INT,
    PRIMARY KEY (date_dim_id)
);
SELECT COUNT(*) FROM DateDim   --- 

-- Drop Table MonthDim
CREATE TABLE MonthDim(
    month_dim_id INT IDENTITY(1,1), 
    month_year VARCHAR(30),
    year INT,
    month INT, 
    year_month VARCHAR(30), 
    quarter INT,
    PRIMARY KEY (month_dim_id)
);
SELECT COUNT(*) FROM MonthDim

-- Drop Table Booking_Staging
CREATE TABLE BookingStaging(
listing_id INT,
host_id INT,
booking_date DATE,
booking_month_year VARCHAR(30),
available INT,
price INT, 
neighbourhood VARCHAR(255),
district VARCHAR(255),
review_scores_value INT, 
review_scores_location INT
);
GO	
SELECT COUNT(*) FROM BookingStaging  --1153959 rows
	
--Drop Table Crime_Staging;
CREATE TABLE Crime_Staging(
    offense_id VARCHAR(12), 
    crime_date DATE,
    crime_month_year VARCHAR(255),
    offense_code VARCHAR(10),
    neighbourhood VARCHAR(255),
    district VARCHAR(255)
);
GO
SELECT COUNT(*) FROM Crime_Staging  --- 63016 rows


--DROP TABLE BookingFact
CREATE TABLE BookingFact(
    booking_fact_id INT IDENTITY(1,1),
    listing_dim_id INT,
    host_dim_id INT,
    date_dim_id INT,
    available INT,
    price_per_guest NUMERIC(10,2),
    price NUMERIC(10,2),
    review_scores_value NUMERIC(10,2),
    PRIMARY KEY (booking_fact_id),
    FOREIGN KEY (listing_dim_id) REFERENCES ListingDim(listing_dim_id),
    FOREIGN KEY (host_dim_id) REFERENCES HostDim(host_dim_id),
    FOREIGN KEY (date_dim_id) REFERENCES DateDim(date_dim_id), 
);
GO

--DROP TABLE Crime_rate_fact
CREATE TABLE Crime_rate_fact(
    crime_rate_fact_id INT IDENTITY(1,1),
    date_dim_id INT,
    location_dim_id INT,
    crimeType_dim_id INT,
    crime_count INT,
    PRIMARY KEY (crime_rate_fact_id),
    FOREIGN KEY (location_dim_id) REFERENCES LocationDim(location_dim_id),
    FOREIGN KEY (date_dim_id) REFERENCES DateDim(date_dim_id),
    FOREIGN KEY (crimeType_dim_id) REFERENCES CrimeTypeDim(crimeType_dim_id)
);

--DROP TABLE Location_fact
CREATE TABLE Location_fact(
    location_fact_id INT IDENTITY(1,1),
    month_dim_id INT,
    location_dim_id INT,
    total_listings INT,
    avg_occupancy_rate NUMERIC(10,2),
    avg_price NUMERIC(10,2),
    total_num_crimes NUMERIC(10,2),
    PRIMARY KEY (location_fact_id),
    FOREIGN KEY (location_dim_id) REFERENCES LocationDim(location_dim_id),
    FOREIGN KEY (month_dim_id) REFERENCES MonthDim(month_dim_id)
);
GO

----------------INSERT FACTS -----------------------------
--------- insert facts into booking fact table ---------------------
INSERT INTO BookingFact(listing_dim_id, host_dim_id, date_dim_id, available, 
price_per_guest, price, review_scores_value)
SELECT l.listing_dim_id, h.host_dim_id, d.date_dim_id, b.available,
CASE 
    WHEN b.price= 0 THEN listing_price/l.num_accommodates
    ELSE b.price/l.num_accommodates
    END AS price_per_guest,
CASE 
    WHEN b.price= 0 THEN listing_price
    ELSE b.price/l.num_accommodates
    END AS price,
b.review_scores_value
FROM BookingStaging b
LEFT JOIN ListingDim l ON b.listing_id = l.listing_id
LEFT JOIN HostDim h ON b.host_id = h.host_id
LEFT JOIN DateDim d ON b.booking_date = d.date

SELECT COUNT(*) FROM BookingFact
--DROP TABLE BookingFact



------------------ insert facts into location facts table ---------------------
INSERT INTO Location_fact(month_dim_id,location_dim_id, total_listings,
avg_occupancy_rate, avg_price, total_num_crimes)
SELECT T.month_dim_id, T.location_dim_id, T.total_listings, T.avg_occupancy_rate, T.avg_price,S.total_num_crimes 
 FROM    
    (SELECT m.month_dim_id, loc.location_dim_id, 
    COUNT(DISTINCT(b.listing_id)) AS total_listings,
    COUNT(CASE WHEN b.available = 0 THEN b.available ELSE NULL END)/(COUNT(b.available)*1.0) AS avg_occupancy_rate,
    AVG(CASE WHEN b.price = 0 THEN l.listing_price ELSE b.price END) AS avg_price
    FROM BookingStaging b
    JOIN MonthDim m ON b.booking_month_year = m.month_year
    JOIN ListingDim l ON b.listing_id = l.listing_id
    JOIN LocationDim loc ON b.neighbourhood = loc.neighbourhood AND b.district = loc.district
    GROUP BY m.month_dim_id, loc.location_dim_id) AS T
JOIN
    (SELECT m.month_dim_id, loc.location_dim_id, COUNT(c.offense_id) AS total_num_crimes
    FROM Crime_Staging c
    JOIN MonthDim m ON c.crime_month_year = m.month_year
    JOIN LocationDim loc ON c.neighbourhood = loc.neighbourhood AND c.district = loc.district
    GROUP BY m.month_dim_id, loc.location_dim_id) AS S
ON T.month_dim_id = S.month_dim_id AND T.location_dim_id = S.location_dim_id
ORDER BY T.month_dim_id, T.location_dim_id

SELECT *FROM Location_fact
--DROP TABLE Location_fact


------------------ insert facts into crime rate fact table ---------------------
INSERT INTO Crime_rate_fact(date_dim_id, location_dim_id, crimeType_dim_id, crime_count)
SELECT d.date_dim_id, LocationDim.location_dim_id, ct.crimeType_dim_id, COUNT(c.offense_id) AS crime_count
FROM Crime_Staging c
LEFT JOIN CrimeTypeDim ct ON c.offense_code = ct.offense_code
LEFT JOIN LocationDim  ON c.neighbourhood = LocationDim.neighbourhood AND c.district = LocationDim.district
LEFT JOIN DateDim d ON c.crime_date = d.date
GROUP BY d.date_dim_id, LocationDim.location_dim_id, ct.crimeType_dim_id
ORDER BY d.date_dim_id, LocationDim.location_dim_id, ct.crimeType_dim_id

SELECT * FROM CRIME_RATE_FACT
--DROP TABLE CRIME_RATE_FACT


--------- loading delta -------------
--DROP TABLE DeltaBookingStaging
Create TABLE DeltaBookingStaging(
listing_id INT,
host_id INT,
booking_date DATE,
booking_month_year VARCHAR(30),
available INT,
price INT, 
neighbourhood VARCHAR(255),
district VARCHAR(255),
review_scores_value INT, 
review_scores_location INT
);
GO

SELECT * FROM DeltaBookingStaging

--DROP TABLE DeltaHostDim
CREATE TABLE DeltaHostDim(
    host_id INT,
    host_name VARCHAR(255),
    host_in_months INT,
    host_is_superhost INT,
    host_listings_count INT,
    host_identity_verified INT
    );
GO


--DROP TABLE DeltaListingDim
CREATE TABLE DeltaListingDim( 
    listing_id INT,
    property_type VARCHAR(255),
    room_type VARCHAR(255),
    num_accommodates INT,
    num_bedrooms INT,
    num_bathrooms INT,
    listing_price INT
  );
GO
SELECT * FROM DeltaListingDim

--DROP TABLE DeltaLocationDim
CREATE TABLE DeltaLocationDim(
    neighbourhood VARCHAR(255), 
    district VARCHAR(255), 
    city VARCHAR(25), 
    state VARCHAR(25), 
    country VARCHAR(30)
    );
GO
SELECT * FROM DeltaLocationDim


--DROP TABLE DeltaDateDim(
CREATE TABLE DeltaDateDim(
    date DATE, 
    year INT, 
    month INT, 
    year_month VARCHAR(30),
    quarter INT, 
    week INT, 
    day VARCHAR(25), 
    is_public_holiday INT
    );
GO
SELECT * FROM DeltaDateDim

--DROP TABLE DeltaMonthDim
CREATE TABLE DeltaMonthDim(
    month_year VARCHAR(30),
    year INT,
    month INT, 
    year_month VARCHAR(30), 
    quarter INT
);
GO
SELECT * FROM DeltaMonthDim


------------------- SCD 2: update listing dim table ---------------------
UPDATE ListingDim
SET expire_timestamp = '2017-01-01', current_flag = 0
WHERE listing_id IN 
(SELECT Delta.listing_id 
    FROM(
        SELECT * FROM DeltaListingDim
        EXCEPT
        SELECT listing_id, property_type, room_type, num_accommodates,num_bedrooms, num_bathrooms, listing_price
        FROM ListingDim) Delta
        );
    GO

INSERT INTO ListingDim(listing_id, property_type, room_type, num_accommodates, num_bedrooms, num_bathrooms, listing_price, current_flag, effective_timestamp, expire_timestamp)
SELECT *, 1 AS current_flag, '2017-01-01', '2085-12-31'
FROM (
    SELECT * FROM DeltaListingDim
    EXCEPT
    SELECT listing_id, property_type, room_type, num_accommodates,num_bedrooms, num_bathrooms, listing_price
    FROM ListingDim) Delta;
GO

----- code to check if the new/changed records are inserted into listing dim table
SELECT* FROM ListingDim WHERE listing_id in (4180905,8578023, 9061048, 7603457)
 
------------------- SCD 1: update host dim table ---------------------

MERGE HostDim AS Target
USING DeltaHostDim AS Source
ON Source.host_id = Target.host_id 
-- For Inserts
WHEN NOT MATCHED BY Target THEN
INSERT (host_name, host_in_months, host_is_superhost,
 host_listings_count, host_identity_verified)
VALUES (Source.host_name, Source.host_in_months, 
Source.host_is_superhost, Source.host_listings_count, 
Source.host_identity_verified)
-- For Updates
WHEN MATCHED THEN UPDATE SET
Target.host_name = Source.host_name,
Target.host_in_months = Source.host_in_months,
Target.host_is_superhost = Source.host_is_superhost,
Target.host_listings_count = Source.host_listings_count,
Target.host_identity_verified = Source.host_identity_verified;

-- code to check if the new/changed records are updated in host dim table
(SELECT* FROM HostDim WHERE host_id in (SELECT host_id FROM DeltaHostDim))


------------------- SCD 1: update location dim table ---------------------

MERGE LocationDim AS Target
USING DeltaLocationDim AS Source
ON Source.neighbourhood = Target.neighbourhood AND Source.district = Target.district
-- For Inserts
WHEN NOT MATCHED BY Target THEN
INSERT (neighbourhood, district, city, state, country)
VALUES (Source.neighbourhood, Source.district, Source.city, 
Source.state, Source.country)
-- For Updates
WHEN MATCHED THEN UPDATE SET
Target.neighbourhood = Source.neighbourhood,
Target.district = Source.district,
Target.city = Source.city,
Target.state = Source.state,
Target.country = Source.country;

--------------------SCD 0: update date dim table ---------------------

MERGE DateDim AS Target
USING DeltaDateDim AS Source
ON Source.date = Target.date
-- For Inserts
WHEN NOT MATCHED BY Target THEN
INSERT (date, year, month, year_month, quarter, week, day, is_public_holiday)
VALUES (Source.date, Source.year, Source.month, Source.year_month, 
    Source.quarter, Source.week, Source.day, Source.is_public_holiday);

---- Code to check if the new/changed records are inserted in date dim table
SELECT * FROM DateDim
WHERE date not in (SELECT date FROM DeltaDateDim)

------------------- SCD 0: update month dim table ---------------------
MERGE MonthDim AS Target
USING DeltaMonthDim AS Source
ON Source.month_year = Target.month_year
-- For Inserts
WHEN NOT MATCHED BY Target THEN
INSERT (month_year, year, month, year_month, quarter)
VALUES (Source.month_year, Source.year, Source.month, Source.year_month, 
    Source.quarter);

SELECT * FROM MONTHDIM
WHERE month_year not in (SELECT month_year FROM DeltaMonthDim)


-------------- Delta update Booking fact table ------------------------------
SELECT * FROM DeltaBookingStaging


INSERT INTO BookingFact(listing_dim_id, host_dim_id, date_dim_id, available, price_per_guest, price, review_scores_value)
SELECT l.listing_dim_id, h.host_dim_id, d.date_dim_id, b.available,
CASE 
WHEN b.price= 0 THEN listing_price/l.num_accommodates
ELSE b.price/l.num_accommodates
END AS price_per_guest,
CASE 
WHEN b.price= 0 THEN listing_price
ELSE b.price/l.num_accommodates
END AS price,
b.review_scores_value
FROM DeltaBookingStaging b
LEFT JOIN HostDim h ON b.host_id = h.host_id
LEFT JOIN DateDim d ON b.booking_date = d.date
LEFT JOIN ListingDim l ON b.listing_id = l.listing_id
WHERE l.listing_dim_id IN(SELECT l.listing_dim_id
FROM ListingDim l
WHERE l.current_flag =1)

---- confirm if the new/changed records refer to new listing dim records
SELECT b.listing_dim_id, l.listing_id, l.room_type,l.current_flag, l.effective_timestamp, l.expire_timestamp
FROM BookingFact b
JOIN ListingDim l ON b.listing_dim_id = l.listing_dim_id
WHERE l.listing_id IN (4180905,8578023, 9061048, 7603457)
AND b.date_dim_id IN (364, 365, 366, 367)

------------- Business Questions -----------------------------

---Business Question 1: For every property type, what is the average price per guest in every quarter of 2016?

SELECT property_type, 
    format([1], '$0.00') as [Q1], 
    format([2], '$0.00') as [Q2],
    format([3], '$0.00') as [Q3],
    format([4], '$0.00') as [Q4]
 FROM(
    SELECT l.property_type, d.quarter, price_per_guest
    FROM BookingFact b
    JOIN DateDim d ON b.date_dim_id = d.date_dim_id
    JOIN (SELECT listing_dim_id, property_type
        FROM ListingDim
        WHERE current_flag = 1) l ON b.listing_dim_id = l.listing_dim_id
    WHERE d.year = 2016) listing_detail
PIVOT(
    AVG(price_per_guest) 
    FOR quarter IN ([1],[2],[3],[4])
    ) AS pvt
 

---Business Question 2: 
--- How does the review score, occupancy, avg price vary by host_is_superhost for the year 2016?


SELECT 
h.host_is_superhost, 
FORMAT(COUNT(CASE WHEN b.available = 0 THEN 1 ELSE NULL END)/(COUNT(b.available)*1.0), 'P2') AS Avg_OccupancyRate,
FORMAT(AVG(price), 'C2') AS Avg_Price,
FORMAT(AVG(review_scores_value), '0.00')AS Avg_ReviewScore
FROM BookingFact b
JOIN HostDim h ON b.host_dim_id = h.host_dim_id
GROUP BY  h.host_is_superhost
ORDER BY  h.host_is_superhost


