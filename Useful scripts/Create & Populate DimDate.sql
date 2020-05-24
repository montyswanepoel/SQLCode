SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create PROC [dbo].[dwpPopulateDimDate]
AS
begin
    -- For details about setting parameters, please refer to:
    -- http://www.codeproject.com/Articles/1060016/Creating-Date-dimension-from-scratch-in-Microsoft

    declare @startDate date = '20190101'
    declare @endDate date = '20191231'
    declare @firstDayOfWeek tinyint = 1
    declare @fiscalDay tinyint = 21
    declare @fiscalMonth tinyint = 5
    declare @fiscalYearPlus1 tinyint = 1

    -- =========================================================================
    -- End of user defined parameters. You should not change rest of the script.
    -- =========================================================================

    declare @dimDateObjectId int
    declare @sql varchar(max)

    -- Sanity Check
    if object_id('dbo.DimDate', 'U') is null
begin
        raiserror (N'%s does not exist in database!', 16, 1, N'[dbo].[DimDate]', 5)
        return
    end
    if @fiscalDay = 1 and @fiscalMonth = 1
begin
        raiserror (N'There is no point in having fiscal year same as calendar year!', 16, 1, null, 5);
        return
    end
    if @startDate >= @endDate
begin
        raiserror (N'@startDate must be less than @endDate!', 16, 1, null, 5)
        return
    end
    if @firstDayOfWeek < 1 or @firstDayOfWeek > 7
begin
        raiserror (N'@firstDayOfWeek must be in range from 1 to 7! Current value is %i', 16, 1, @firstDayOfWeek, 5);
        return
    end
    if @fiscalDay < 1 or @fiscalDay > 28
begin
        raiserror (N'@fiscalDay must be in range from 1 to 28! Current value is %i', 16, 1, @fiscalDay, 5);
        return
    end
    if @fiscalMonth < 1 or @fiscalMonth > 12
begin
        raiserror (N'@fiscalMonth must be in range from 1 to 12! Current value is %i', 16, 1, @fiscalMonth, 5);
        return
    end
    if @fiscalYearPlus1 < 0 or @fiscalYearPlus1 > 1
