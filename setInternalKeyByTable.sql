CREATE PROCEDURE setInternalKeyByTable
@tablename nvarchar(50),
@colname nvarchar(50)
AS
	DECLARE @hashed varchar(65)
	DECLARE @db_cursor CURSOR
	DECLARE @sql nvarchar(max)
	DECLARE @query nvarchar(100)
	DECLARE @seq_check int
	DECLARE @var int
	DECLARE @index int
	BEGIN TRY
		SET @sql = 'ALTER TABLE ' + @tablename + ' ADD ikey int'
		EXEC SP_EXECUTESQL @sql
	END TRY
	BEGIN CATCH
		SELECT 'CONTINUE'
	END CATCH
	BEGIN TRY
		SET @sql = 'CREATE UNIQUE INDEX hashed_index ON ' + @tablename + ' (' + @colname + ')'
		EXEC SP_EXECUTESQL @sql
	END TRY
	BEGIN CATCH
		SELECT 'CONTINUE'
	END CATCH
	SET @query = 'SELECT ' + @colname + ' FROM ' + @tablename
	SET @sql = 'SET @cursor = CURSOR FOR ' + @query + ' OPEN @cursor;'
	EXEC SP_EXECUTESQL @sql, N'@cursor cursor output', @db_cursor output
	FETCH NEXT FROM @db_cursor INTO @hashed
	WHILE @@FETCH_STATUS = 0  
	BEGIN
		SET @seq_check = IDENT_CURRENT('ikey_table')
		BEGIN TRY 
			INSERT INTO ikey_table (hashed) VALUES (@hashed)
			SET @var = @seq_check
			SET @seq_check = IDENT_CURRENT('ikey_table')
		END TRY
		BEGIN CATCH
			SET @sql = 'DBCC CHECKIDENT ("ikey_table", RESEED, ' + CAST(@seq_check AS nvarchar(50)) + ');'
			EXEC SP_EXECUTESQL @sql
			SELECT @var=ikey FROM ikey_table WHERE hashed = @hashed
		END CATCH
		SET @sql = 'UPDATE ' + @tablename + ' SET ikey = ' + cast(@var AS nvarchar(10)) + ' WHERE hashed = ''' + @hashed + ''''
		EXEC SP_EXECUTESQL @sql
		FETCH NEXT FROM @db_cursor INTO @hashed
	END
	CLOSE @db_cursor
	DEALLOCATE @db_cursor
GO

CREATE TABLE ikey_table (
	hashed varchar(65) NOT NULL UNIQUE,
	ikey int NOT NULL IDENTITY(1,1),
)
GO

CREATE UNIQUE INDEX hashed_index 
ON ikey_table (hashed)
GO