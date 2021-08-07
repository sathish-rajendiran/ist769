USE [demo]
GO
/***************************************************************************************************
	Name: Sathish Kumar Rajendiran      	           
	SUID: 666555028
	Email: srajendi@syr.edu
	Date Due: 07/27/2021 
	Topic: Transactions and Temporal Tables
	Homework #:3
*****************************************************************************************************
1. 	In the Demo database, create two tables:
	a. 	The first table players should have columns player id (int pk), player name (varchar), 
		shots attempted (int), shots made (int)
	b. 	The second table shots should have columns shot id (int pk), player id (int fk to players), 
		clock time (datetime), shot made (bit)
	c. 	Add two players to the players table. Mary and Sue initialize the players with 0 shots 
		attempted and made.

**********************************************************************************************************
							Drop players and shots user tables if exist
*********************************************************************************************************/
	
	/*********** Cleaning up Histroy Table  *******************/
	---Turn Versioning Off
	ALTER TABLE dbo.players
	SET (SYSTEM_VERSIONING = OFF);
	GO


	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='shots')
		BEGIN
			DROP TABLE dbo.shots
		END
	GO

	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='players')
		BEGIN
			DROP TABLE dbo.players
		END
	GO

	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='players_history')
		BEGIN
			DROP TABLE dbo.players_history
		END
	GO

	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='DB_Errors')
		BEGIN
			DROP TABLE dbo.DB_Errors
		END
	GO

/***********************   Table Creation   ***********************************************************/

	----dbo.players table creation
	CREATE TABLE dbo.players(
  		player_id INT NOT NULL IDENTITY,
  		player_name VARCHAR(80) NOT NULL,
  		shots_attempted INT,
  		shots_made INT,
  		CONSTRAINT players_PK PRIMARY KEY (player_id)
		)
	GO

	----dbo.shots table creation
	CREATE TABLE dbo.shots(
  		shot_id INT NOT NULL IDENTITY PRIMARY KEY,
  		player_id INT NOT NULL FOREIGN KEY REFERENCES dbo.players(player_id),
  		clock_time DATETIME NOT NULL,
  		shot_made BIT NOT NULL default 'FALSE'
		)
	GO

	---- Table to record errors
 	CREATE TABLE dbo.DB_Errors
			 (ErrorID        INT IDENTITY(1, 1),
			  UserName       VARCHAR(100),
			  ErrorNumber    INT,
			  ErrorState     INT,
			  ErrorSeverity  INT,
			  ErrorLine      INT,
			  ErrorProcedure VARCHAR(MAX),
			  ErrorMessage   VARCHAR(MAX),
			  ErrorDateTime  DATETIME)
	GO

/***********************   Data Population   ***********************************************************/
	INSERT INTO players (player_name, shots_attempted, shots_made)
	VALUES ('Mary', 0, 0),('Sue',0,0)
	GO
 
	SELECT * from dbo.players
	GO
	SELECT * from dbo.shots
	GO

