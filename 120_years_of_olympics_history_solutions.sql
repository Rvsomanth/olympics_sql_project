CREATE TABLE IF NOT EXISTS OLYMPICS_HISTORY
(
    ID          INT,
    NAME        VARCHAR,
    SEX         VARCHAR,
    AGE         VARCHAR,
    HEIGHT      VARCHAR,
    WEIGHT      VARCHAR,
    TEAM        VARCHAR,
    NOC         VARCHAR,
    GAMES       VARCHAR,
    YEAR        INT,
    SEASON      VARCHAR,
    CITY        VARCHAR,
    SPORT       VARCHAR,
    EVENT       VARCHAR,
    MEDAL       VARCHAR
);

CREATE TABLE IF NOT EXISTS OLYMPICS_HISTORY_NOC_REGIONS
(
    noc         VARCHAR,
    region      VARCHAR,
    notes       VARCHAR
);


select * from public.OLYMPICS_HISTORY;
select * from public.OLYMPICS_HISTORY_NOC_REGIONS;

--1 How many olympics games have been held?

select count(distinct games) from OLYMPICS_HISTORY;

--2 List down all Olympics games held so far?

select distinct year, season, city from OLYMPICS_HISTORY
order by 1;

--3 Mention the total no of nations who participated in each olympics game?

with cte as (select oh.games,ohn.region from OLYMPICS_HISTORY oh
join OLYMPICS_HISTORY_NOC_REGIONS ohn
on oh.noc=ohn.noc
group by oh.games,ohn.region)
select games, count(region) from cte
group by games
order by games;

-- 4 Which year saw the highest and lowest no of countries participating in olympics?

with cte as (select oh.games,ohn.region from OLYMPICS_HISTORY oh
join OLYMPICS_HISTORY_NOC_REGIONS ohn
on oh.noc=ohn.noc
group by oh.games,ohn.region),
cte2 as ( select games, count(region) as total_count from cte
		 group by games)
select distinct concat(first_value(games) over (order by total_count),
					  '-',first_value(total_count) over (order by total_count desc))
					   as highest_participants,
					   concat(first_value(games) over (order by total_count),
					  '-',first_value(total_count) over (order by total_count))
					   as lowest_participants from cte2
					   

-- 5 Which nation has participated in all of the olympic games? 

with cte as (
select *,
dense_rank() over (order by total_cnt desc) as dn from 
(select count(distinct oh.games) as total_cnt,ohn.region from OLYMPICS_HISTORY oh
join OLYMPICS_HISTORY_NOC_REGIONS ohn
on oh.noc=ohn.noc
group by ohn.region 
order by 1 desc) x) 
select region,total_cnt from cte where dn=1;
 
--6 Identify the sport which was played in all summer olympics?

with cte as (
select *,
dense_rank() over (order by total_cnt desc) as dn from 
(select distinct(sport) as sports,count(distinct games) as total_cnt 
from OLYMPICS_HISTORY oh
join OLYMPICS_HISTORY_NOC_REGIONS ohn
on oh.noc=ohn.noc
where oh.season ='Summer'
group by 1
order by 2 desc)x)
select sports,total_cnt from cte
where dn=1;
-------------------------------------------------------------
with cte as (
	select count(distinct(games)) as total_games from OLYMPICS_HISTORY
	where season='Summer'),
total_games as (
	select distinct(games),sport from OLYMPICS_HISTORY
	where season='Summer'),
total_sport_games_summer as (
	select sport,count(games) as no_of_games from total_games
	group by sport)
select * from total_sport_games_summer ts
join cte c
on ts.no_of_games=c.total_games;
 
--7 Which Sports were just played only once in the olympics?

with cte1 as (
select distinct(games) as game,sport from OLYMPICS_HISTORY),
cte2 as (
select sport,count(game) as cnt_game from cte1 group by sport)
select c1.game,c2.*
from cte1 c1
join cte2 c2
on c1.sport = c2.sport
where cnt_game =1
order by c1.game;
 
 

--8 Fetch the total no of sports played in each olympic games?

select games,count(distinct(sport)) as sport_count from OLYMPICS_HISTORY
group by games 
order by 2 desc

