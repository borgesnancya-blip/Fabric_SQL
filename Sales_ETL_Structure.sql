/*
===============================================================================
PROYECTO: Arquitectura de Datos en Microsoft Fabric (DP-600)
DESCRIPCIÓN: Implementación de un modelo de Estrellas (Fact & Dimensions).
AUTOR: Nancy - Data Analytics Engineer
FECHA: Mayo 2026

NOTAS TÉCNICAS IMPORTANTES (Best Practices):
1. USO DE ESQUEMAS: Se utiliza 'CREATE SCHEMA [Sales]' para organizar los objetos, 
   separando las tablas de negocio del esquema por defecto (dbo).
   
2. INTEGRIDAD DE DATOS (IF NOT EXISTS): El script es "Idempotente". 
   Usa 'IF OBJECT_ID' para verificar si la tabla existe antes de crearla, 
   evitando errores si el script se corre varias veces.

3. CARGA DE DIMENSIONES (SCD Tipo 1): En el Procedimiento Almacenado se utiliza 
   la cláusula 'NOT EXISTS' para asegurar que no se dupliquen Clientes ni ítems. 
   Esto mantiene la "Pureza de los Datos" en la capa Gold.

4. RENDIMIENTO EN FABRIC: Se definen Primary Keys como 'NONCLUSTERED' y 'NOT ENFORCED'.
   Esto es una práctica recomendada en sistemas de almacenamiento masivo (Data Warehouse) 
   para priorizar la velocidad de carga (ETL) sin sobrecargar el motor de base de datos.
===============================================================================
*/



CREATE SCHEMA [Sales]
 GO
        
 IF OBJECT_ID('Sales.Fact_Sales', 'U') IS NULL
 	CREATE TABLE Sales.Fact_Sales (
 		CustomerID VARCHAR(255) NOT NULL,
 		ItemID VARCHAR(255) NOT NULL,
 		SalesOrderNumber VARCHAR(30),
 		SalesOrderLineNumber INT,
 		OrderDate DATE,
 		Quantity INT,
 		TaxAmount FLOAT,
 		UnitPrice FLOAT
 	);
    
 IF OBJECT_ID('Sales.Dim_Customer', 'U') IS NULL
     CREATE TABLE Sales.Dim_Customer (
         CustomerID VARCHAR(255) NOT NULL,
         CustomerName VARCHAR(255) NOT NULL,
         EmailAddress VARCHAR(255) NOT NULL
     );
        
 ALTER TABLE Sales.Dim_Customer add CONSTRAINT PK_Dim_Customer PRIMARY KEY NONCLUSTERED (CustomerID) NOT ENFORCED
 GO
    
 IF OBJECT_ID('Sales.Dim_Item', 'U') IS NULL
     CREATE TABLE Sales.Dim_Item (
         ItemID VARCHAR(255) NOT NULL,
         ItemName VARCHAR(255) NOT NULL
     );
        
 ALTER TABLE Sales.Dim_Item add CONSTRAINT PK_Dim_Item PRIMARY KEY NONCLUSTERED (ItemID) NOT ENFORCED
 GO




 CREATE VIEW Sales.Staging_Sales
 AS
 SELECT * FROM [<your lakehouse name>].[dbo].[staging_sales];

 CREATE OR ALTER PROCEDURE Sales.LoadDataFromStaging (@OrderYear INT)
 AS
 BEGIN
 	-- Load data into the Customer dimension table
     INSERT INTO Sales.Dim_Customer (CustomerID, CustomerName, EmailAddress)
     SELECT DISTINCT CustomerName, CustomerName, EmailAddress
     FROM [Sales].[Staging_Sales]
     WHERE YEAR(OrderDate) = @OrderYear
     AND NOT EXISTS (
         SELECT 1
         FROM Sales.Dim_Customer
         WHERE Sales.Dim_Customer.CustomerName = Sales.Staging_Sales.CustomerName
         AND Sales.Dim_Customer.EmailAddress = Sales.Staging_Sales.EmailAddress
     );
        
     -- Load data into the Item dimension table
     INSERT INTO Sales.Dim_Item (ItemID, ItemName)
     SELECT DISTINCT Item, Item
     FROM [Sales].[Staging_Sales]
     WHERE YEAR(OrderDate) = @OrderYear
     AND NOT EXISTS (
         SELECT 1
         FROM Sales.Dim_Item
         WHERE Sales.Dim_Item.ItemName = Sales.Staging_Sales.Item
     );
        
     -- Load data into the Sales fact table
     INSERT INTO Sales.Fact_Sales (CustomerID, ItemID, SalesOrderNumber, SalesOrderLineNumber, OrderDate, Quantity, TaxAmount, UnitPrice)
     SELECT CustomerName, Item, SalesOrderNumber, CAST(SalesOrderLineNumber AS INT), CAST(OrderDate AS DATE), CAST(Quantity AS INT), CAST(TaxAmount AS FLOAT), CAST(UnitPrice AS FLOAT)
     FROM [Sales].[Staging_Sales]
     WHERE YEAR(OrderDate) = @OrderYear;
 END


 EXEC Sales.LoadDataFromStaging 2021

 SELECT c.CustomerName, SUM(s.UnitPrice * s.Quantity) AS TotalSales
 FROM Sales.Fact_Sales s
 JOIN Sales.Dim_Customer c
 ON s.CustomerID = c.CustomerID
 WHERE YEAR(s.OrderDate) = 2021
 GROUP BY c.CustomerName
 ORDER BY TotalSales DESC;

 SELECT i.ItemName, SUM(s.UnitPrice * s.Quantity) AS TotalSales
 FROM Sales.Fact_Sales s
 JOIN Sales.Dim_Item i
 ON s.ItemID = i.ItemID
 WHERE YEAR(s.OrderDate) = 2021
 GROUP BY i.ItemName
 ORDER BY TotalSales DESC;

 WITH CategorizedSales AS (
 SELECT
     CASE
         WHEN i.ItemName LIKE '%Helmet%' THEN 'Helmet'
         WHEN i.ItemName LIKE '%Bike%' THEN 'Bike'
         WHEN i.ItemName LIKE '%Gloves%' THEN 'Gloves'
         ELSE 'Other'
     END AS Category,
     c.CustomerName,
     s.UnitPrice * s.Quantity AS Sales
 FROM Sales.Fact_Sales s
 JOIN Sales.Dim_Customer c
 ON s.CustomerID = c.CustomerID
 JOIN Sales.Dim_Item i
 ON s.ItemID = i.ItemID
 WHERE YEAR(s.OrderDate) = 2021
 ),
 RankedSales AS (
     SELECT
         Category,
         CustomerName,
         SUM(Sales) AS TotalSales,
         ROW_NUMBER() OVER (PARTITION BY Category ORDER BY SUM(Sales) DESC) AS SalesRank
     FROM CategorizedSales
     WHERE Category IN ('Helmet', 'Bike', 'Gloves')
     GROUP BY Category, CustomerName
 )
 SELECT Category, CustomerName, TotalSales
 FROM RankedSales
 WHERE SalesRank = 1
 ORDER BY TotalSales DESC;
