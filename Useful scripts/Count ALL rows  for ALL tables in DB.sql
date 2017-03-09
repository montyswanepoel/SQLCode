CREATE TABLE #temp ( 
  table_name    SYSNAME, 
  row_count     INT, 
  reserved_size VARCHAR(50), 
  data_size     VARCHAR(50), 
  index_size    VARCHAR(50), 
  unused_size   VARCHAR(50)) 

SET nocount  ON 

INSERT #temp 
EXEC Sp_msforeachtable 
  'sp_spaceused ''?''' 

SELECT   a.table_name, 
         a.row_count, 
         Count(* ) AS col_count, 
         a.data_size 
FROM     #temp a 
         INNER JOIN information_schema.columns b 
           ON a.table_name COLLATE database_default = b.table_name COLLATE database_default 
GROUP BY a.table_name, 
         a.row_count, 
         a.data_size 
ORDER BY Cast(Replace(a.data_size,' KB','') AS INTEGER) DESC 

DROP TABLE #temp 