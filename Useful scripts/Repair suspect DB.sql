DBCC CHECKDB('SANDBOX') WITH no_infomsgs, ALL_ERRORMSGS

EXEC sp_resetstatus 'SANDBOX'; 

ALTER DATABASE SANDBOX SET EMERGENCY 

DBCC checkdb('SANDBOX') 

ALTER DATABASE SANDBOX SET SINGLE_USER WITH ROLLBACK IMMEDIATE 

DBCC CheckDB ('SANDBOX', REPAIR_ALLOW_DATA_LOSS) 

ALTER DATABASE SANDBOX SET MULTI_USER



