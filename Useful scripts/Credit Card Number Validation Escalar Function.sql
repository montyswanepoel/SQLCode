CREATE FUNCTION dbo.validateCreditCard (
	@CCNumber	varchar(20)
	)
RETURNS bit AS
BEGIN 
declare		@lenCCNumber	int,
		@i		int,
		@TotalSum	int,
		@temp		int,
		@isValidCC	bit

SET	@isValidCC = 0
SET @CCNumber = LTRIM(RTRIM(@CCNumber))

IF (@CCNumber IS NULL) OR (LEN(@CCNumber) = 0) OR (ISNUMERIC(@CCNumber) <> 1)
	GOTO Rtrn

SET @lenCCNumber=LEN(@CCNumber)
SET @i = 1
SET @temp = 0
SET @TotalSum = 0

WHILE @i <= @lenCCNumber
	BEGIN
		IF SUBSTRING(@CCNumber,@i,1) NOT LIKE '[0-9]'
			GOTO Rtrn
		
		SET @temp = CAST(SUBSTRING(@CCNumber,@i,1) AS int)
		IF (@i % 2) = 1
			BEGIN
				SET @temp = @temp * 2
				IF @temp > 9
					SET @temp = @temp - 9
			END

		SET @TotalSum = @TotalSum + @temp
		SET @i = @i + 1
	END

IF (@TotalSum % 10 = 0) AND (@TotalSum <= 150)
	SET @isValidCC = 1
Rtrn:
RETURN (@isValidCC)
END