/*********************************************************************************
IST769 Homework Submission
Name: Sathish Kumar Rajendiran      	           
SUID: 666555028
Email: srajendi@syr.edu
Date Due: 08/03/2021 
Date Due: Performance, Security, NoSQL
Homework #:4
************************************************************************************
1. 	Create a non-clustered index on the timesheets table in the demo database. 
The index you create should be designed to improve the following query:
    
select employee_id, employee_firstname, employee_lastname, 
sum(timesheet_hourlyrate*timesheet_hours)
from timesheets
group by employee_id, employee_firstname, employee 
*/

----Pre-setup command
----Use [fudgemart_v3]
----Go
----select * into demo.dbo.timesheets
----from fudgemart_employees join fudgemart_employee_timesheets
----on employee_id = timesheet_employee_id
----Go

USE [demo]
GO

SET STATISTICS TIME ON
SET STATISTICS IO ON
GO

--before Index creation    
declare @startTime datetime2
declare @endTime datetime2
set @startTime = getdate()
select employee_id, employee_firstname, employee_lastname, 
sum(timesheet_hourlyrate*timesheet_hours) as wages
from timesheets
group by employee_id, employee_firstname, employee_lastname 
set @endTime = getdate()
---total execution time in milliseconds
select datediff(millisecond,@startTime,@endTime) as execTime
GO

SET STATISTICS TIME OFF
SET STATISTICS IO OFF
GO

---- Find an existing index named IX_Timesheets_EmployeeID_Name_Hours_Rate and delete it if found.   
IF EXISTS (SELECT name FROM sys.indexes  
        WHERE name = N'IX_Timesheets_EmployeeID_Name_Hours_Rate')   
DROP INDEX IX_Timesheets_EmployeeID_Name_Hours_Rate ON dbo.timesheets;   
GO  


-- Create a nonclustered index called IX_Timesheets_EmployeeID_Name_Hours_Rate   
-- on the dbo.timesheets table using the employee_id, employee_firstname,employee_lastname,timesheet_hourlyrate,timesheet_hours columns.   
CREATE NONCLUSTERED INDEX IX_Timesheets_EmployeeID_Name_Hours_Rate   
ON dbo.timesheets (employee_id)
INCLUDE (employee_firstname, employee_lastname,timesheet_hourlyrate,timesheet_hours)
GO  


SET STATISTICS TIME ON
SET STATISTICS IO ON
GO

--after Index creation    
declare @startTime datetime2
declare @endTime datetime2
set @startTime = getdate()
select employee_id, employee_firstname, employee_lastname, 
sum(timesheet_hourlyrate*timesheet_hours) as wages
from timesheets
group by employee_id, employee_firstname, employee_lastname 
set @endTime = getdate()
---total execution time in milliseconds
select datediff(millisecond,@startTime,@endTime) as execTime
GO

SET STATISTICS TIME OFF
SET STATISTICS IO OFF
GO

/**********************************************************************************
2. Write an SQL Select query which uses the index you created in the first question but does an index seek instead of an index scan.
*/

SET STATISTICS TIME ON
SET STATISTICS IO ON
GO

--after Index creation    
declare @startTime datetime2
declare @endTime datetime2
--declare @maxemployeeID int
set @startTime = getdate()
--select @maxemployeeID = max(employee_id) from dbo.timesheets
select employee_id, employee_firstname, employee_lastname, 
sum(timesheet_hourlyrate*timesheet_hours) as wages
from timesheets
where employee_id < 50
--where employee_id < ( select max(employee_id) from dbo.timesheets)
--where employee_id < @maxemployeeID
group by employee_id, employee_firstname, employee_lastname 
set @endTime = getdate()
---total execution time in milliseconds
select datediff(millisecond,@startTime,@endTime) as execTime
GO

SET STATISTICS TIME OFF
SET STATISTICS IO OFF
GO

/***************************************************************************
3. Create a single columnstore index on the timesheets table in the demo database which will improve the following queries:
	
select employee_department, sum(timesheet_hours)
from timesheets group by employee_department
 
select employee_jobtitle, avg(timesheet_hourlyrate)
from timesheets group by employee_jobtitle
*/
SET STATISTICS TIME ON
SET STATISTICS IO ON
GO

--before Index creation    
declare @startTime datetime2
declare @endTime datetime2
set @startTime = getdate()

select employee_department
, sum(timesheet_hours) agg_timesheet_hours
from timesheets
group by employee_department
set @endTime = getdate()

---total execution time in milliseconds
select datediff(millisecond,@startTime,@endTime) as execTime
GO

SET STATISTICS TIME OFF
SET STATISTICS IO OFF
GO

---- Find an existing index named IX_CLM_Timesheets_Employee_Department_Hours
---- and delete it if found.   
IF EXISTS (SELECT name FROM sys.indexes  
        WHERE name = N'IX_CLM_Timesheets')   
