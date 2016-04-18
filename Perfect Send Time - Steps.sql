/*
Goal: calculate the perfect send day/time based on the activity history of user. 

Rules:
- Activity only measured in the past 90 days. Using the Taxonomy Table for that since it's currently configured on 90 days for performance
- A user must have opened at least two emails

This system should only be used for 'important campaigns'. If used in every campaign you won't get other numbers.
Standard monthly newsletters, and other minor mailings should be randomised in send timings to create/measure/test the open weekday-time.

Promo mailings, for example, can use the Perfect Send Time system

There are two options:
1) 	Set up for a whole week
	Triggers will be created for the whole week from 10:00 CET (09:00 GMT) until 22:00 CET (21:00 GMT)
2) 	Single day, with perfect hour
	For the specific day, triggers will be created from 10:00 CET (09:00 GMT) until 22:00 CET (21:00 GMT)
*/

--Preperation 
--CREATE Table for sub
declare @sub as VARCHAR(50) = 'SEBN'

declare @classification_table as VARCHAR(100) = @sub + '_DATA_PST_SEGMENT_CLASSIFICATION'
declare @counts_table as VARCHAR(100) = @sub + '_DATA_PST_SEGMENT_COUNTS'
declare @taxonomy_table as VARCHAR(100) = 'taxonomy_l1362_T8'

declare @sql as nvarchar(max)

SET @sql = '
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name=''' + @classification_table + ''' AND xtype=''U'')
    CREATE TABLE ' + @classification_table + ' (
        ID INT primary key IDENTITY(1,1) NOT NULL,
USERID	INT,
CREATED_DT	DateTime,	
MODIFIED_DT	DateTime,	
PREFERRED_WEEKDAY VARCHAR(3),
PREFERRED_HOUR	VARCHAR(3),
FROM_DT	DateTime,
TO_DT	DateTime,	
LISTID	INT,
PERFECT_HOUR VARCHAR(3)
)'

EXEC sp_executesql @sql

SET @sql = '
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name=''' + @counts_table + ''' AND xtype=''U'')
    CREATE TABLE ' + @counts_table + ' (
        ID INT primary key IDENTITY(1,1) NOT NULL,
USERID	INT,
CREATED_DT	DateTime,	
MODIFIED_DT	DateTime,	
COUNT_OPENS INT,
FOR_WEEKDAY INT,
FOR_HOUROFDAY INT,
LISTID	INT
)'

EXEC sp_executesql @sql

--STEP 0
SET @sql = 'truncate table ' + @sub + '_DATA_PST_SEGMENT_CLASSIFICATION' 
EXEC sp_executesql @sql

SET @sql = 'truncate table ' + @sub + '_DATA_PST_SEGMENT_COUNTS' 
EXEC sp_executesql @sql

declare @timewindow as int = -90
declare @country_id as int = 156
declare @listid as int = 0
declare @usertable as varchar(150) = 'Mys.' + @sub +'_Mys_USERS'
declare @optintable as varchar(150) = 'Mys.' + @sub +'_Mys_data_optin_pref'
declare @localetable as varchar(150) = 'Mys.' + @sub +'_Mys_data_locale'

SET @listid = (select ID from lists where tablename = @usertable)

--STEP1
--user selection 
-- ..no check BPM state because we want to know the opens of the welcome mails also.

SET @sql = '
MERGE ' + @classification_table + ' AS target USING 
(
	select id as userid from ' + @usertable + ' users (nolock)
	where 
		exists (
			select 1 from ' + @optintable + ' optins (nolock)
			where 
			MYSOPTINPREFID <> 3
			AND
			users.id = optins.userid
			)
		AND
		exists (
			select 1 from ' + @localetable + ' locale (nolock)
			where 
			myscountryid = ' + cast(@country_id as varchar(20)) + '
			AND
			users.id = locale.userid
		)
) AS source
  ON ( 		
  		target.userid = source.userid
  	 )
    WHEN NOT MATCHED THEN
  		INSERT (created_dt,userid,listid)
     	VALUES (getutcdate(),source.userid, '+ cast(@listid as varchar(20)) + ');'

EXEC sp_executesql @sql


