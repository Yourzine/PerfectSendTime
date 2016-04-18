select top 1000 count(a.id) as count, campaignid, 
min(run_dt),-- run_dt mischien niet gebruiken als er schedule op zit... moet de eerste mail misschien checken.
--(select count(id) from flags b (nolock) where b.campaignid = a.campaignid and probeid = 0) as numbersent,
DATEPART(YEAR, dt) as year,
DATEPART(MONTH, dt) as month,
DATEPART(DAY, dt) as day,
DATEPART(WEEKDAY, dt) as weekday,
DATEPART(HOUR, dt) as hour
from flags a (nolock)
inner join campaigns on a.campaignid = campaigns.id and run_dt <> ''
where
dt > dateadd(day,-5,getdate())
and
probeid < 0
group by
campaignid, 
DATEPART(YEAR, dt),
DATEPART(MONTH, dt),
DATEPART(DAY, dt),
DATEPART(WEEKDAY, dt),
DATEPART(HOUR, dt)
ORDER BY 
DATEPART(YEAR, dt),
DATEPART(MONTH, dt),
DATEPART(DAY, dt),
DATEPART(WEEKDAY, dt),
DATEPART(HOUR, dt)


select top 1000 count(a.id) as opens,
--campaignid, 
CAST(AVG(CAST(run_dt AS FLOAT)) AS DATETIME) as avgrundate, -- run_dt mischien niet gebruiken als er schedule op zit... moet de eerste mail misschien checken.
--(select count(id) from flags b (nolock) where b.campaignid = a.campaignid and probeid = 0) as numbersent,
DATEPART(YEAR, dt) as year,
DATEPART(MONTH, dt) as month,
DATEPART(DAY, dt) as day,
DATEPART(WEEKDAY, dt) as weekday,
DATEPART(HOUR, dt) as hour
from flags a (nolock)
inner join campaigns on a.campaignid = campaigns.id and run_dt <> ''
where
dt > dateadd(day,-5,getdate())
and
probeid < 0
group by
campaignid, 
DATEPART(YEAR, dt),
DATEPART(MONTH, dt),
DATEPART(DAY, dt),
DATEPART(WEEKDAY, dt),
DATEPART(HOUR, dt)
ORDER BY 
DATEPART(YEAR, dt),
DATEPART(MONTH, dt),
DATEPART(DAY, dt),
DATEPART(WEEKDAY, dt),
DATEPART(HOUR, dt)



select top 1000 count(a.id) as opens,
--campaignid, 
--CAST(AVG(CAST(run_dt AS FLOAT)) AS DATETIME) as avgrundate, -- run_dt mischien niet gebruiken als er schedule op zit... moet de eerste mail misschien checken.
--DATEPART(WEEKDAY, CAST(AVG(CAST(run_dt AS FLOAT)) AS DATETIME)),
--(select count(id) from flags b (nolock) where b.campaignid = a.campaignid and probeid = 0) as numbersent,
--DATEPART(YEAR, dt) as year,
--DATEPART(MONTH, dt) as month,
--DATEPART(DAY, dt) as day,
DATEPART(WEEKDAY, dt) as weekday,
DATEPART(HOUR, dt) as hour
from flags a (nolock)
inner join campaigns on a.campaignid = campaigns.id and run_dt <> ''
where
exists (select 1 from mys.SEBN_Mys_DATA_LOCALE (nolock) where a.id = mys.SEBN_Mys_DATA_LOCALE.userid and myscountryid = 156)
and
dt > dateadd(day,-20,getdate())
and
probeid < 0
--and DATEPART(HOUR, dt) = 12
--and DATEPART(WEEKDAY, dt) = 1
group by
--campaignid, 
--DATEPART(YEAR, dt),
--DATEPART(MONTH, dt),
--DATEPART(DAY, dt),
DATEPART(WEEKDAY, dt),
DATEPART(HOUR, dt)
ORDER BY 
--DATEPART(YEAR, dt),
--DATEPART(MONTH, dt),
--DATEPART(DAY, dt),
DATEPART(WEEKDAY, dt),
DATEPART(HOUR, dt)




select count(a.id) as opens,
--campaignid, 
--CAST(AVG(CAST(run_dt AS FLOAT)) AS DATETIME) as avgrundate, -- run_dt mischien niet gebruiken als er schedule op zit... moet de eerste mail misschien checken.
--DATEPART(WEEKDAY, CAST(AVG(CAST(run_dt AS FLOAT)) AS DATETIME)),
--(select count(id) from flags b (nolock) where b.campaignid = a.campaignid and probeid = 0) as numbersent,
--DATEPART(YEAR, dt) as year,
--DATEPART(MONTH, dt) as month,
--DATEPART(DAY, dt) as day,
DATEPART(WEEKDAY, dt) as weekday,
DATEPART(HOUR, dt) as hour
from flags a (nolock)
inner join campaigns on a.campaignid = campaigns.id and run_dt <> ''
where
--exists (select 1 from mys.SEBN_Mys_DATA_LOCALE (nolock) where a.userid = mys.SEBN_Mys_DATA_LOCALE.userid and myscountryid = 156)
exists (select 1 from goc_customer (nolock) where a.userid = goc_customer.id and country_id = 156)
and
dt > dateadd(day,-20,getdate())
and
probeid < 0
--and DATEPART(HOUR, dt) = 12
--and DATEPART(WEEKDAY, dt) = 1
group by
--campaignid, 
--DATEPART(YEAR, dt),
--DATEPART(MONTH, dt),
--DATEPART(DAY, dt),
DATEPART(WEEKDAY, dt),
DATEPART(HOUR, dt)
ORDER BY 
--DATEPART(YEAR, dt),
--DATEPART(MONTH, dt),
--DATEPART(DAY, dt),
DATEPART(WEEKDAY, dt),
DATEPART(HOUR, dt)

update DATA_PST_SEBN set SEGMENT1_COUNT = (
	select count(id) from flags 
	where 
	probeid < 0 
	and DATEPART(WEEKDAY, dt) = 6 
	and DATEPART(HOUR, dt) = 15
	and EXISTS (select 1 from goc_customer (nolock) where flags.userid = goc_customer.id and country_id = 156)
	and dt > dateadd(day,-20,getdate())
	and flags.userid = DATA_PST_SEBN.userid
	)






------------------------------------
select max(COUNT_OPENS) as opens, for_weekday,FOR_HOUROFDAY
from SEBN_DATA_PST_SEGMENT_COUNTS
where userid = 1560
group by
 for_weekday,FOR_HOUROFDAY

select avg(for_weekday),avg(FOR_HOUROFDAY)
from SEBN_DATA_PST_SEGMENT_COUNTS
where 
COUNT_OPENS >= 2
group by
 for_weekday,FOR_HOUROFDAY


select top 1 count(count_opens),avg(for_weekday),avg(FOR_HOUROFDAY)
from SEBN_DATA_PST_SEGMENT_COUNTS
group by 
for_weekday, for_hourofday
order by count(count_opens) desc

select count(count_opens),avg(for_weekday),avg(FOR_HOUROFDAY)
from SEBN_DATA_PST_SEGMENT_COUNTS
group by 
for_weekday--, for_hourofday
order by count(count_opens) desc

select count(count_opens),avg(for_weekday),avg(FOR_HOUROFDAY)
from SEBN_DATA_PST_SEGMENT_COUNTS
group by 
for_weekday, for_hourofday
order by count(count_opens) desc

--dlete from list if in state > 18