DROP INDEX IX_CLM_Timesheets ON dbo.timesheets;   
GO  
-- Create a nonclustered COLUMNSTORE index called IX_CLM_Timesheets   
-- on the dbo.timesheets table using the employee_id, employee_department,timesheet_hours,timesheet_hourlyrate,timesheet_hours columns.

CREATE NONCLUSTERED COLUMNSTORE INDEX IX_CLM_Timesheets   
ON dbo.timesheets(employee_department,timesheet_hours)
GO  


SET STATISTICS TIME ON
SET STATISTICS IO ON
GO

--after Index creation    
declare @startTime datetime2
declare @endTime datetime2
set @startTime = getdate()

select employee_department
, sum(timesheet_hours) agg_timesheet_hours
from timesheets
group by employee_department
set @endTime = getdate()

---total execution time in milliseconds
select datediff(millisecond,@startTime,@endTime) as execTime
GO

SET STATISTICS TIME OFF
SET STATISTICS IO OFF
GO

/********************************************************/

SET STATISTICS TIME ON
SET STATISTICS IO ON
GO

--before Index creation    
declare @startTime datetime2
declare @endTime datetime2
set @startTime = getdate()

select employee_jobtitle
, avg(timesheet_hourlyrate) avg_hourlyrate
from timesheets 
group by employee_jobtitle
set @endTime = getdate()

---total execution time in milliseconds
select datediff(millisecond,@startTime,@endTime) as execTime
GO

SET STATISTICS TIME OFF
SET STATISTICS IO OFF
GO

IF EXISTS (SELECT name FROM sys.indexes  
        WHERE name = N'IX_CLM_Timesheets')   
DROP INDEX IX_CLM_Timesheets ON dbo.timesheets;   
GO  
-- Create a nonclustered COLUMNSTORE index called IX_CLM_Timesheets   
-- on the dbo.timesheets table using the employee_id, employee_department,timesheet_hours,timesheet_hourlyrate,timesheet_hours columns.

CREATE NONCLUSTERED COLUMNSTORE INDEX IX_CLM_Timesheets   
ON dbo.timesheets(employee_department,timesheet_hours,employee_jobtitle,timesheet_hourlyrate)
GO  

SET STATISTICS TIME ON
SET STATISTICS IO ON
GO

--after Index creation    
declare @startTime datetime2
declare @endTime datetime2
set @startTime = getdate()

select employee_jobtitle
, avg(timesheet_hourlyrate) avg_hourlyrate
from timesheets 
group by employee_jobtitle
set @endTime = getdate()

---total execution time in milliseconds
select datediff(millisecond,@startTime,@endTime) as execTime
GO

SET STATISTICS TIME OFF
SET STATISTICS IO OFF
GO

/***************************************************************************

4. Create an indexed view named v_employees on the timesheets table in the demo database which lists the employee id, first name, last name, job title, and department columns values and one row per employee (essentially re-building the employee table). Then set a unique clustered index on the view and finish by writing an SQL Select query which uses the indexed view.
*/

/**********************  SQL Views Creation - Begins ***************************
----- v_employees - Creation
----- This view returns product details. 
*/

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_NAME='v_employees')
BEGIN
DROP VIEW v_employees
END
GO

CREATE VIEW  v_employees WITH schemabinding
AS
SELECT    employee_id
	, employee_firstname
	, employee_lastname
	, employee_jobtitle
	, employee_department 
	,COUNT_BIG(*) as employee_count
from dbo.timesheets
Group by
employee_id
, employee_firstname
, employee_lastname
, employee_jobtitle
, employee_department
GO

--before index creation
SELECT * FROM dbo.v_employees
GO


IF EXISTS (SELECT name FROM sys.indexes  
        WHERE name ='IX_CLS_v_employees_EmployeeID')   
DROP INDEX IX_CLS_v_employees_EmployeeID ON dbo.v_employees;   
GO  
-- Create an unique clustered index called IX_CLS_v_employees_EmployeeID   
-- on the dbo.v_employees table using the employee_id

CREATE UNIQUE CLUSTERED  INDEX IX_CLS_v_employees_EmployeeID   
ON dbo.v_employees(employee_id)
GO  
--query from the view after index creation
SELECT * FROM dbo.v_employees
GO

/***************************************************************************
5. Output the following query in JSON format: Display the employee id, first name, last name, count of timesheets, total hours worked, and average timesheet hourly rate.
*/
--simple select sql with SQL Output
select
      employee_id
  	, employee_firstname
  	, employee_lastname
  	, count(*) as timesheet_count
  	, sum(timesheet_hours) as total_hours_worked
  	, AVG(timesheet_hourlyrate) as avg_timesheet_rate
from timesheets
group by 
      employee_id
  	, employee_firstname
  	, employee_lastname
Go

--SQL statement with NOSQL Output
select
      employee_id
  	, employee_firstname , employee_lastname
  	, count(*) as timesheet_count
  	, sum(timesheet_hours) as total_hours_worked
  	, AVG(timesheet_hourlyrate) as avg_timesheet_rate
from timesheets
group by 
      employee_id
  	, employee_firstname
  	, employee_lastname
FOR JSON AUTO
GO




