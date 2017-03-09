USE master;
GO
IF EXISTS ( SELECT  *
            FROM    master.dbo.sysobjects
            WHERE   id = OBJECT_ID('dbo.sp_who3') )
    DROP PROCEDURE dbo.sp_who3;
GO

/*====================================================================
-- Mircea Anton Nita - 2010
-- https://www.mcpvirtualbusinesscard.com/VBCServer/Mircea/card
======================================================================*/
CREATE PROCEDURE dbo.sp_who3
    @dbname sysname = NULL ,
    @loginame sysname = NULL
AS
    SET NOCOUNT ON;

    DECLARE @retcode INT ,
        @sidlow VARBINARY(85) ,
        @sidhigh VARBINARY(85) ,
        @sid1 VARBINARY(85) ,
        @spidlow INT ,
        @spidhigh INT ,
        @seldbid VARCHAR(10) ,
        @charMaxLenLoginName VARCHAR(24) ,
        @charMaxLenDBName VARCHAR(24) ,
        @charMaxLenCPUTime VARCHAR(10) ,
        @charMaxLenDiskIO VARCHAR(10) ,
        @charMaxLenHostName VARCHAR(24) ,
        @charMaxLenProgramName VARCHAR(10) ,
        @charMaxLenLastBatch VARCHAR(10) ,
        @charMaxLenCommand VARCHAR(10) ,
        @charsidlow VARCHAR(85) ,
        @charsidhigh VARCHAR(85) ,
        @charspidlow VARCHAR(11) ,
        @charspidhigh VARCHAR(11) ,
        @command VARCHAR(8000);

-- set defaults
    SET @retcode = 0;
    SET @sidlow = CONVERT(VARBINARY(85), ( REPLICATE(CHAR(0), 85) ));
    SET @sidhigh = CONVERT(VARBINARY(85), ( REPLICATE(CHAR(1), 85) ));
    SET @spidlow = 0;
    SET @spidhigh = 32767;

    IF ( @dbname IS NOT NULL )
        AND ( ( SELECT TOP 1
                        name
                FROM    master.dbo.sysdatabases WITH ( NOLOCK )
                WHERE   name LIKE '%' + @dbname + '%'
              ) IS NULL )
        BEGIN
            PRINT '-- No database could be located for filter "%' + @dbname
                + '%". Ignoring the parameter...';
            PRINT '';
            SELECT  @dbname = NULL; -- invalid @dbname passed as parameter is ignored
        END;

    IF ( @loginame IS NULL ) -- Simply default to all LoginNames.
        GOTO LABEL_PARAM;

    SELECT  @sid1 = NULL;
    IF EXISTS ( SELECT  *
                FROM    sys.syslogins
                WHERE   loginname = @loginame )
        SELECT  @sid1 = sid
        FROM    sys.syslogins
        WHERE   loginname = @loginame;

    IF ( @sid1 IS NOT NULL ) -- The parameter is a recognized login name.
        BEGIN
            SELECT  @sidlow = SUSER_SID(@loginame) ,
                    @sidhigh = SUSER_SID(@loginame);
            GOTO LABEL_PARAM;
        END;

    IF ( LOWER(@loginame COLLATE Latin1_General_CI_AS) IN ( 'active' ) ) -- Special action, not sleeping.
        BEGIN
            SELECT  @loginame = LOWER(@loginame COLLATE Latin1_General_CI_AS);
            GOTO LABEL_PARAM;
        END;

    IF ( PATINDEX('%[^0-9]%', ISNULL(@loginame, 'z')) = 0 ) -- Is a number.
        BEGIN
            SELECT  @spidlow = CONVERT(INT, @loginame) ,
                    @spidhigh = CONVERT(INT, @loginame);
            GOTO LABEL_PARAM;
        END;

    RAISERROR(15007,-1,-1,@loginame);
    SELECT  @retcode = 1;
    GOTO LABEL_RETURN;


    LABEL_PARAM:


