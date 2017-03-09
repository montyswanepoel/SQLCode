if not object_id('dbo.udf_GetDaylightSavingsTime') is null
    drop function dbo.udf_GetDaylightSavingsTime
GO

CREATE function [dbo].udf_GetDaylightSavingsTime(@year int, @extent varchar(255))
returns datetime
/**********************************************************************
PROCEDURE:      udf_GetDaylightSavingsTime
PARAMETERS:     @year: the year to return the daylight savings time begin
                date
                
                @extent ('Begin' or 'End'): indicates whether the function
                returns the begin or end date of daylight savings time

APPLICATION:	System Support
PURPOSE:		This procedure will return the date of daylight savings
                time according to the current federal schedule, which is 
                currently the second Sunday in March: http://www.energy.ca.gov/daylightsaving.html#chart

NOTES:          This procedure will also return the begin date for the previous
                schedule which ended in 2006, which was the first Sunday of 
                April

EXAMPLES:       print dbo.udf_GetDaylightSavingsTime(2003, 'Begin')
                print dbo.udf_GetDaylightSavingsTime(2003, 'End')                
                
                print dbo.udf_GetDaylightSavingsTime(2009, 'Begin')
                print dbo.udf_GetDaylightSavingsTime(2009, 'end')
                
MODIFIED DATE   AUTHOR              DESCRIPTION
--------------  --------------      -------------------------------

**********************************************************************/
as
begin -- function

declare @dateTime datetime
,       @ErrorMessage varchar(1000)
,       @ProcName     varchar(128)

SET @ProcName = object_name(@@procid)

if @extent not in('Begin', 'End')
begin
	set @dateTime = 1/0
end

set @dateTime = case @extent
                    when 'Begin' then
                        case 
                            --latest daylight savings time 
                            when @year >= 2007 then cast('3/8/' + cast(@year as varchar(4)) as datetime)
                            --old daylight savings time prior to 2007
                            when @year <= 2006 then cast('4/1/' + cast(@year as varchar(4)) as datetime)
                        end
                    when 'End' then
                        case 
                            --latest daylight savings time 
                            when @year >= 2007 then cast('11/1/' + cast(@year as varchar(4)) as datetime)
                            --old daylight savings time prior to 2007
                            when @year <= 2006 then cast('10/31/' + cast(@year as varchar(4)) as datetime)
                        end
                end

set @dateTime = case
                    when @extent = 'End' and @year <= 2006
                        then DATEADD(DAY,1-DATEPART(weekday,dateadd(ms,-3,DATEADD(mm, DATEDIFF(m,0,@dateTime)+1, 0))),dateadd(ms,-3,DATEADD(mm, DATEDIFF(m,0,@dateTime)+1, 0)))
                else
                    case when datepart(dw, @dateTime) = 1
                        then @dateTime
                        else dateadd(dd, 8 - datepart(dw, @dateTime), @dateTime)
                    end
                end
                
-- daylight savings time begins at 2 am
return convert(varchar(10), @dateTime, 101) + ' 02:00:00'
end -- function
GO



declare @TestyWesty table (UTCDate datetime)

--Test DST Begin date
insert into @TestyWesty values('03/08/2009 09:59:59')
insert into @TestyWesty values('03/08/2009 10:00:00')
insert into @TestyWesty values('03/08/2009 10:00:01')

--Test DST End date
insert into @TestyWesty values('11/01/2009 08:59:59')
insert into @TestyWesty values('11/01/2009 09:00:00')
insert into @TestyWesty values('11/01/2009 09:00:01')

SELECT 
      case
        when dateadd(hour, -8, UTCDate) >= dbo.udf_GetDaylightSavingsTime(year(UTCDate), 'Begin') and dateadd(hour, -7, UTCDate) < dbo.udf_GetDaylightSavingsTime(year(UTCDate), 'End')
            then dateadd(hour, -7, UTCDate)
        else
            dateadd(hour, -8, UTCDate)
       end as UTCDate
from   @TestyWesty

