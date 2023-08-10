-- Creates a View that can be called on and displays all columns between all 5 tables
CREATE VIEW All_Data_View AS
SELECT 
    p.Product_ID AS Product_ID, 
    p.Product_Name AS Product_Name,
    c.Category_ID AS Category_ID,
    c.Category_Name AS Category_Name,
    oi.Order_Item_ID AS Order_Item_ID,
    oi.Quantity AS Order_Item_Quantity,
    oi.Unit_Price AS Order_Item_Unit_Price,
    o.Order_ID AS Order_ID,
    o.Customer_ID AS Customer_ID,
    o.Order_Date AS Order_Date,
    o.Total_Amount AS Order_Total_Amount,
    cust.First_Name AS Customer_First_Name,
    cust.Last_Name AS Customer_Last_Name,
    cust.Email AS Customer_Email,
    cust.Country AS Country
FROM Products p
JOIN Categories c ON p.Category_ID = c.Category_ID
JOIN Order_Items oi ON p.Product_ID = oi.Product_ID
JOIN Orders o ON oi.Order_ID = o.Order_ID
JOIN Customers cust ON o.Customer_ID = cust.Customer_ID;


-- Runs View query that was just created
SELECT * FROM All_Data_View;


-- Lists all products with their category names
SELECT p.Product_Name, c.Category_Name
FROM Products p
JOIN Categories c ON p.Category_ID = c.Category_ID;


-- Question 1. What are the products with the highest revenue and the number of units sold? 
-- Calculates the total revenue and quantity for each product sold
SELECT p.Product_Name, 
       FORMAT(ISNULL(SUM(CONVERT(NUMERIC(18, 2), oi.Quantity) * CONVERT(NUMERIC(18, 2), oi.Unit_Price)), 0), 'N2') AS Total_Revenue,
       ISNULL(SUM(oi.Quantity), 0) AS Total_Quantity_Sold
FROM Products p
LEFT JOIN Order_Items oi ON p.Product_ID = oi.Product_ID
GROUP BY p.Product_Name
ORDER BY ISNULL(SUM(CONVERT(NUMERIC(18, 2), oi.Quantity) * CONVERT(NUMERIC(18, 2), oi.Unit_Price)), 0) DESC;


-- Question 2. What are the products that have we have been selling the most of? 
-- Finds the top selling products by quantity (with their total revenue)
-- CTE Example
WITH ProductSales AS (
    SELECT p.Product_Name, 
           SUM(oi.Quantity) AS Total_Quantity_Sold,
           SUM(CONVERT(NUMERIC(18, 2), oi.Quantity) * CONVERT(NUMERIC(18, 2), oi.Unit_Price)) AS Total_Revenue
    FROM Products p
    JOIN Order_Items oi ON p.Product_ID = oi.Product_ID
    GROUP BY p.Product_Name
)
SELECT Product_Name, Total_Quantity_Sold, 
       FORMAT(Total_Revenue, 'N2') AS Total_Revenue
FROM ProductSales
ORDER BY Total_Quantity_Sold DESC;


-- Question 3. What are the top 3 categories that have the greatest number of products sold as well as the top product from each category? 
-- Finds the top 3 categories that have the highest number of products sold, as well as the top selling product from that category
-- Top, Join example
SELECT TOP 3
       c.Category_Name,
       CONVERT(INT, SUM(CONVERT(BIGINT, oi.Quantity))) AS Total_Quantity_Sold,
       FORMAT(SUM(CONVERT(NUMERIC(18, 2), oi.Quantity) * CONVERT(NUMERIC(18, 2), oi.Unit_Price)), 'N2') AS Total_Revenue,
       MAX(p.Product_Name) AS Top_Selling_Product
FROM Categories c
JOIN Products p ON c.Category_ID = p.Category_ID
JOIN Order_Items oi ON p.Product_ID = oi.Product_ID
GROUP BY c.Category_Name
ORDER BY Total_Quantity_Sold DESC;


-- Question 4. How many orders did each customer make and what is their average order amount? 
-- Counts the number of orders placed by each customer and the average order amount
SELECT
    c.Customer_ID,
    c.First_Name,
    c.Last_Name,
    COUNT(o.Order_ID) AS OrderCount,
    AVG(ISNULL(o.Total_Amount, 0)) AS Avg_Order_Amount
FROM Customers c
LEFT JOIN Orders o ON c.Customer_ID = o.Customer_ID
GROUP BY
    c.Customer_ID,
    c.First_Name,
    c.Last_Name
ORDER BY OrderCount DESC;


-- Question 5. What is the total amount of units sold, the total revenue made, the total number of orders and the average order amount? 
-- Calculates the total number of products sold, total revenue made, total orders made and the average amount spend per order
WITH ProductCounts AS (
    SELECT COUNT(Product_ID) AS Number_Of_Products_Sold
    FROM Order_Items
),
TotalRevenue AS (
    SELECT FORMAT(SUM(CONVERT(BIGINT, oi.Quantity) * CONVERT(NUMERIC(18, 2), oi.Unit_Price)), 'N2') AS Total_Revenue
    FROM Order_Items oi
),
TotalOrders AS (
    SELECT COUNT(DISTINCT Order_ID) AS Total_Number_Of_Orders
    FROM Order_Items
),
OrderAmounts AS (
    SELECT SUM(CAST(Quantity AS NUMERIC(18, 2)) * CAST(Unit_Price AS NUMERIC(18, 2))) AS TotalOrderAmount
    FROM Order_Items
    GROUP BY Order_ID
)
SELECT 
    (SELECT Number_Of_Products_Sold FROM ProductCounts) AS Number_Of_Products_Sold,
    (SELECT Total_Revenue FROM TotalRevenue) AS Total_Revenue,
    (SELECT Total_Number_Of_Orders FROM TotalOrders) AS Total_Number_Of_Orders,
    (SELECT AVG(TotalOrderAmount) FROM OrderAmounts) AS Average_Order_Amount;