--STEP2
--Count the opens
--sunday is weekday 1
SET @sql = '
MERGE ' + @counts_table + ' AS target
USING 
(
	select 
		userid, listid, 
		count(id) as COUNT_OPENS,
		DATEPART(WEEKDAY, dt) as weekday,
    	DATEPART(HOUR, dt) as hour 
    from flags (nolock)
	where 
	probeid <> 0
	AND
	listid = ' + cast(@listid as varchar(6)) + ' 
	and flags.dt > dateadd(day, ' + cast(@timewindow as VARCHAR(6)) + ',getdate())
	/* --temp disabled. Taxonomy on MYS was only recently activated. need more data
	and 
	 EXISTS (
	 		select 1 from ' + @taxonomy_table+ ' tax (nolock)
	 		where 
	 			MAILS_VIEWED > 2 
	 			and
	 			flags.userid = tax.userid
	 		)
	*/
	and 
	EXISTS
		( 
			select 1 from '+ @classification_table +' classification
			where classification.userid = flags.userid
		)
	--maybe add an exclude list? or whitelisting... campaigns
	group by userid, listid,DATEPART(WEEKDAY, dt),DATEPART(HOUR, dt)
) AS source
  ON ( 		
  		target.userid = source.userid 
  		and target.listid = source.listid 
 	 	and target.FOR_WEEKDAY = source.weekday
 	 	and target.FOR_HOUROFDAY = source.hour
 	 )
    WHEN MATCHED THEN 
        UPDATE SET COUNT_OPENS = source.COUNT_OPENS,modified_DT = getutcdate()
	WHEN NOT MATCHED THEN
  		INSERT (created_dt,userid,COUNT_OPENS,FOR_WEEKDAY,FOR_HOUROFDAY,listid)
     	VALUES (getutcdate(),source.userid, source.COUNT_OPENS,source.weekday,source.hour,source.listid);'

EXEC sp_executesql @sql


--STEP3
--add to segmentation table

SET @sql = '
UPDATE
    target 
SET
target.MODIFIED_DT = getutcdate(),
target.PREFERRED_WEEKDAY = source.weekday,
target.PREFERRED_HOUR = source.hour,
target.PERFECT_HOUR = source.phour
FROM '+ @classification_table+' target (nolock)
INNER JOIN
(
	select 
	a.userid as userid, 
	--perfect weekday
		(select top 1 for_weekday from ' + @counts_table + ' b (nolock) where a.userid = b.userid 
			group by for_weekday order by max(count_opens)) as weekday,
	--perfect hour for perfect weekday
		(select top 1 for_hourofday from ' + @counts_table + ' b (nolock) where a.userid = b.userid and for_weekday = 
			(select top 1 for_weekday from ' + @counts_table + ' b (nolock) where a.userid = b.userid 
				group by for_weekday order by max(count_opens)
			) 
			group by for_hourofday order by max(count_opens)
		) as hour,
	--perfect hour
		(select top 1 for_hourofday from ' + @counts_table + ' b (nolock) where a.userid = b.userid 
			group by for_hourofday order by max(count_opens)) as phour
	from ' + @counts_table + ' a (nolock)
	group by userid
) source
ON 
    target.userid = source.userid'

 EXEC sp_executesql @sql

--STEP4 + 5
--define defaults (4) and update (5), using the TOP 1 of counts (highest amount of opens) to check the most counts on which day,hour, hour alone (perfect hour) 

SET @sql = '
declare @default_weekday as int
declare @default_hourofday as int

select top 1 @default_weekday=for_weekday, @default_hourofday = FOR_HOUROFDAY
from '+ @counts_table +'
group by 
for_weekday, 
for_hourofday
order by count(count_opens) desc

declare @default_perfecthour as int

select top 1 @default_perfecthour = FOR_HOUROFDAY
from '+ @counts_table +'
group by 
for_hourofday
order by count(count_opens) desc

UPDATE
    classification 
SET
classification.MODIFIED_DT = getutcdate(),
classification.PREFERRED_WEEKDAY = @default_weekday,
classification.PREFERRED_HOUR = @default_hourofday,
classification.PERFECT_HOUR = @default_perfecthour
from '+ @classification_table +' classification (nolock)
where 
not exists (select 1 from '+ @counts_table +' counts (nolock) where counts.userid = classification.userid)
'
EXEC sp_executesql @sql