-------------------- Capture consistent sysprocesses. -------------------

    SELECT  spid ,
            status ,
            sid ,
            hostname ,
            program_name ,
            cmd ,
            cpu ,
            physical_io ,
            blocked ,
            dbid ,
            CONVERT(sysname, RTRIM(loginame)) AS loginname ,
            spid AS 'spid_sort' ,
            SUBSTRING(CONVERT(VARCHAR, last_batch, 111), 6, 5) + ' '
            + SUBSTRING(CONVERT(VARCHAR, last_batch, 113), 13, 8) AS 'last_batch_char' ,
            DB_NAME(dbid) AS 'dbname'
    INTO    #tb1_sysprocesses
    FROM    master.dbo.sysprocesses WITH ( NOLOCK );

    IF @@error <> 0
        BEGIN
            SELECT  @retcode = @@error;
            GOTO LABEL_RETURN;
        END;

    IF ( @loginame IN ( 'active' ) )
        DELETE  #tb1_sysprocesses
        WHERE   LOWER(status) = 'sleeping'
                AND UPPER(cmd) IN ( 'AWAITING COMMAND', 'LAZY WRITER',
                                    'CHECKPOINT SLEEP' )
                AND blocked = 0
                AND dbid NOT IN (
                SELECT  dbid
                FROM    master.dbo.sysdatabases WITH ( NOLOCK )
                WHERE   name LIKE '%' + @dbname + '%' ); 


-- Prepare to dynamically optimize column widths.
    SELECT  @charsidlow = CONVERT(VARCHAR(85), @sidlow) ,
            @charsidhigh = CONVERT(VARCHAR(85), @sidhigh) ,
            @charspidlow = CONVERT(VARCHAR, @spidlow) ,
            @charspidhigh = CONVERT(VARCHAR, @spidhigh);

    SELECT  @charMaxLenLoginName = CONVERT(VARCHAR, ISNULL(MAX(DATALENGTH(loginname)),
                                                           16)) ,
            @charMaxLenDBName = CONVERT(VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), DB_NAME(dbid))))),
                                                        20)) ,
            @charMaxLenCPUTime = CONVERT(VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), cpu)))),
                                                         7)) ,
            @charMaxLenDiskIO = CONVERT(VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), physical_io)))),
                                                        6)) ,
            @charMaxLenCommand = CONVERT(VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), cmd)))),
                                                         7)) ,
            @charMaxLenHostName = CONVERT(VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), hostname)))),
                                                          16)) ,
            @charMaxLenProgramName = CONVERT(VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), program_name)))),
                                                             11)) ,
            @charMaxLenLastBatch = CONVERT(VARCHAR, ISNULL(MAX(DATALENGTH(RTRIM(CONVERT(VARCHAR(128), last_batch_char)))),
                                                           9))
    FROM    #tb1_sysprocesses
    WHERE   spid >= @spidlow
            AND spid <= @spidhigh;


-- Output the report.
    SET @command = '
SET nocount off

SELECT
 SPID = convert(char(5),spid)

 ,Status =
 CASE lower(status)
 When ''sleeping'' Then lower(status)
 Else upper(status)
 END

 ,Login = substring(loginname,1,' + @charMaxLenLoginName + ')

 ,HostName =
 CASE hostname
 When Null Then '' .''
 When '' '' Then '' .''
 Else substring(hostname,1,' + @charMaxLenHostName
        + ')
 END

 ,BlkBy =
 CASE isnull(convert(char(5),blocked),''0'')
 When ''0'' Then '' .''
 Else isnull(convert(char(5),blocked),''0'')
 END

 ,DBName = substring(case when dbid = 0 then null when dbid <> 0 then db_name(dbid) end,1,'
        + @charMaxLenDBName + ')
 ,Command = substring(cmd,1,' + @charMaxLenCommand + ')

 ,CPUTime = substring(convert(varchar,cpu),1,' + @charMaxLenCPUTime + ')
 ,DiskIO = substring(convert(varchar,physical_io),1,' + @charMaxLenDiskIO + ')

 ,LastBatch = substring(last_batch_char,1,' + @charMaxLenLastBatch + ')

 ,ProgramName = substring(program_name,1,' + @charMaxLenProgramName + ')
 ,SPID = convert(char(5),spid) -- Handy extra for right-scrolling users.
 from
 #tb1_sysprocesses
 where 
 spid >= ' + @charspidlow + '
 and spid <= ' + @charspidhigh + '
';

    IF ( @dbname IS NOT NULL )
        SET @command = @command + '
 and dbname like ''%' + @dbname + '%''
';

    SET @command = @command + ' order by spid_sort

set nocount on
';
    EXEC (@command);

    LABEL_RETURN:

    IF ( OBJECT_ID('tempdb.dbo.#tb1_sysprocesses') IS NOT NULL )
        DROP TABLE #tb1_sysprocesses;


    RETURN @retcode;
 -- sp_who3
GO


IF EXISTS ( SELECT  *
            FROM    sysobjects
            WHERE   id = OBJECT_ID('dbo.sp_who3')
                    AND sysstat & 0xf = 4 )
    GRANT EXEC ON dbo.sp_who3 TO PUBLIC;
GO