-- Question 6. What does the revenue for each category look like week by week?  
-- Creates pivot table that shows the week by week breakdown of how each category's revenue performed (Null values mean there was no revenue for that week)
-- Dynamic SQL Example
DECLARE @StartDate DATE = '2023-08-01';
DECLARE @EndDate DATE = '2023-08-31';
DECLARE @SQL NVARCHAR(MAX);

SET @SQL = N'
SELECT *
FROM (
    SELECT cat.Category_Name,
           ''Week '' + CAST(DATEPART(WEEK, o.Order_Date) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, o.Order_Date), 0)) + 1 AS NVARCHAR(10)) AS [Week],
           FORMAT(SUM(CONVERT(NUMERIC(18, 2), COALESCE(oi.Quantity, 0) * COALESCE(oi.Unit_Price, 0))), ''0.00'') AS Total_Revenue
    FROM Categories cat
    LEFT JOIN Products p ON cat.Category_ID = p.Category_ID
    LEFT JOIN Order_Items oi ON p.Product_ID = oi.Product_ID
    LEFT JOIN Orders o ON oi.Order_ID = o.Order_ID
                        AND o.Order_Date >= @StartDate AND o.Order_Date <= @EndDate
    GROUP BY cat.Category_Name, DATEPART(WEEK, o.Order_Date) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, o.Order_Date), 0)) + 1
) AS PivotSource
PIVOT (
    MAX(Total_Revenue)
    FOR [Week] IN ([Week 1], [Week 2], [Week 3], [Week 4], [Week 5])
) AS PivotTable';

EXEC sp_executesql @SQL, N'@StartDate DATE, @EndDate DATE', @StartDate, @EndDate;


-- Question 7. What are the top 3 customers with the highest total order amount, along with the details of their top 3 orders (by order amount) and the names of the products 
-- they purchased in those orders?  

-- Finds the top 3 customers with the highest total order amount, focusing on their highest total order amounts and the names of the products they purchased with those orders
-- Example of Common Table Expressions (CTEs), Window Functions, Self-Joins, Joins, Aggregations, Filtering and Sorting, Rank

-- Step 1: Calculate the total order amount for each customer and rank them by total order amount.
-- This CTE creates a list of ranked customers based on their total order amount.
WITH Ranked_Customers AS (
  SELECT
    c.Customer_ID,
    c.First_Name,
    c.Last_Name,
    SUM(o.Total_Amount) AS Total_Order_Amount,
    ROW_NUMBER() OVER (ORDER BY SUM(o.Total_Amount) DESC) AS rank
  FROM Customers c
  LEFT JOIN Orders o ON c.Customer_ID = o.Customer_ID
  GROUP BY c.Customer_ID, c.First_Name, c.Last_Name, c.Email
)

-- Step 2: Calculate the ranked orders for each customer, including the order date, total amount, and product name.
-- This CTE creates a list of ranked orders for each customer, ordered by total amount.
, Ranked_Orders AS (
  SELECT
    o.Order_ID,
    o.Customer_ID,
    o.Order_Date,
    o.Total_Amount,
    p.Product_Name,
    ROW_NUMBER() OVER (PARTITION BY o.Customer_ID ORDER BY o.Total_Amount DESC) AS Order_Rank
  FROM Orders o
  INNER JOIN Order_Items oi ON o.Order_ID = oi.Order_ID
  INNER JOIN Products p ON oi.Product_ID = p.Product_ID
)

-- Step 3: Get the latest order date for each ranked customer.
-- This CTE finds the latest order date for each customer in the Ranked_Customers CTE.
, Latest_Order AS (
  SELECT
    rc.Customer_ID,
    MAX(ro.Order_Date) AS Latest_Order_Date
  FROM Ranked_Customers rc
  INNER JOIN Ranked_Orders ro ON rc.Customer_ID = ro.Customer_ID
  WHERE rc.Rank <= 3 AND ro.Order_Rank <= 3
  GROUP BY rc.Customer_ID
)

-- Final Step: Combine the ranked customers, ranked orders, and latest order information.
-- This final query step retrieves the desired output by joining the three CTEs and filtering the results.
SELECT
  rc.Rank,
  rc.Customer_ID,
  rc.First_Name,
  rc.Last_Name,
  ro.Order_ID,
  ro.Order_Date,
  ro.Total_Amount,
  ro.Product_Name
FROM Ranked_Customers rc
INNER JOIN Ranked_Orders ro ON rc.Customer_ID = ro.Customer_ID
INNER JOIN Latest_Order lo ON rc.Customer_ID = lo.Customer_ID
WHERE rc.Rank <= 3 AND ro.Order_Rank <= 3
ORDER BY rc.Rank, ro.Order_Rank;


-- Question 8. Globally, what does our revenue and customer base look like?
-- Calculates the total number of customer and revenue from each country
SELECT
    cust.Country,
    COUNT(DISTINCT cust.Customer_ID) AS Number_Of_Customers,
    FORMAT(SUM(CONVERT(NUMERIC(18, 2), oi.Quantity) * CONVERT(NUMERIC(18, 2), oi.Unit_Price)), 'N2') AS Total_Revenue
FROM Customers cust
LEFT JOIN Orders o ON cust.Customer_ID = o.Customer_ID
LEFT JOIN Order_Items oi ON o.Order_ID = oi.Order_ID
GROUP BY cust.Country
ORDER BY SUM(CONVERT(NUMERIC(18, 2), oi.Quantity) * CONVERT(NUMERIC(18, 2), oi.Unit_Price)) DESC;