--STEP6a
--create campaign
/*
Create a triggered campaign, Add two required parameters named: 
PREFERRED_WEEKDAY	Text
PREFERRED_HOUR		Text

Add a list, open de query editor
Add two contraints on scope PERFECT_SEND_TIME, 
field: PREFERRED_WEEKDAY  to be equal to #PREFERRED_WEEKDAY (notice the hashtag)
AND
field: PREFERRED_HOUR  to be equal to #PREFERRED_HOUR (notice the hashtag)
AND ... any other filters you want. Be aware of any OR statement which can invalidate the first two AND statements.

build the flow as normal.

*/

--STEP7a
--create day/hour triggers for a whole week.

--Test table
--create table #psttemp (datehour datetime,hour int)

declare @campaignid as INT = 6100
declare @startdate as datetime = '2016-03-08 00:00:00' --input for startdate, will be parameter if used in SP

declare @starthour as INT = 9; --GMT 09:00 , CET 10:00
declare @endhour as INT = 21; --GMT 21:00 , CET 22:00

declare @startday as INT = 1; --sunday
declare @endday as int = 7;

declare @daycounter as INT = @startday;
declare @hourcounter as INT = @starthour; 

declare @insertdate as datetime;

declare @offset as int = 3; --used in the calculation for the correct datetime.

declare @xml as nvarchar(max);

while (@daycounter <= @endday)
begin 

	SET @hourcounter = @starthour;
	SET @startdate = dateadd(day,1,@startdate)
		
	while (@hourcounter <= @endhour)
	begin		
		if (@hourcounter >= @starthour AND @hourcounter <= @endhour)
		begin
		
		set @insertdate = dateadd(hh, @hourcounter, dateadd(yy, year(@startdate) - 1900, dateadd(dd, datepart(dy,@startdate) - @offset, 0)))
			
	--	insert into #psttemp (datehour) values (@insertdate)
	
		SET @xml = '<NONAME><PARAMS><PARAM NAME="PREFERRED_WEEKDAY"><![CDATA['+ CAST(@daycounter AS VARCHAR(3)) +']]></PARAM><PARAM NAME="PREFERRED_HOUR"><![CDATA['+ CAST(@hourcounter AS VARCHAR(3)) +']]></PARAM></PARAMS></NONAME>'
		INSERT INTO CAMPAIGNTRIGGERFLAGS 
		(campaignid, start_dt,enabled,reqconfirm, state, xml)
		SELECT @campaignid, @insertdate, 1, 0, 0, @xml
	
		END

		SET @hourcounter = @hourcounter + 1
	end

SET @daycounter = @daycounter + 1
end

--test table
--select * from #psttemp
--drop table #psttemp


--STEP6b
--create campaign FOR PERFECT HOUR
/*
Create a triggered campaign, Add a required parameter named: 
PERFECT_HOUR		Text

Add a list to the flow, open de query editor
Add a contraints on scope PERFECT_SEND_TIME, 
field: PERFECT_HOUR  to be equal to #PERFECT_HOUR (notice the hashtag)
AND ... any other filters you want. Be aware of any OR statement which can invalidate the first statement

build the flow as normal.
*/

--STEP7b
--create perfect hour triggers for one day.

--Test table
--create table #psttemp (datehour datetime,hour int)

/*declare @campaignid as INT = 6100
declare @startdate as datetime = '2016-03-09 00:00:00' --input for startdate, will be parameter if used in SP

declare @starthour as INT = 9; --GMT 09:00 , CET 10:00
declare @endhour as INT = 21; --GMT 21:00 , CET 22:00

declare @hourcounter as INT = @starthour; 

declare @insertdate as datetime;

declare @offset as int = 2; --used in the calculation for the correct datetime.

declare @xml as nvarchar(max);

while (@hourcounter <= @endhour)
begin		
	if (@hourcounter >= @starthour AND @hourcounter <= @endhour)
	begin
	
	set @insertdate = dateadd(hh, @hourcounter, dateadd(yy, year(@startdate) - 1900, dateadd(dd, datepart(dy,@startdate) - @offset, 0)))
		
--	insert into #psttemp (datehour) values (@insertdate)
	
	SET @xml = '<NONAME><PARAMS><PARAM NAME="PERFECT_HOUR"><![CDATA[' + CAST(@hourcounter AS VARCHAR(3)) + ']]></PARAM></PARAMS></NONAME>'
	INSERT INTO CAMPAIGNTRIGGERFLAGS 
	(campaignid, start_dt,enabled,reqconfirm, state, xml)
	SELECT @campaignid, @insertdate, 1, 0, 0, @xml
	
	END

	SET @hourcounter = @hourcounter + 1
end
*/