--9 Fetch oldest athletes to win a gold medal?

with cte as(
select *, dense_rank() over (order by agee desc) as dn from
(select distinct *,
cast(case when age ='NA' then '0' else age end as int) as agee
from OLYMPICS_HISTORY  
where medal ='Gold')x)

select name,sex,agee,height,weight,team,noc,games,sport,event,medal from cte
where dn=1;

--10 Find the Ratio of male and female athletes participated in all olympic games?

with cte as (
select *, row_number() over (order by cnt desc) as rn from
(select sex,count(1) as cnt from OLYMPICS_HISTORY 
group by sex)x),
max_cte as (
select cnt from cte where rn=1),
min_cte as (
	select cnt from cte where rn=2)
 
select concat('1: ',round(max_cte.cnt::decimal/min_cte.cnt,2)) as ratio
from max_cte,min_cte

--11.Fetch the top 5 athletes who have won the most gold medals.

with cte as
(select name,team,count(name) as no_of_medals,
 dense_rank() over (order by count(name) desc) as dn
from OLYMPICS_HISTORY
where medal = 'Gold'
group by name,2)
select name,team,no_of_medals,dn from cte where dn <6;

 --12 Fetch the top 5 athletes who have won the most medals (gold/silver/bronze)?

with cte as (
select name,team,count(name) as total_medals,
 dense_rank() over (order by count(name) desc) as dn
 from OLYMPICS_HISTORY
 where medal in ('Gold','Silver','Bronze')
 group by name,team)
 
 select name,team, total_medals from cte where dn <= 5;
 
-- 13.Fetch the top 5 most successful countries in olympics.
--		Success is defined by no of medals won?

with cte as (
	select ohn.region,count(oh.medal) as no_of_medals,
	dense_rank() over (order by count(medal) desc) as dn
	from OLYMPICS_HISTORY oh 
	join OLYMPICS_HISTORY_NOC_REGIONS ohn
	on oh.noc=ohn.noc
	where oh.medal <> 'NA'
	group by ohn.region)
select * from cte where dn<=5;

--14.List down total gold, silver and broze medals won by each country?

--CREATE EXTENSION TABLEFUNC;

SELECT country
	, coalesce(gold, 0) as gold
	, coalesce(silver, 0) as silver
	, coalesce(bronze, 0) as bronze
FROM CROSSTAB('SELECT nr.region as country
			, medal
			, count(1) as total_medals
			FROM olympics_history oh
			JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
			where medal <> ''NA''
			GROUP BY nr.region,medal
			order BY nr.region,medal',
		'values (''Bronze''), (''Gold''), (''Silver'')')
AS FINAL_RESULT(country varchar, bronze bigint, gold bigint, silver bigint)
order by gold desc, silver desc, bronze desc;

--15.List down total gold, silver and broze medals won by each country 
--corresponding to each olympic games.
 

SELECT substring(games_country,1,position(' - ' in games_country) - 1) as games
        , substring(games_country,position(' - ' in games_country) + 3) as country
        , coalesce(gold, 0) as gold
        , coalesce(silver, 0) as silver
        , coalesce(bronze, 0) as bronze
    FROM CROSSTAB('SELECT concat(games, '' - '', nr.region) as games_country
                , medal
                , count(1) as total_medals
                FROM olympics_history oh
                JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
                where medal <> ''NA''
                GROUP BY games_country,nr.region,medal
                order BY games_country,medal',
            'values (''Bronze''), (''Gold''), (''Silver'')')
    AS FINAL_RESULT(games_country text, bronze bigint, gold bigint, silver bigint);

 
 -- 16.Identify which country won the most gold, most silver and
 --		most bronze medals in each olympic games.

with cte as (
 SELECT substring(game_country,1,position(' - ' in game_country)-1) as games,
 substring(game_country,position(' - ' in game_country)+3) as country
	, coalesce(gold, 0) as gold
	, coalesce(silver, 0) as silver
	, coalesce(bronze, 0) as bronze
FROM CROSSTAB('SELECT concat(games,'' - '',nr.region) as game_country
			, medal
			, count(1) as total_medals
			FROM olympics_history oh
			JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
			where medal <> ''NA''
			GROUP BY game_country,nr.region,medal
			order BY game_country,nr.region',
		'values (''Bronze''), (''Gold''), (''Silver'')')
AS FINAL_RESULT(game_country varchar, bronze bigint, gold bigint, silver bigint)
order by game_country)

