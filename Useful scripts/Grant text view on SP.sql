
--temporary table

DECLARE
	   @tmpTable TABLE(PK_ID int IDENTITY(1 , 1)
						    NOT NULL
						    PRIMARY KEY CLUSTERED ,
				    name sysname)

--declare variables

DECLARE
	   @name sysname ,
	   @RowCount int ,
	   @RecCount int ,
	   @strSQL varchar(1000)


INSERT INTO @tmpTable(name)
SELECT ROUTINE_SCHEMA + '.' + ROUTINE_NAME
  FROM INFORMATION_SCHEMA.ROUTINES
  WHERE
	   ROUTINE_TYPE =
	   'PROCEDURE'
    AND ROUTINE_NAME NOT LIKE 'dt_%'

-- counters for while

SET @RecCount = (SELECT COUNT(*)
			    FROM @tmpTable)

SET @RowCount = 1

WHILE
	 @RowCount <
	 @RecCount + 1

    BEGIN

	   SELECT @name = name
		FROM @tmpTable
		WHERE
			 PK_ID =
			 @RowCount

	   SET @strSQL = N'Grant VIEW Definition on ' + RTRIM(CAST(@name AS varchar(128))) + ' to [ZA\Andries.Mgiti]'

	   --Execute the Sql

	   EXEC (@strSQL)

	   --Decrement the counter

	   SET @RowCount = @RowCount + 1

	   --reset vars, just in case...

	   SET @name = NULL
    END

SELECT * FROM @tmpTable