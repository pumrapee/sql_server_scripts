CREATE PROCEDURE setInternalKeyByTable
@tablename nvarchar(50),
@colname nvarchar(50)
AS
	DECLARE @hashed varchar(65)
	DECLARE @db_cursor CURSOR
	DECLARE @sql nvarchar(100)
	DECLARE @sql2 nvarchar(100)
	DECLARE @sql3 nvarchar(max)
	DECLARE @query nvarchar(100)
	DECLARE @seq_check int
	DECLARE @var int
	SET @sql2 = 'ALTER TABLE ' + @tablename + ' ADD ikey int'
	EXEC SP_EXECUTESQL @sql2
	SET @seq_check = IDENT_CURRENT('ikey_table')
	SET @query = 'SELECT ' + @colname + ' FROM ' + @tablename;
	SET @sql = 'SET @cursor = CURSOR FOR ' + @query + ' OPEN @cursor;';
	EXEC SP_EXECUTESQL @sql, N'@cursor cursor output', @db_cursor output;
	FETCH NEXT FROM @db_cursor INTO @hashed
	WHILE @@FETCH_STATUS = 0  
	BEGIN
		IF NOT EXISTS (SELECT hashed FROM ikey_table WHERE hashed = @hashed)
		BEGIN
			BEGIN TRY 
				INSERT INTO ikey_table (hashed) VALUES (@hashed);
				SET @seq_check = IDENT_CURRENT('ikey_table')
				SET @var = @seq_check
				SET @sql3 = 'UPDATE ' + @tablename + ' SET ikey = ' + cast(@var AS nvarchar(10)) + ' WHERE hashed = ''' + @hashed + ''''
				EXEC SP_EXECUTESQL @sql3
			END TRY
			BEGIN CATCH
				SET @sql = 'DBCC CHECKIDENT ("ikey_table", RESEED, ' + CAST(@seq_check AS nvarchar(50)) + ');'
				SET @sql3 = 'UPDATE ' + @tablename + ' SET ikey = ' + cast(@var AS nvarchar(10)) + ' WHERE hashed = ''' + @hashed + ''''
				EXEC SP_EXECUTESQL @sql3
				SELECT ERROR_NUMBER() AS ErrorNumber;
			END CATCH;
		END
		ELSE
		BEGIN
			SELECT @var=ikey FROM ikey_table WHERE hashed = @hashed;
			EXEC SP_EXECUTESQL @sql3
		END
		FETCH NEXT FROM @db_cursor INTO @hashed;
	END;
	CLOSE @db_cursor;
	DEALLOCATE @db_cursor;
GO

CREATE TABLE ikey_table (
	hashed varchar(65) NOT NULL UNIQUE,
	ikey int NOT NULL IDENTITY(1,1),
);