--- ==========================================================
-- Análisis Exploratorio de Datos (EDA) - Proyecto Layoffs
-- Base de datos: MySQL 8+
-- Objetivo: Identificar patrones, tendencias y métricas clave sobre despidos masivos (2020-2023)
-- ==========================================================

-- 1. Vista preliminar de los datos limpios
SELECT * FROM layoffs_staging2;

-- 2. Valores extremos: Revisamos máximos para entender la magnitud
-- (Ej: ¿Cuál fue el despido masivo más grande en un solo día? ¿Hubo cierres totales?)
SELECT MAX(total_laid_off) AS maximo_despidos_num, MAX(percentage_laid_off) AS maximo_porcentaje
FROM layoffs_staging2;

-- 3. Análisis de cierres totales (100% de despidos)
-- Ordenamos por fondos recaudados para ver startups grandes que fallaron completamente.
SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC;

-- ----------------------------------------------------------
-- ANÁLISIS TEMPORAL Y DIMENSIONAL
-- ----------------------------------------------------------

-- 4. Rango temporal del dataset
-- Importante para contextualizar (¿Cubre toda la pandemia o se extendiente hasta 2023?)
SELECT MIN(`date`) AS fecha_inicio, MAX(`date`) AS fecha_fin  
FROM layoffs_staging2;

-- 5. Despidos por Empresa (Top Absoluto)
SELECT company, SUM(total_laid_off) AS total_despidos
FROM layoffs_staging2
GROUP BY company
ORDER BY 2 DESC;

-- 6. Despidos por Industria
-- Hipótesis: El sector tecnológico (Consumer, Retail, Crypto) fue el más golpeado.
SELECT industry, SUM(total_laid_off) AS total_despidos
FROM layoffs_staging2
GROUP BY industry
ORDER BY 2 DESC;

-- 7. Despidos por País
-- Hipótesis: Estados Unidos como pais potencia cuenta con mayor cantidad de despido debido a las grandes empresas y su capital
SELECT country, SUM(total_laid_off) AS total_despidos
FROM layoffs_staging2
GROUP BY country
ORDER BY 2 DESC;

-- 8. Despidos por Año
SELECT YEAR(`date`) AS anio, SUM(total_laid_off) AS total_despidos
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY 1 DESC; 

-- ----------------------------------------------------------
-- ANÁLISIS DE TENDENCIAS Y SERIES DE TIEMPO
-- ----------------------------------------------------------

-- 9. Evolución mensual de despidos
SELECT SUBSTRING(`date`, 1, 7) AS `mes`, SUM(total_laid_off) AS total_despidos
FROM layoffs_staging2
WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
GROUP BY `mes`
ORDER BY 1 ASC;

-- 10. Rolling Total (Acumulado progresivo)
-- Permite visualizar la aceleración de la crisis mes a mes.
WITH rolling_total AS (
  SELECT SUBSTRING(`date`, 1, 7) AS `mes`, SUM(total_laid_off) AS total_off 
  FROM layoffs_staging2
  WHERE SUBSTRING(`date`, 1, 7) IS NOT NULL
  GROUP BY `mes`
  ORDER BY 1 ASC
)
SELECT `mes`, 
       total_off, 
       SUM(total_off) OVER (ORDER BY `mes`) AS acumulado_total
FROM rolling_total; 

-- 11. Ranking: Top 5 Empresas con más despidos por Año
-- Usamos DENSE_RANK para manejar empates y reiniciar el ranking cada año.
WITH company_year (company, years, total_laid_off) AS (
  SELECT company, YEAR(`date`), SUM(total_laid_off)
  FROM layoffs_staging2
  GROUP BY company, YEAR(`date`)
), 
Company_year_rank AS (
  SELECT *, 
  DENSE_RANK() OVER (PARTITION BY years ORDER BY total_laid_off DESC) AS Ranking
  FROM company_year
  WHERE years IS NOT NULL
)
SELECT * FROM Company_year_rank
WHERE Ranking <= 5;

-- ==========================================================
-- ANÁLISIS AVANZADO / EXTRA
-- ==========================================================

-- 12. Despidos según la etapa de la empresa
-- Hipótesis: Las empresas en etapas tempranas (Seed, Series A) tienen porcentajes de despido más altos (cierres).
SELECT stage, ROUND(AVG(percentage_laid_off) * 100, 2) AS promedio_porcentaje_despido, SUM(total_laid_off) AS total_personas
FROM layoffs_staging2
GROUP BY stage
ORDER BY 2 DESC;

-- 13. Análisis de "Espalda Financiera" vs Despidos
-- Hipótesis: ¿Tener más fondos recaudados protegió a las empresas o las hizo recortar más?
-- Usamos CASE para categorizar las empresas según su capital levantado.

SELECT 
    CASE 
        WHEN funds_raised_millions < 50 THEN 'Startups Pequeñas (<50M)'
        WHEN funds_raised_millions BETWEEN 50 AND 500 THEN 'Medianas (50-500M)'
        WHEN funds_raised_millions > 500 THEN 'Gigantes / Unicornios (>500M)'
        ELSE 'Sin Datos de Fondos'
    END AS categoria_fondos,
    COUNT(*) AS cantidad_empresas,
    SUM(total_laid_off) AS total_despidos,
    ROUND(AVG(percentage_laid_off) * 100, 2) AS promedio_porcentaje_despido
FROM layoffs_staging2
GROUP BY categoria_fondos
ORDER BY total_despidos DESC;