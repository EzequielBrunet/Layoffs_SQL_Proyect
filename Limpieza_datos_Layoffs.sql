-- ==========================================================
-- Limpieza de Datos (Data Cleaning) - Proyecto Layoffs
-- Base de datos: MySQL 8+
-- Objetivo: Preparar una tabla lista para análisis (sin duplicados, estandarizada y consistente)
-- Pasos:
-- 1. Eliminar duplicados
-- 2. Estandarizar los datos (ortografía, formatos)
-- 3. Manejar valores nulos o en blanco
-- 4. Eliminar columnas innecesarias y crear tabla final
-- ==========================================================

- ----------------------------------------------------------
-- Inspección inicial de los datos crudos (Raw Data)
-- ----------------------------------------------------------
SELECT *
FROM layoffs;

-- ==========================================================
-- 0. Creación de la tabla de preparación (Staging)
-- Buenas prácticas: No modificamos la tabla original.
-- ==========================================================

CREATE TABLE layoffs_staging
LIKE layoffs;

INSERT INTO layoffs_staging
SELECT *
FROM layoffs;

-- ==========================================================
-- 1. Eliminación de duplicados
-- Como no tenemos un ID único, generamos uno artificial con ROW_NUMBER
-- ==========================================================

-- Inspección visual de duplicados
SELECT *,
ROW_NUMBER() OVER (
  PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions
  ORDER BY company
) AS row_num
FROM layoffs_staging;

-- Creamos una segunda tabla staging (staging2) que incluya la columna row_num
CREATE TABLE layoffs_staging2 AS
WITH duplicate_cte AS (
  SELECT *,
  ROW_NUMBER() OVER (
    PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions
    ORDER BY company
  ) AS row_num
  FROM layoffs_staging
)
SELECT *
FROM duplicate_cte;

-- Verificamos cuántos duplicados existen
SELECT COUNT(*) AS cantidad_duplicados
FROM layoffs_staging2
WHERE row_num > 1;

-- Desactivamos modo seguro temporalmente para permitir el borrado
SET SQL_SAFE_UPDATES = 0;

-- Borramos los duplicados
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

SELECT COUNT(*) AS filas_post_delete
FROM layoffs_staging2;

-- ==========================================================
-- 2. Estandarización de datos
-- ==========================================================

-- Eliminamos espacios en blanco extra al inicio y final en nombres de empresas
UPDATE layoffs_staging2
SET company = TRIM(company)
WHERE company IS NOT NULL;

-- Unificamos industrias con nombres similares (ej: Crypto = Crypto Currency)
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry IS NOT NULL
  AND TRIM(industry) LIKE 'Crypto%';

-- Estandarizamos países: quitamos espacios y signos de puntuación finales erróneos (ej: "United States.")
UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM TRIM(country))
WHERE country IS NOT NULL;

-- Formateo de fechas: Convertimos de texto (string) a formato DATE real
UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

-- Modificamos la estructura de la columna para que sea tipo DATE
ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- ==========================================================
-- 3.  Valores Nulos y Blancos
-- ==========================================================

-- Identificamos filas donde no hay datos clave de despidos
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- Revisamos industrias nulas o vacías
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
   OR TRIM(industry) = '';

-- Estandarizamos los espacios vacíos ('') a NULL para facilitar el uso de los JOINS
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry IS NOT NULL
  AND TRIM(industry) = '';

-- Buscamos si la misma empresa tiene la industria completa en otra fila
SELECT t1.company, t1.industry AS industria_nula, t2.industry AS industria_relleno
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Ejecutamos la actualización cruzando la tabla consigo misma
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Eliminación de datos inútiles:
-- Borramos filas donde no tenemos ni el total ni el porcentaje de despidos,
-- ya que no sirven para el análisis numérico.
DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND (percentage_laid_off IS NULL OR TRIM(percentage_laid_off) = '');

SELECT COUNT(*) AS filas_finales
FROM layoffs_staging2;

-- ==========================================================
-- 4. Limpieza final y Exportación
-- ==========================================================

-- Eliminamos la columna auxiliar row_num que ya no necesitamos
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;