/*****************************************************************************************************

2. 	Write transaction safe code as a stored procedure which when given a player id, 
	clock time, and whether the shot was made (bit value) will add the record to the shots table 
	and update the player record in the players table. For example, If Mary takes a shot 
	and makes it, then misses the next one, there would be two records in the shots table and 
	her row in the players table should have 2 attempt and 1 shot made. 
	
	Execute the stored procedure to demonstrate the transaction is ACID compliant. 

*******************************  Stored Procedure Creation - Begins ***************************
	----- p_write_shot - Creation
	----- This Stored procedure update/insert data into  fudgemart_vendors
	----- Input value: @player_id,@clock_time and @shot_made
	----- Output : if @player_id exists then shot detail is inserted into shots table 
				  and respective transaction also updated on the players table */

	IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME='p_write_shot')
	BEGIN
		DROP PROCEDURE p_write_shot
	END
	GO

	CREATE PROCEDURE dbo.p_write_shot(
  		@player_id INT,
  		@clock_time datetime,
  		@shot_made bit
  		)
	AS
	BEGIN TRY
  		BEGIN TRANSACTION
  	
		INSERT INTO dbo.shots (player_id, clock_time, shot_made)
  			SELECT @player_id, @clock_time,@shot_made
	  ----	if @@ROWCOUNT <> 1 
			----THROW 50005, 'Failed to insert into shots table, zero rows affected',0;
	   
   		UPDATE dbo.players
        		SET shots_attempted = COALESCE (shots_attempted, 0) + 1,
              		shots_made = CASE @shot_made WHEN 1 THEN COALESCE (shots_made, 0) + 1
                          	        		ELSE  shots_made END
  		WHERE player_id = @player_id
	  ----	if @@ROWCOUNT <> 1 
			----THROW 50006,'Failed to update into player table, zero rows affected',0;
		COMMIT TRANSACTION
	END TRY

	BEGIN CATCH
 		INSERT INTO dbo.DB_Errors
		VALUES
		  (SUSER_SNAME(),
		   ERROR_NUMBER(),
		   ERROR_STATE(),
		   ERROR_SEVERITY(),
		   ERROR_LINE(),
		   ERROR_PROCEDURE(),
		   ERROR_MESSAGE(),
		   GETDATE());

		---- Transaction uncommittable
		IF (XACT_STATE()) = -1
		  ROLLBACK TRANSACTION
 
		---- Transaction committable
		IF (XACT_STATE()) = 1
		  COMMIT TRANSACTION
	END CATCH
	GO

	/********* Validation **********************************************************************/
	--select * from dbo.players
	--select * from dbo.shots
	------Udate/Insert into p_write_vendor table
	EXEC dbo.p_write_shot @player_id=1, @clock_time='2021/07/26 16:00:00', @shot_made='TRUE'
	GO
	EXEC dbo.p_write_shot @player_id=1, @clock_time='2021/07/26 16:05:00', @shot_made='TRUE'
	GO
	EXEC dbo.p_write_shot @player_id=2, @clock_time='2021/07/26 16:00:00', @shot_made='TRUE'
	GO
	EXEC dbo.p_write_shot @player_id=2, @clock_time='2021/07/26 16:05:00', @shot_made='FALSE'
	GO
	EXEC dbo.p_write_shot @player_id=1, @clock_time='2021/07/26 16:00:00', @shot_made='TRUE'
	GO
	EXEC dbo.p_write_shot @player_id=1, @clock_time='2021/07/26 16:05:00', @shot_made='TRUE'
	GO
	----negative scenarios
	EXEC dbo.p_write_shot @player_id=10, @clock_time='2021/07/26 16:00:00', @shot_made='TRUE'  --foreign key violation on player_id - failure
	GO
	EXEC dbo.p_write_shot @player_id=1, @clock_time='2021/07/26 16:00:00',@shot_made=NULL  --NOT NULL exception -failure
	GO

	select * from dbo.shots
	select * from dbo.players
	select * from dbo.DB_Errors

/*****************************************************************************************************
3. 	Alter the players table to be a system-versioned temporal table.
 */
	----alter dbo.players table to add hidden columns that are used as version columns
	ALTER TABLE dbo.players
	----Add the system versioning history table
	ADD StartTime DATETIME2 GENERATED ALWAYS AS ROW START 
		HIDDEN DEFAULT GETUTCDATE(),
		EndTime  DATETIME2 GENERATED ALWAYS AS ROW END 
		HIDDEN DEFAULT 
			CONVERT(DATETIME2, '9999-12-31 23:59:59.9999999'),
		PERIOD FOR SYSTEM_TIME (StartTime, EndTime);
	GO
	----Turn on the System_Versioning to player table on players_history table
	ALTER TABLE dbo.players
	SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE=dbo.players_history));
	GO

	select * from dbo.players
	select * from dbo.players_history

