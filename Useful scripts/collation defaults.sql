/***
    The below script changes the collation of the columns
    to the database default collation. 
    Please note that the collation of the dependant columns, 
    like Foreign keys, Indexes and check constraints cannot be changed.
    For these columns we need to change it manually
    
***/
set nocount on

Declare 
    @SQL        varchar(max),
    @tablename    varchar(200),
    @columnname    varchar(200),
    @collationname    nvarchar(200),
    @typename    varchar(50),
    @maxlength    varchar(50),
    @precision    int,
    @scale        int

/********* Enter Database name here *****/
select @collationname = convert(nvarchar(200),(DATABASEPROPERTYEX('<<DatabaseName>>','Collation')))

/******** Declaring table variable ******/
declare @COLname Table 
(
    Collation_name    varchar(100),
    Column_name    varchar(200),
    Table_name    varchar(200),
    [Type_name]    varchar(100),
    isuserdefined    int,
    isassemblytype    int,
    max_length    bigint,
    [precision]    int,
    scale        int,
    [type]        char(3),
    iobjid        int
)
/******* inserting data into Table variable ****/
insert into @COLname
select    a.collation_name, 
    a.name as Column_Name, 
    b.name as Table_name,
    t.name AS TypeName,
    t.is_user_defined,
    t.is_assembly_type,
    a.max_length,
    a.precision,
    a.scale,
    o.type,
    i.object_id
from sys.columns a ,sys.tables b, sys.types t, sys.objects o , sys.indexes i
    where a.object_id = b.object_id 
    and t.user_type_id = a.user_type_id
    and a.object_id = o.object_id 
    and a.object_id = i.object_id
    and a.collation_name != @collationname    -- Checking for different collation
    and o.type not in('PK','P','FN','S')    -- Checking for depended columns
    and i.type != 1                -- Checking for indexes
    order by Table_name


while(select COUNT(1) from @COLname) > 0
    Begin
    select    TOP 1 
        @tablename = Table_name ,
        @columnname = Column_name,
        @typename = [Type_name],
        @maxlength = max_length,
        @precision = precision,
        @scale = scale
    from    @COLname
    select @SQL =    'alter table '+ @tablename +CHAR(13)+
            'alter column '+ @columnname +CHAR(32)+@typename+CHAR(40)+@maxlength+CHAR(41)+
            ' COLLATE '+@collationname+CHAR(13)
        --Exec(@SQL)
        PRINT @SQL
        delete from @COLname where Table_name = @tablename and Column_name = @columnname
        
    end


---- End of the script 