begin
        raiserror (N'@fiscalYearPlus1 must be 0 or 1! Current value is %i', 16, 1, @fiscalYearPlus1, 5);
        return
    end


    begin try
	begin tran

		-- Prepare drop and create scripts
		-- ===============================

		select @dimDateObjectId = T.[object_id]
    from sys.schemas S
        inner join sys.tables T on T.[schema_id] = S.[schema_id]
    where S.name = 'dbo'
        and T.name = 'DimDate'
	
		IF OBJECT_ID('tempdb..#drop') IS NOT NULL DROP TABLE #drop
		IF OBJECT_ID('tempdb..#create') IS NOT NULL DROP TABLE #create
		CREATE TABLE #drop
    (
        script NVARCHAR(MAX)
    )
		CREATE TABLE #create
    (
        script NVARCHAR(MAX)
    )
  
		-- drop is easy, just build a simple concatenated list from sys.foreign_keys:
		INSERT INTO #drop
        (script)
    SELECT N'ALTER TABLE ' + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) + ' DROP CONSTRAINT ' + QUOTENAME(fk.name)
    FROM sys.foreign_keys AS fk
        INNER JOIN sys.tables AS ct ON fk.parent_object_id = ct.[object_id]
        INNER JOIN sys.schemas AS cs ON ct.[schema_id] = cs.[schema_id]
    WHERE fk.referenced_object_id = @dimDateObjectId

		-- create is a little more complex. We need to generate the list of 
		-- columns on both sides of the constraint, even though in most cases
		-- there is only one column.
		INSERT INTO #create
        (script)
    SELECT N'ALTER TABLE ' + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) + ' ADD CONSTRAINT ' + QUOTENAME(fk.name) + ' FOREIGN KEY (' + STUFF((SELECT ',' + QUOTENAME(c.name)
        -- get all the columns in the constraint table
        FROM sys.columns AS c
            INNER JOIN sys.foreign_key_columns AS fkc ON fkc.parent_column_id = c.column_id AND fkc.parent_object_id = c.[object_id]
        WHERE fkc.constraint_object_id = fk.[object_id]
        ORDER BY fkc.constraint_column_id
        FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'')
			+ ') REFERENCES ' + QUOTENAME(rs.name) + '.' + QUOTENAME(rt.name)
			+ '(' + STUFF((SELECT ',' + QUOTENAME(c.name)
        -- get all the referenced columns
        FROM sys.columns AS c
            INNER JOIN sys.foreign_key_columns AS fkc ON fkc.referenced_column_id = c.column_id AND fkc.referenced_object_id = c.[object_id]
        WHERE fkc.constraint_object_id = fk.[object_id]
        ORDER BY fkc.constraint_column_id
        FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') + ');'
    FROM sys.foreign_keys AS fk
        INNER JOIN sys.tables AS rt ON fk.referenced_object_id = rt.[object_id]
        INNER JOIN sys.schemas AS rs ON rt.[schema_id] = rs.[schema_id]
        INNER JOIN sys.tables AS ct ON fk.parent_object_id = ct.[object_id]
        INNER JOIN sys.schemas AS cs ON ct.[schema_id] = cs.[schema_id]
    WHERE rt.is_ms_shipped = 0 AND ct.is_ms_shipped = 0 AND fk.referenced_object_id = @dimDateObjectId

		-- Physically drop constraints
		-- ===========================
		DECLARE drop_cursor CURSOR FOR 
		SELECT script
    FROM #drop
		OPEN drop_cursor
		FETCH NEXT FROM drop_cursor INTO @sql
		WHILE @@FETCH_STATUS = 0
		BEGIN
        EXEC(@sql)
        FETCH NEXT FROM drop_cursor INTO @sql
    END 
		CLOSE drop_cursor;
		DEALLOCATE drop_cursor;


		-- Prepare table for insert
		-- ========================
		truncate table dbo.DimDate

		-- Insert Unknown member
		-- =====================
		insert into dbo.DimDate
        ([Date], [FullDateAlternateKey])
    select -1, '19000101'

		-- DimDate Logic
		-- ===============================
		declare @daysCount int = datediff(day, @startDate, @endDate) + 1
		set datefirst @firstDayOfWeek; -- Monday is first day of the week. https://msdn.microsoft.com/en-AU/library/ms181598.aspx

		-- Use Tally table: http://dwaincsql.com/2014/03/27/tally-tables-in-t-sql/
		with
        lv0
        as
        (
                            select 0 g
            union ALL
                select 0
        )
			,
        lv1
        as
        (
            select 0 g
            from lv0 a CROSS JOIN lv0 b
        ) -- 4
			,
        lv2
        as
        (
            select 0 g
            from lv1 a CROSS JOIN lv1 b
        ) -- 16
			,
        lv3
        as
        (
            select 0 g
            from lv2 a CROSS JOIN lv2 b
        ) -- 256
			,
        lv4
        as
        (
            select 0 g
            from lv3 a CROSS JOIN lv3 b
        ) -- 65,536
			,
        lv5
        as
        (
            select 0 g
            from lv4 a CROSS JOIN lv4 b
        ) -- 4,294,967,296
			,
        Tally (n)
        as
        (
            select row_number() over (order by (select NULL))
            from lv5
        )
			,
        Dates_1 (d)
        as
        (
            select TOP (@daysCount)
                dateadd(day, n-1, @startDate)
            from Tally
            ORDER BY n
        )
			,
        Dates_2 (d, fd)
        as
        (
            select d, dateadd(day, -1 * (@fiscalDay - 1), dateadd(month, -1 * (@fiscalMonth - 1), d))
            from Dates_1
        )
			,
        Dates (d, fd, fd1)
        as
        (
            select d, fd, convert(date, CAST(year(fd) AS varchar) + right('0' + cast(@fiscalMonth as varchar), 2) + right('0' + cast(@fiscalDay as varchar), 2))
            from Dates_2
        )

    insert into dbo.DimDate
        (
        [Date]
        ,[FullDateAlternateKey]
        ,[DateEnglishName]
        -- D
        ,[DayOfWeek]
        ,[DayOfWeekEnglishName]
        ,[DayOfMonth]
        ,[DayOfMonthEnglishName]
        ,[DayOfQuarter]
        ,[DayOfQuarterEnglishName]
        ,[DayOfTrimester]
        ,[DayOfTrimesterEnglishName]
        ,[DayOfHalfYear]
        ,[DayOfHalfYearEnglishName]
        ,[DayOfYear]
        ,[DayOfYearEnglishName]
        ,[Weekday]
        -- W
        ,[Week]
        ,[WeekEnglishName]
        ,[WeekOfYear]
        ,[WeekOfYearEnglishName]
        -- t
        ,[TenDays]
        ,[TenDaysEnglishName]
        ,[TenDaysOfMonth]
        ,[TenDaysOfMonthEnglishName]
        ,[TenDaysOfQuarter]
        ,[TenDaysOfQuarterEnglishName]
        ,[TenDaysOfTrimester]
        ,[TenDaysOfTrimesterEnglishName]
        ,[TenDaysOfHalfYear]
        ,[TenDaysOfHalfYearEnglishName]
        ,[TenDaysOfYear]
        ,[TenDaysOfYearEnglishName]
        -- M
        ,[Month]
        ,[MonthEnglishName]
        ,[MonthOfQuarter]
        ,[MonthOfQuarterEnglishName]
        ,[MonthOfTrimester]
        ,[MonthOfTrimesterEnglishName]
        ,[MonthOfHalfYear]
        ,[MonthOfHalfYearEnglishName]
        ,[MonthOfYear]
        ,[MonthOfYearEnglishName]
        -- Q
        ,[Quarter]
        ,[QuarterEnglishName]
        ,[QuarterOfHalfYear]
        ,[QuarterOfHalfYearEnglishName]
        ,[QuarterOfYear]
        ,[QuarterOfYearEnglishName]
        -- T
        ,[Trimester]
        ,[TrimesterEnglishName]
        ,[TrimesterOfYear]
        ,[TrimesterOfYearEnglishName]
        -- H
        ,[HalfYear]
        ,[HalfYearEnglishName]
        ,[HalfYearOfYear]
        ,[HalfYearOfYearEnglishName]
        -- Y
        ,[Year]
        ,[YearEnglishName]
        -- FD
        ,[FiscalDay]
        ,[FiscalDayEnglishName]
        ,[FiscalDayOfWeek]
        ,[FiscalDayOfWeekEnglishName]
        ,[FiscalDayOfMonth]
        ,[FiscalDayOfMonthEnglishName]
        ,[FiscalDayOfQuarter]
        ,[FiscalDayOfQuarterEnglishName]
        ,[FiscalDayOfTrimester]
        ,[FiscalDayOfTrimesterEnglishName]
        ,[FiscalDayOfHalfYear]
        ,[FiscalDayOfHalfYearEnglishName]
        ,[FiscalDayOfYear]
        ,[FiscalDayOfYearEnglishName]
        -- FW
        ,[FiscalWeek]
        ,[FiscalWeekEnglishName]
        ,[FiscalWeekOfMonth]
        ,[FiscalWeekOfMonthEnglishName]
        ,[FiscalWeekOfQuarter]
        ,[FiscalWeekOfQuarterEnglishName]
        ,[FiscalWeekOfTrimester]
        ,[FiscalWeekOfTrimesterEnglishName]
        ,[FiscalWeekOfHalfYear]
        ,[FiscalWeekOfHalfYearEnglishName]
        ,[FiscalWeekOfYear]
        ,[FiscalWeekOfYearEnglishName]
        -- FM
        ,[FiscalMonth]
        ,[FiscalMonthEnglishName]
        ,[FiscalMonthOfQuarter]
        ,[FiscalMonthOfQuarterEnglishName]
        ,[FiscalMonthOfTrimester]
        ,[FiscalMonthOfTrimesterEnglishName]
        ,[FiscalMonthOfHalfYear]
        ,[FiscalMonthOfHalfYearEnglishName]
        ,[FiscalMonthOfYear]
        ,[FiscalMonthOfYearEnglishName]
        -- FQ
        ,[FiscalQuarter]
        ,[FiscalQuarterEnglishName]
        ,[FiscalQuarterOfHalfYear]
        ,[FiscalQuarterOfHalfYearEnglishName]
        ,[FiscalQuarterOfYear]
        ,[FiscalQuarterOfYearEnglishName]
        -- FT
        ,[FiscalTrimester]
        ,[FiscalTrimesterEnglishName]
        ,[FiscalTrimesterOfYear]
        ,[FiscalTrimesterOfYearEnglishName]
        -- FH
        ,[FiscalHalfYear]
        ,[FiscalHalfYearEnglishName]
        ,[FiscalHalfYearOfYear]
        ,[FiscalHalfYearOfYearEnglishName]
        -- FY
        ,[FiscalYear]
        ,[FiscalYearEnglishName]
        )

    select
        -- Date
        convert(int, convert(varchar(10), d, 112)) as [Date]
			, d as [FullDateAlternateKey]
			, convert(varchar(20), d, 106) as [DateEnglishName]

			-- Day
			, convert(smallint, datepart(weekday, d)) as [DayOfWeek]
			, convert(varchar(20), datename(weekday, d)) as [DayOfWeekEnglishName]
			, convert(smallint, datepart(day, d)) as [DayOfMonth]
			, convert(varchar(20), 'Day ' + right('0' + convert(varchar, datepart(day, d)), 2)) as [DayOfMonthEnglishName]
			, convert(smallint, datediff(day, dateadd(quarter, datediff(quarter, 0, d), 0),d) + 1) as [DayOfQuarter]
			, convert(varchar(20), 'Day ' + right('0' + convert(varchar, datediff(day, dateadd(quarter, datediff(quarter, 0, d), 0),d) + 1), 2)) as [DayOfQuarterEnglishName]
			, convert(smallint, datediff(day, dateadd(month, datediff(month, 0, d) - datediff(month, 0, d) % 4, 0), d) + 1) as [DayOfTrimester]
			, convert(varchar(20), 'Day ' + right('00' + convert(varchar, datediff(day, dateadd(month, datediff(month, 0, d) - datediff(month, 0, d) % 4, 0), d) + 1), 3)) as [DayOfTrimesterEnglishName]
			, convert(smallint, datediff(day, dateadd(month, datediff(month, 0, d) - datediff(month, 0, d) % 6, 0), d) + 1) as [DayOfHalfYear]
			, convert(varchar(20), 'Day ' + right('00' + convert(varchar, datediff(day, dateadd(month, datediff(month, 0, d) - datediff(month, 0, d) % 6, 0), d) + 1), 3)) as [DayOfHalfYearEnglishName]
			, convert(smallint, datepart(dayofyear, d)) as [DayOfYear]
			, convert(varchar(20), 'Day ' + right('00' + convert(varchar, datepart(dayofyear, d)), 3)) as [DayOfYearEnglishName]
			, isnull(convert(varchar(20), case when datename(weekday, d) in ('Saturday', 'Sunday') then 'Weekend' else 'Weekday' end), 0) as [Weekday]

			-- Week
			, convert(int, datepart(year, d) * 100 + datepart(week, d)) as [Week]
			, convert(varchar(20), 'CY' + convert(char(4), datepart(year, d)) + ' W' + right('0' + convert(varchar, datepart(week, d)), 2)) as [WeekEnglishName]
			, convert(int, datepart(week, d)) as [WeekOfYear]
			, convert(varchar(20), 'Week ' + right('0' + convert(varchar, datepart(week, d)), 2)) as [WeekOfYearEnglishName]

			-- Ten Days
			, convert(int, datepart(year, d) * 100 + (datepart(month, d) - 1) * 3 + ((case when datepart(day, d) = 31 then 21 else datepart(day, d) end - 1) / 10) + 1) as [TenDays]
			, convert(varchar(20), 'CY' + convert(char(4), datepart(year, d)) + ' Td' + right('0' + convert(varchar, (datepart(month, d) - 1) * 3 + case when datepart(day, d) <= 10 then 1 when datepart(day, d) <= 20 then 2 else 3 end), 2)) as [TenDaysEnglishName]
			, convert(smallint, case when datepart(day, d) <= 10 then 1 when datepart(day, d) <= 20 then 2 else 3 end) as [TenDaysOfMonth]
			, convert(varchar(20), 'Ten Days ' + convert(varchar, case when datepart(day, d) <= 10 then 1 when datepart(day, d) <= 20 then 2 else 3 end)) as [TenDaysOfMonthEnglishName]
			, convert(int, ((datepart(month, d) - 1) % 3) * 3 + ((case when datepart(day, d) = 31 then 21 else datepart(day, d) end - 1) / 10) + 1) as [TenDaysOfQuarter]
			, convert(varchar(20), 'Ten Days ' + convert(varchar, ((datepart(month, d) - 1) % 3) * 3 + ((case when datepart(day, d) = 31 then 21 else datepart(day, d) end - 1) / 10) + 1)) as [TenDaysOfQuarterEnglishName]
			, convert(int, ((datepart(month, d) - 1) % 4) * 3 + ((case when datepart(day, d) = 31 then 21 else datepart(day, d) end - 1) / 10) + 1) as [TenDaysOfTrimester] 
			, convert(varchar(20), 'Ten Days ' + right('0' + convert(varchar, ((datepart(month, d) - 1) % 4) * 3 + ((case when datepart(day, d) = 31 then 21 else datepart(day, d) end - 1) / 10) + 1), 2)) as [TenDaysOfTrimesterEnglishName] 
			, convert(int, ((datepart(month, d) - 1) % 6) * 3 + ((case when datepart(day, d) = 31 then 21 else datepart(day, d) end - 1) / 10) + 1) as [TenDaysOfHalfYear] 
			, convert(varchar(20), 'Ten Days ' + right('0' + convert(varchar, ((datepart(month, d) - 1) % 6) * 3 + ((case when datepart(day, d) = 31 then 21 else datepart(day, d) end - 1) / 10) + 1), 2)) as [TenDaysOfHalfYearEnglishName]
			, convert(int, (datepart(month, d) - 1) * 3 + ((case when datepart(day, d) = 31 then 21 else datepart(day, d) end - 1) / 10) + 1) as [TenDaysOfYear] 
			, convert(varchar(20), 'Ten Days ' + right('0' + convert(varchar, (datepart(month, d) - 1) * 3 + ((case when datepart(day, d) = 31 then 21 else datepart(day, d) end - 1) / 10) + 1), 2)) as [TenDaysOfYearEnglishName] 

			-- Month
			, convert(int, datepart(year, d) * 100 + datepart(month, d)) as [Month]
			, convert(varchar(20), left(datename(month, d), 3) + ' CY' + convert(varchar, datepart(year, d))) as [MonthEnglishName]
			, convert(smallint, (datepart(month, d) - 1) % 3 + 1) as [MonthOfQuarter]
			, convert(varchar(20), 'Month ' + convert(varchar, (datepart(month, d) - 1) % 3 + 1)) as [MonthOfQuarterEnglishName]
			, convert(smallint, (datepart(month, d) - 1) % 4 + 1) as [MonthOfTrimester]
			, convert(varchar(20), 'Month ' + convert(varchar, (datepart(month, d) - 1) % 4 + 1)) as [MonthOfTrimesterEnglishName]
			, convert(smallint, (datepart(month, d) - 1) % 6 + 1) as [MonthOfHalfYear]
			, convert(varchar(20), 'Month ' + convert(varchar, (datepart(month, d) - 1) % 6 + 1)) as [MonthOfHalfYearEnglishName]
			, convert(smallint, datepart(month, d)) as [MonthOfYear]
			, convert(varchar(20), datename(month, d)) as [MonthOfYearEnglishName]

			-- Quarter
			, convert(smallint, datepart(year, d) * 10 + datepart(quarter, d)) as [Quarter]
			, convert(varchar(20), 'CY' + convert(varchar, datepart(year, d)) + ' Q' + convert(char(1), datepart(quarter, d))) as [QuarterEnglishName]
			, convert(smallint, case when datepart(quarter, d) > 2 then datepart(quarter, d) - 2 else datepart(quarter, d) end) as [QuarterOfHalfYear]
			, convert(varchar(20), 'Quarter ' + convert(char(1), case when datepart(quarter, d) > 2 then datepart(quarter, d) - 2 else datepart(quarter, d) end)) as [QuarterOfHalfYearEnglishName]
			, convert(smallint, datepart(quarter, d)) as [QuarterOfYear]
			, convert(varchar(20), 'Quarter ' + convert(char(1), datepart(quarter, d))) as [QuarterOfYearEnglishName]

			-- Trimester
			, convert(smallint, datepart(year, d) * 10 + ((datepart(month, d) - 1) / 4 + 1)) as [Trimester]
			, convert(varchar(20), 'CY' + convert(char(4), datepart(year, d)) + ' T' + convert(char(1), (datepart(month, d) - 1) / 4 + 1)) as [TrimesterEnglishName]
			, convert(smallint, (datepart(month, d) - 1) / 4 + 1) as [TrimesterOfYear]
			, convert(varchar(20), 'Trimester ' + convert(char(1), (datepart(month, d) - 1) / 4 + 1)) as [TrimesterOfYearEnglishName]

			-- Half Year
			, convert(smallint, datepart(year, d) * 10 + case when datepart(month, d) <= 6 then 1 else 2 end) as [HalfYear]
			, convert(varchar(20), 'CY' + convert(varchar, datepart(year, d)) + ' H' + convert(char(1), case when datepart(month, d) <= 6 then 1 else 2 end)) as [HalfYearEnglishName]
			, convert(smallint, case when datepart(month, d) <= 6 then 1 else 2 end) as [HalfYearOfYear]
			, convert(varchar(20), 'Semester ' + convert(char(1), case when datepart(month, d) <= 6 then 1 else 2 end)) as [HalfYearOfYearEnglishName]

			-- Year
			, convert(smallint, datepart(year, d)) as [Year]
			, convert(varchar(20), 'CY' + convert(varchar, datepart(year, d))) as [YearEnglishName]

			-- Fiscal Day
			, convert(int, (datepart(year, fd) + @fiscalYearPlus1) * 10000 + datepart(month, fd) * 100 + datepart(day, fd)) as [FiscalDay]
			, convert(varchar(20), 'FY' + convert(varchar, (datepart(year, fd) + @fiscalYearPlus1)) + ' M' + right('0' + convert(varchar, datepart(month, fd)), 2) + ' D' + right('0' + convert(varchar, datepart(day, fd)), 2)) as [FiscalDayEnglishName]
			, convert(smallint, datepart(weekday, d)) as [FiscalDayOfWeek]
			, convert(varchar(20), datename(weekday, d)) as [FiscalDayOfWeekEnglishName]
			, convert(smallint, datepart(day, fd)) as [FiscalDayOfMonth]
			, convert(varchar(20), 'Fiscal Day ' + right('0' + convert(varchar, datepart(day, fd)), 2)) as [FiscalDayOfMonthEnglishName]
			, convert(smallint, datediff(day, dateadd(quarter, datediff(quarter, 0, fd), 0),fd) + 1) as [FiscalDayOfQuarter]
			, convert(varchar(20), 'Fiscal Day ' + right('0' + convert(varchar, datediff(day, dateadd(quarter, datediff(quarter, 0, fd), 0),fd) + 1), 2)) as [FiscalDayOfQuarterEnglishName]
			, convert(smallint, datediff(day, dateadd(month, datediff(month, 0, fd) - datediff(month, 0, fd) % 4, 0), fd) + 1) as [FiscalDayOfTrimester]
			, convert(varchar(20), 'Fiscal Day ' + right('00' + convert(varchar, datediff(day, dateadd(month, datediff(month, 0, fd) - datediff(month, 0, fd) % 4, 0), fd) + 1), 3)) as [FiscalDayOfTrimesterEnglishName]
			, convert(smallint, datediff(day, dateadd(month, datediff(month, 0, fd) - datediff(month, 0, fd) % 6, 0), fd) + 1) as [FiscalDayOfHalfYear]
			, convert(varchar(20), 'Fiscal Day ' + right('00' + convert(varchar, datediff(day, dateadd(month, datediff(month, 0, fd) - datediff(month, 0, fd) % 6, 0), fd) + 1), 3)) as  [FiscalDayOfHalfYearEnglishName]
			, convert(smallint, datepart(dayofyear, fd)) as [FiscalDayOfYear]
			, convert(varchar(20), 'Fiscal Day ' + right('00' + convert(varchar, datepart(dayofyear, fd)), 3)) as [FiscalDayOfYearEnglishName]

			-- Fiscal Week
			, convert(int, (datepart(year, fd) + @fiscalYearPlus1) * 100 + 1 + DATEDIFF(WEEK, dateadd(day, -@@datefirst, fd1), dateadd(day, -@@datefirst, d))) as [FiscalWeek]
			, convert(varchar(20), 'FY' + convert(varchar, datepart(year, fd) + @fiscalYearPlus1) + ' W' + convert(varchar, 1 + DATEDIFF(WEEK, dateadd(day, -@@datefirst, fd1), dateadd(day, -@@datefirst, d)))) as [FiscalWeekEnglishName]
			, 1 + DATEDIFF(WEEK, dateadd(day, -@@datefirst, dateadd(day, (@fiscalDay - 1), dateadd(month, datediff(month, 0, case when @fiscalDay > day(d) then dateadd(month, -1, d) else d end) - datediff(month, 0, d) % 1, 0))), dateadd(day, -@@datefirst, d)) as [FiscalWeekOfMonth]
			, 'x' as [FiscalWeekOfMonthEnglishName]
			, convert(smallint, 1 + DATEDIFF(WEEK, dateadd(day, -@@datefirst, dateadd(month, datediff(month, fd1, case when @fiscalDay > day(d) then dateadd(month, -1, d) else d end) - datediff(month, fd1, case when @fiscalDay > day(d) then dateadd(month, -1, d) else d end) % 3, fd1)), dateadd(day, -@@datefirst, d))) as [FiscalWeekOfQuarter]
			, 'x' as [FiscalWeekOfQuarterEnglishName]
			, convert(smallint, 1 + DATEDIFF(WEEK, dateadd(day, -@@datefirst, dateadd(month, datediff(month, fd1, case when @fiscalDay > day(d) then dateadd(month, -1, d) else d end) - datediff(month, fd1, case when @fiscalDay > day(d) then dateadd(month, -1, d) else d end) % 4, fd1)), dateadd(day, -@@datefirst, d))) as [FiscalWeekOfTrimester]
			, 'x' as [FiscalWeekOfTrimesterEnglishName]
			--,convert(smallint, 1 + DATEDIFF(WEEK, dateadd(day, -@@datefirst, dateadd(day, @fiscalDay - 1, dateadd(month, datediff(month, 0, d) - datediff(month, 0, fd) % 6, 0))/*dateadd(month, datediff(month, 0, d) - datediff(month, 0, fd) % 6, 0)*/), dateadd(day, -@@datefirst, d))) as [FiscalWeekOfHalfYear] 
			--,1 + DATEDIFF(WEEK, dateadd(day, -@@datefirst, dateadd(day, (@fiscalDay - 1), dateadd(month, datediff(month, 0, case when @fiscalDay > day(d) then dateadd(month, -6, d) else d end) - datediff(month, 0, d) % 6, 0))), dateadd(day, -@@datefirst, d)) as [FiscalWeekOfHalfYear] 
			, convert(smallint, 1 + DATEDIFF(WEEK, dateadd(day, -@@datefirst, dateadd(month, datediff(month, fd1, case when @fiscalDay > day(d) then dateadd(month, -1, d) else d end) - datediff(month, fd1, case when @fiscalDay > day(d) then dateadd(month, -1, d) else d end) % 6, fd1)), dateadd(day, -@@datefirst, d))) as [FiscalWeekOfHalfYear]
			, 'x' as [FiscalWeekOfHalfYearEnglishName]
			, 1 + DATEDIFF(WEEK, dateadd(day, -@@datefirst, fd1), dateadd(day, -@@datefirst, d)) as [FiscalWeekOfYear]
			, 'x' as [FiscalWeekOfYearEnglishName]

			-- Fiscal Month
			, convert(int, (datepart(year, fd) + @fiscalYearPlus1) * 100 + datepart(month, fd)) as [FiscalMonth]
			, convert(varchar(20), 'FY' + convert(varchar, (datepart(year, fd) + @fiscalYearPlus1)) + ' M' + right('0' + convert(varchar, datepart(month, fd)), 2)) as [FiscalMonthEnglishName]
			, convert(smallint, (datepart(month, fd) - 1) % 3 + 1) as [FiscalMonthOfQuarter]
			, convert(varchar(20), 'Month ' + convert(varchar, (datepart(month, fd) - 1) % 3 + 1)) as [FiscalMonthOfQuarterEnglishName]
			, convert(smallint, (datepart(month, fd) - 1) % 4 + 1) as [FiscalMonthOfTrimester]
			, convert(varchar(20), 'Month ' + convert(varchar, (datepart(month, fd) - 1) % 4 + 1)) as [FiscalMonthOfTrimesterEnglishName]
			, convert(smallint, (datepart(month, fd) - 1) % 6 + 1) as [FiscalMonthOfHalfYear]
			, convert(varchar(20), 'Month ' + convert(varchar, (datepart(month, fd) - 1) % 6 + 1)) as [FiscalMonthOfHalfYearEnglishName]
			, convert(smallint, datepart(month, fd)) as [FiscalMonthOfYear]
			, convert(varchar(20), 'Month ' + right('0' + convert(varchar, datepart(month, fd)), 2)) as [FiscalMonthOfYearEnglishName] 

			-- Fiscal Quarter
			, convert(smallint, (datepart(year, fd) + @fiscalYearPlus1) * 10 + datepart(quarter, fd)) as [FiscalQuarter]
			, convert(varchar(20), 'FY' +  convert(varchar, datepart(year, fd) + @fiscalYearPlus1) + ' Q' + convert(varchar, datepart(quarter, fd))) as [FiscalQuarterEnglishName] 
			, convert(smallint, case when datepart(quarter, fd) > 2 then datepart(quarter, fd) - 2 else datepart(quarter, fd) end) as [FiscalQuarterOfHalfYear]
			, convert(varchar(20), 'Fiscal Quarter ' + convert(varchar, case when datepart(quarter, fd) > 2 then datepart(quarter, fd) - 2 else datepart(quarter, fd) end)) as [FiscalQuarterOfHalfYearEnglishName] 
			, convert(smallint, datepart(quarter, fd)) as [FiscalQuarterOfYear]
			, convert(varchar(20), 'Fiscal Quarter ' + convert(varchar, datepart(quarter, fd))) as [FiscalQuarterOfYearEnglishName] 

			-- Fiscal Trimester
			, convert(smallint, (datepart(year, fd) + @fiscalYearPlus1) * 10 + ((datepart(month, fd) - 1) / 4 + 1)) as [FiscalTrimester] 
			, convert(varchar(20), 'FY' + convert(varchar, datepart(year, fd) + @fiscalYearPlus1) + ' T' + convert(varchar, (datepart(month, fd) - 1) / 4 + 1)) as [FiscalTrimesterEnglishName] 
			, convert(smallint, (datepart(month, fd) - 1) / 4 + 1) as [FiscalTrimesterOfYear] 
			, convert(varchar(20), 'Fiscal Trimester ' + convert(varchar, (datepart(month, fd) - 1) / 4 + 1)) as [FiscalTrimesterOfYearEnglishName] 

			-- Fiscal Half Year
			, convert(smallint, (datepart(year, fd) + @fiscalYearPlus1) * 10 + case when datepart(month, fd) <= 6 then 1 else 2 end) as [FiscalHalfYear] 
			, convert(varchar(20), 'FY' + convert(varchar, datepart(year, fd) + @fiscalYearPlus1) + ' H' + convert(varchar, case when datepart(month, fd) <= 6 then 1 else 2 end)) as [FiscalHalfYearEnglishName] 
			, convert(smallint, case when datepart(month, fd) <= 6 then 1 else 2 end) as [FiscalHalfYearOfYear] 
			, convert(varchar(20), 'Fiscal Semester ' + convert(varchar, case when datepart(month, fd) <= 6 then 1 else 2 end)) as [FiscalHalfYearOfYearEnglishName] 

			-- Fiscal Year
			, convert(smallint, datepart(year, fd) + @fiscalYearPlus1) as [FiscalYear] 
			, convert(varchar(20), 'FY' + convert(varchar, datepart(year, fd) + @fiscalYearPlus1)) as [FiscalYearEnglishName]
    from Dates
    ORDER BY d;


		-- Recreate constraints / foreign keys
		-- ===================================
		DECLARE create_cursor CURSOR FOR 
		SELECT script
    FROM #create
		OPEN create_cursor
		FETCH NEXT FROM create_cursor INTO @sql
		WHILE @@FETCH_STATUS = 0
		BEGIN
        BEGIN TRY
				EXEC(@sql)
			END TRY
			BEGIN CATCH /* Do nothing */ END CATCH
        FETCH NEXT FROM create_cursor INTO @sql
    END 
		CLOSE create_cursor;
		DEALLOCATE create_cursor;      


	commit tran

end try
begin catch

	rollback tran

end catch



    -- Tests

    declare @col varchar(200)
    declare @sql2 varchar(max)
    declare @i int = 1

    DECLARE col_cursor CURSOR FOR 
select name
    from sys.columns C
    where object_id = (select object_id
        from sys.objects
        where name = 'DimDate')
        --and name like 'Fiscal%'
        and name not like '%Name'
        and name not in ('Date', 'FullDateAlternateKey', 'Weekday')

    OPEN col_cursor

    FETCH NEXT FROM col_cursor INTO @col

    WHILE @@FETCH_STATUS = 0
BEGIN

        set @sql2 = 'select ''Day and Month when [' + @col + '] changes value:'' [Test ' + convert(varchar, @i) + '.1]'

        exec(@sql2)

        set @sql2 = 'select distinct day(D1.FullDateAlternateKey) as [Day], month(D1.FullDateAlternateKey) as [Month]
		from dbo.DimDate D1
	inner join dbo.DimDate D2 on D2.FullDateAlternateKey = dateadd(day, -1, D1.FullDateAlternateKey)
	where D1.[' + @col + '] <> D2.[' + @col + ']
	and D1.[Date] <> -1
	order by 1, 2'

        exec(@sql2)

        set @sql2 = 'select ''Date, Current and Previous when [' + @col + '] changes value:'' [Test ' + convert(varchar, @i) + '.2]'
        exec(@sql2)

        set @sql2 = 'select distinct D1.FullDateAlternateKey as [Current Date], D1.[' + @col + '] as [Current ' + @col + '], D2.[' + @col + '] as [Previous ' + @col + '], D2.FullDateAlternateKey as [Previous Date]
		from dbo.DimDate D1
	inner join dbo.DimDate D2 on D2.FullDateAlternateKey = dateadd(day, -1, D1.FullDateAlternateKey)
	where D1.[' + @col + '] <> D2.[' + @col + ']
	and D1.[Date] <> -1
	order by 1, 2'

        exec (@sql2)

        set @i = @i + 1

        FETCH NEXT FROM col_cursor INTO @col
    END
    CLOSE col_cursor;
    DEALLOCATE col_cursor;
end

GO
