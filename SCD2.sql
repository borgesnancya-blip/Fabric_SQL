/*
===============================================================================
PROYECTO: Arquitectura de Datos en Microsoft Fabric (DP-600)
DESCRIPCIÓN: Implementación de un modelo de Estrellas con SCD Tipo 2.
AUTOR: Nancy - Data Analytics Engineer
FECHA: Mayo 2026

NOTAS TÉCNICAS IMPORTANTES (Best Practices):
1. SCD TIPO 2 (HISTÓRICO): Se agregaron columnas ValidFrom, ValidTo y IsCurrent 
   para rastrear cambios en los atributos de los clientes a lo largo del tiempo.
   
2. IDEMPOTENCIA: Uso de IF OBJECT_ID para asegurar que el script sea re-ejecutable.

3. LÓGICA DE CARGA: El procedimiento ahora realiza un UPDATE para cerrar registros 
   anteriores y un INSERT para los nuevos, manteniendo la trazabilidad completa.
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
    
-- DIMENSIÓN CLIENTE CON SCD TIPO 2
IF OBJECT_ID('Sales.Dim_Customer', 'U') IS NULL
    CREATE TABLE Sales.Dim_Customer (
        CustomerKey INT IDENTITY(1,1) NOT NULL, -- Clave subrogada para historial
        CustomerID VARCHAR(255) NOT NULL,
        CustomerName VARCHAR(255) NOT NULL,
        EmailAddress VARCHAR(255) NOT NULL,
        ValidFrom DATETIME NOT NULL,
        ValidTo DATETIME NULL,
        IsCurrent BIT NOT NULL
    );
        
ALTER TABLE Sales.Dim_Customer add CONSTRAINT PK_Dim_Customer PRIMARY KEY NONCLUSTERED (CustomerKey) NOT ENFORCED
GO
    
IF OBJECT_ID('Sales.Dim_Item', 'U') IS NULL
    CREATE TABLE Sales.Dim_Item (
        ItemID VARCHAR(255) NOT NULL,
        ItemName VARCHAR(255) NOT NULL
    );
        
ALTER TABLE Sales.Dim_Item add CONSTRAINT PK_Dim_Item PRIMARY KEY NONCLUSTERED (ItemID) NOT ENFORCED
GO

/* Nota: Recordá reemplazar <your lakehouse name> por el nombre real de tu Lakehouse 
*/
-- CREATE VIEW Sales.Staging_Sales AS SELECT * FROM [Tu_Lakehouse].[dbo].[staging_sales];

GO

CREATE OR ALTER PROCEDURE Sales.LoadDataFromStaging (@OrderYear INT)
AS
BEGIN
    -- 1. SCD TIPO 2: "CERRAR" REGISTROS QUE CAMBIARON
    -- Si el email cambió, el registro actual deja de serlo.
    UPDATE Dim
    SET Dim.ValidTo = GETDATE(),
        Dim.IsCurrent = 0
    FROM Sales.Dim_Customer AS Dim
    INNER JOIN Sales.Staging_Sales AS Stg ON Dim.CustomerID = Stg.CustomerName
    WHERE Dim.IsCurrent = 1 
      AND Dim.EmailAddress <> Stg.EmailAddress;

    -- 2. INSERTAR REGISTROS NUEVOS (O VERSIONES NUEVAS DE LOS QUE CAMBIARON)
    INSERT INTO Sales.Dim_Customer (CustomerID, CustomerName, EmailAddress, ValidFrom, ValidTo, IsCurrent)
    SELECT DISTINCT 
        CustomerName, 
        CustomerName, 
        EmailAddress, 
        GETDATE(), 
        NULL, 
        1
    FROM [Sales].[Staging_Sales]
    WHERE YEAR(OrderDate) = @OrderYear
    AND NOT EXISTS (
        SELECT 1
        FROM Sales.Dim_Customer
        WHERE Sales.Dim_Customer.CustomerID = Sales.Staging_Sales.CustomerName
        AND Sales.Dim_Customer.IsCurrent = 1
    );
        
    -- 3. CARGA DE DIMENSIÓN ITEM (Sigue siendo SCD Tipo 1 para este ejemplo)
    INSERT INTO Sales.Dim_Item (ItemID, ItemName)
    SELECT DISTINCT Item, Item
    FROM [Sales].[Staging_Sales]
    WHERE YEAR(OrderDate) = @OrderYear
    AND NOT EXISTS (
        SELECT 1
        FROM Sales.Dim_Item
        WHERE Sales.Dim_Item.ItemID = Sales.Staging_Sales.Item
    );
        
    -- 4. CARGA DE TABLA DE HECHOS
    INSERT INTO Sales.Fact_Sales (CustomerID, ItemID, SalesOrderNumber, SalesOrderLineNumber, OrderDate, Quantity, TaxAmount, UnitPrice)
    SELECT CustomerName, Item, SalesOrderNumber, CAST(SalesOrderLineNumber AS INT), CAST(OrderDate AS DATE), CAST(Quantity AS INT), CAST(TaxAmount AS FLOAT), CAST(UnitPrice AS FLOAT)
    FROM [Sales].[Staging_Sales]
    WHERE YEAR(OrderDate) = @OrderYear;
END
GO

-- Ejemplo de ejecución
-- EXEC Sales.LoadDataFromStaging 2021