select distinct(games),
concat(first_value(country) over (partition by games order by gold desc),' - ',
    first_value(gold) over (partition by games order by gold desc)) as max_gold,
concat(first_value(country) over (partition by games order by bronze desc),' - ',
    first_value(bronze) over (partition by games order by bronze desc)) as bronze_gold,
concat(first_value(country) over (partition by games order by silver desc),' - ',
    first_value(silver) over (partition by games order by silver desc)) as silver_gold
 from cte
 order by games;
 
 --17.Identify which country won the most gold, most silver, most bronze medals 
 --		the most medals in each olympic games.
 
with cte as (
 SELECT substring(game_country,1,position(' - ' in game_country)-1) as games,
 substring(game_country,position(' - ' in game_country)+3) as country
	, coalesce(gold, 0) as gold
	, coalesce(silver, 0) as silver
	, coalesce(bronze, 0) as bronze
FROM CROSSTAB('SELECT concat(games,'' - '',nr.region) as game_country
			, medal
			, count(1) as total_medals
			FROM olympics_history oh
			JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
			where medal <> ''NA''
			GROUP BY game_country,nr.region,medal
			order BY game_country,nr.region',
		'values (''Bronze''), (''Gold''), (''Silver'')')
AS FINAL_RESULT(game_country varchar, bronze bigint, gold bigint, silver bigint)
order by game_country),
cte2 as (
SELECT games, nr.region as country, count(1) as medals
    		FROM olympics_history oh
    		JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
    		where medal <> 'NA'
    		GROUP BY games,nr.region order BY 1, 2)
			
select distinct(c1.games),
concat(first_value(c1.country) over (partition by c1.games order by gold desc),' - ',
    first_value(gold) over (partition by c1.games order by gold desc)) as max_gold,
concat(first_value(c1.country) over (partition by c1.games order by bronze desc),' - ',
    first_value(bronze) over (partition by c1.games order by bronze desc)) as max_bronze ,
concat(first_value(c1.country) over (partition by c1.games order by silver desc),' - ',
    first_value(silver) over (partition by c1.games order by silver desc)) as max_silver ,
concat(first_value(c2.country) over (partition by c2.games order by medals desc),' - ',
    first_value(medals) over (partition by c2.games order by medals desc)) as max_medal
from cte c1
join cte2 c2
on c1.games=c2.games and c1.country=c2.country
order by games;

--18.Which countries have never won gold medal but have won silver/bronze medals?

 select * from (
 SELECT country
	, coalesce(gold, 0) as gold
	, coalesce(silver, 0) as silver
	, coalesce(bronze, 0) as bronze
FROM CROSSTAB('SELECT nr.region as country
			, medal
			, count(1) as total_medals
			FROM olympics_history oh
			JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
			where medal <> ''NA''  
			GROUP BY nr.region,medal
			order BY nr.region,medal',
		'values (''Bronze''), (''Gold''), (''Silver'')')
AS FINAL_RESULT(country varchar, bronze bigint, gold bigint, silver bigint))x
where gold =0 and (silver>0 or bronze >0)
order by gold desc , silver desc, bronze desc;

--In which Sport/event, India has won highest medals?
select sport,max(medal_count) as max_medals from 
(select sport,count(medal) as medal_count  
FROM olympics_history oh
JOIN olympics_history_noc_regions nr 
ON nr.noc = oh.noc
where nr.region ='India' and medal <>'NA'
group by sport) x
group by sport
order by max(medal_count) desc
limit 1;


--20.Break down all olympic games where india won medal for Hockey 
--		and how many medals in each olympic games.
 
select nr.region,sport,games,
count(medal) as medal_count  
FROM olympics_history oh
JOIN olympics_history_noc_regions nr 
ON nr.noc = oh.noc
where nr.region ='India' and medal <>'NA' and sport = 'Hockey'
group by nr.region,sport,games
order by medal_count desc;
 
 

    


 

	
 

 
 





 

 




