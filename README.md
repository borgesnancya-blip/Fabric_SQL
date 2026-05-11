# 🚀 Fabric SQL Library - DP-600 Journey

¡Este es mi repositorio de aprendizaje y práctica para la certificación **DP-600: Microsoft Fabric Analytics Engineer**!

Este espacio está dedicado a documentar mi progreso y a servir como biblioteca de scripts de **T-SQL** y **PySpark** optimizados para arquitecturas de datos modernas en **Microsoft Fabric**.

---

## 🛠️ Contenido del Repositorio
Aquí encontrarás la organización de mi ecosistema de datos, desde el modelado relacional hasta el procesamiento masivo con Spark:

### 📂 [Ingeniería de Datos con Apache Spark]
* **[Análisis SQL y Visualización Dinámica en Spark](./Ingenieria_Datos_Spark/analisis_ventas.ipynb)**: Cuaderno interactivo con consultas de agregación y gráficos de tendencia (Revenue/Orders).
* **[Modelado y Particionado de Ventas con PySpark](./Ingenieria_Datos_Spark/modelado_pyspark.ipynb)**: Lógica de ingesta con esquemas definidos (`StructType`) y optimización de almacenamiento mediante `partitionBy("Year")`.

### 📂 [Modelado de Tablas y ETL con SQL]
Aquí encontrarás los scripts fundamentales para la creación de un Data Warehouse con arquitectura de medalla:

* **[Estructura_ETL_Ventas.sql](./Modelado_Tablas_SQL/Estructura_ETL_Ventas.sql)**
    * Implementación de un **Esquema de Estrella** (Fact & Dimensions).
    * Lógica de carga **SCD Tipo 1**: Ideal para mantener datos maestros actualizados mediante la técnica de "ignorar duplicados" (`NOT EXISTS`).
    * Definición de restricciones (Constraints) optimizadas para el motor de Fabric.

* **[SCD2.sql](./Modelado_Tablas_SQL/SCD2.sql)**
    * Lógica avanzada de **Slowly Changing Dimensions (Tipo 2)**.
    * Control de versiones mediante columnas de validez (`ValidFrom`, `ValidTo`) y bandera de estado (`IsCurrent`).
    * Gestión de **claves subrogadas** e integridad histórica de los datos.

---

## 🎯 Objetivo Profesional
Mi meta es dominar el ecosistema de **Microsoft Fabric**, integrando mi experiencia previa **Power BI** con capacidades avanzadas de **Ingeniería de Datos**. 

> *"Este repositorio es el testimonio de mi transición de Analista a Analytics Engineer."*

---
✨ **Conectemos:** Si estás interesado en el mundo de los datos y Fabric, ¡sentite libre de revisar mi código!
