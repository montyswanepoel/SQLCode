-- Convert a UTC Time to a Local Time
DECLARE @UTCDate datetime
DECLARE @LocalDate datetime
DECLARE @TimeDiff int 


--Figure out the time difference between UTC and Local time
SET @UTCDate = GETUTCDATE()
SET @LocalDate = GETDATE()
SET @TimeDiff = DATEDIFF(hh, @UTCDate, @LocalDate) 

--Check Results
PRINT @LocalDate
PRINT @UTCDate
PRINT @TimeDiff 

--Convert UTC to local time
DECLARE @DateYouWantToConvert datetime
DECLARE @ConvertedLocalTime datetime 

SET @DateYouWantToConvert = ’4/25/2007 18:00′
SET @ConvertedLocalTime = DATEADD(hh, @TimeDiff, @DateYouWantToConvert) 

--Check Results
PRINT @ConvertedLocalTime 

