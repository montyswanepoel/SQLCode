-- T-SQL generator for sp_configure
--
-- Create by Rudy Panigas Sept 20, 2010
--
-- Purpose of this code is to create a T-SQL output that
-- can be execute on SQL Server (2005 and higher) to recofigure
-- the SQL server as compared to the settings on which you 
-- have executed this code from.

-- Good for rebuilding a SQL server from bare metal, UAT and/or
-- development environments

USE master
GO

 

CREATE TABLE #SQLSrvValues
(
 [name] [varchar](48) NOT NULL,
 [description] [varchar](256) NOT NULL,
 [value] [sql_variant] NOT NULL,
 [minimum] [sql_variant] NOT NULL,
 [maximum] [sql_variant] NOT NULL,
 [value_in_use] [sql_variant] NOT NULL,
) ON [PRIMARY]

GO

 

EXEC ('INSERT INTO #SQLSrvValues
 ([name]
 ,[description]
 ,[value] 
 ,[minimum] 
 ,[maximum] 
 ,[value_in_use])
 SELECT 
 [name]
 ,[description]
 ,[value] 
 ,[minimum] 
 ,[maximum] 
 ,[value_in_use]
 FROM master.sys.configurations')

PRINT ''
PRINT '-- Execute code below to reconfigure SQL server'
PRINT 'USE MASTER'
PRINT 'GO'

 

DECLARE @ValueName VARCHAR (48)
 ,@CurValue SQL_VARIANT

DECLARE SQLValues CURSOR FOR SELECT [name], [value_in_use] FROM #SQLSrvValues
OPEN SQLValues
 FETCH NEXT FROM SQLValues INTO @ValueName, @CurValue
 
 WHILE @@FETCH_STATUS = 0
 BEGIN
 
 /* Creates T-SQL code to make the changes to the SQL server setting*/ 
 PRINT 'EXEC sp_configure '''+ @Valuename +''', '''+CONVERT(VARCHAR(20),@CurValue)+ ''';'
 PRINT 'RECONFIGURE WITH OVERRIDE;'
 
 
FETCH NEXT FROM SQLValues INTO @ValueName, @CurValue
END

CLOSE SQLValues
DEALLOCATE SQLValues
DROP TABLE #SQLSrvValues
GO