/*****************************************************************************************************
4. 	Execute your stored procedure from part 2 to create at least 15 shot records over a 5-minute period. 
Make sure there are records in the first ½ of the 5-minute period
and at few in the last minute of the 5-minute period.
*/   
	/* Delete all records from shots and players table */
	--Delete from dbo.shots
	--Go
	--Delete from dbo.players
	--Go
	SELECT * FROM dbo.players
	SELECT * FROM dbo.shots
	--***********************insert records*******************************************
	--INSERT INTO players (player_name, shots_attempted, shots_made)
	--VALUES ('Mary', 0, 0),('Sue',0,0)
	--GO
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:55:00',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:55:10',@shot_made =1
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:55:20',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:55:30',@shot_made =1
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:55:40',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:55:50',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:56:00',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:56:10',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:56:20',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:56:30',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:56:40',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:56:50',@shot_made =0
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:57:00',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:57:10',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:57:20',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:57:30',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:57:40',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:57:50',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:58:00',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:58:10',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:58:20',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:58:30',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:58:40',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:58:50',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:59:00',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:59:10',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:59:20',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:59:30',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 18:59:40',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 18:59:50',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:00:00',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:00:10',@shot_made =1;
	WAITFOR DELAY '00:00:05'
 	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:00:20',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:00:30',@shot_made =1
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:00:40',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:00:50',@shot_made =1
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:01:00',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:01:10',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:01:20',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:01:30',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:01:40',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:01:50',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:02:00',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:02:10',@shot_made =0
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:02:20',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:02:30',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:02:40',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:02:50',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:03:00',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:03:10',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:03:20',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:03:30',@shot_made =0;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:03:40',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:03:50',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:04:00',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:04:10',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:04:20',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:04:30',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:04:40',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:04:50',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:05:00',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:05:10',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=1, @clock_time = '2021/07/26 19:05:20',@shot_made =1;
	WAITFOR DELAY '00:00:05'
	EXEC dbo.p_write_shot @player_id=2, @clock_time = '2021/07/26 19:05:30',@shot_made =1;
	WAITFOR DELAY '00:00:05'
 
	SELECT * FROM dbo.players
	select * from dbo.players_history
 
/*****************************************************************************************************
5. 	Write SQL queries to show:
	a. 	The player statistics at the end of the 5-minute period (current statistics).
	b. 	The player statistics exactly 2 minutes and 30 seconds into the period.
	c.  The player statistics in the last minute of the period.
********************************************************************************************************/


/*********** Cleaning up Histroy Table  *******************/
	----Turn Versioning Off
	--ALTER TABLE dbo.players
	--SET (SYSTEM_VERSIONING = OFF);
	--GO


	--all from players_history versioning table
	select * from dbo.players
	--where player_id in(5,6)

	select * from dbo.shots

	----select all records 
	select * from dbo.players 
	for system_time all
	--where player_id in(5,6)
	order by shots_attempted

	--All shots entered
	select * from dbo.players_history
	--where player_id in(5,6)
    order by shots_attempted

--time range
	select 
	 min(StartTime) min_StartTime
	,min(EndTime) min_EndTime
	,max(StartTime) max_StartTime
	,max(EndTime) max_EndTime
	,datediff(minute,min(StartTime),max(StartTime)) startTime_range_in_minutes
	,datediff(minute,min(EndTime),max(EndTime)) endtime_range_in_minutes
	,datediff(minute,min(StartTime),max(EndTime)) overall_range_in_minutes
	from dbo.players_history
	--where player_id in(5,6)	


	
	----select with as of time frame record
	select * from dbo.players 
	for system_time AS OF '2021-07-27 01:14'

	----select changes between time frames
	select * from dbo.players 
	for system_time between '2021-07-27 01:04:00' and '2021-07-27 01:06:30'

	----select changes in the last minute
	select * from dbo.players 
	for system_time between '2021-07-27 01:14:00' and '2021-07-27 01:14:00'
