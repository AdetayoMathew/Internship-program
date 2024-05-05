Create database game_analysis;
use game_analysis;
alter table player_details modify L1_Status varchar(30);
alter table player_details modify L2_Status varchar(30);
alter table player_details modify P_ID int primary key;
alter table player_details drop myunknowncolumn;

alter table level_details2 drop myunknowncolumn;
alter table level_details2 change timestamp start_datetime datetime;
alter table level_details2 modify Dev_Id varchar(10);
alter table level_details2 modify Difficulty varchar(15);
RENAME TABLE player_details TO pd;
RENAME TABLE level_details2 TO ld;
select* from pd;
select* from ld;
---------------------------------------------------------------------------------------------------
-- 1 Extract `P_ID`, `Dev_ID`, `PName`, and `Difficulty_level` of all players at Level 0

select 
pd.P_ID,pd.PName,ld.Dev_ID,ld.Difficulty
from pd,ld
where Level = 0;

--  2 Find `Level1_code`wise average `Kill_Count` where `lives_earned` is 2, and at least 3 stages are crossed
SELECT pd.L1_Code, AVG(ld.Kill_Count) AS avg_killcount
FROM pd
JOIN ld ON pd.P_ID = ld.P_ID
WHERE ld.Lives_Earned = 2 AND ld.Stages_crossed >= 3
GROUP BY pd.L1_Code
order by avg_killcount
desc;

-- 3 Find the total number of stages crossed at each difficulty level for Level 2 with players 
-- using `zm_series` devices. Arrange the result in decreasing order of the total number of 
 -- stages crossed
 
SELECT Difficulty, SUM(Stages_crossed) AS total_stages_crossed
FROM ld
WHERE Level = 2
    AND Dev_Id LIKE 'zm_%'
GROUP BY Difficulty
ORDER BY total_stages_crossed DESC;

-- 4 Extract `P_ID` and the total number of unique dates for those players who have played games on multiple days.
select
P_ID,
count(distinct(start_datetime)) as total_no_unique_dates
from ld
group by P_ID
having total_no_unique_dates > 1
order by total_no_unique_dates desc ;

-------------- 5. Find `P_ID` and levelwise sum of `kill_counts` where `kill_count` is greater than the average kill count for Medium difficulty
select avg(Kill_Count)
from ld; ------------- avg count is 18.5714
SELECT P_ID, SUM(Kill_Count) AS tot_kills 
FROM ld 
WHERE Difficulty = "Medium" 
GROUP BY P_ID 
HAVING SUM(Kill_Count) > AVG(Kill_Count);

----- 6 Find `Level` and its corresponding `Level_code`wise sum of lives earned, excluding Level 0. Arrange in ascending order of level.

SELECT SUM(ld.Lives_Earned) as tot_live_earned, ld.Level, pd.L1_Code, pd.L2_Code 
FROM ld
join pd on ld.P_ID = pd.P_ID
WHERE ld.Level > 0 
AND pd.L1_Code <> '' 
AND pd.L2_Code <> '' 
GROUP BY ld.Level, pd.L1_Code, pd.L2_Code 
ORDER BY ld.Level ASC;

------ 7 Find the top 3 scores based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well

--------- without the rank ---------
select Score,Difficulty,Dev_Id
from ld
group by Dev_Id,Score,Difficulty
order by Score
DESC
limit 3;

----------- ADDING THE RANK --------
SELECT `Rank`,Score,Difficulty
FROM (
    SELECT Score, Difficulty, Dev_Id, 
           ROW_NUMBER() OVER (ORDER BY Score DESC) AS `Rank`
    FROM ld
    GROUP BY Dev_Id, Score, Difficulty
) AS RankedScores
ORDER BY `Rank`
LIMIT 3;

---------  8 Find the `first_login` datetime for each device ID --------

SELECT 
    Dev_Id, 
    MIN(start_datetime) AS first_login
FROM 
    ld
GROUP BY 
    Dev_Id
ORDER BY 
    first_login;
    
    ------------  9 Find the top 5 scores based on each difficulty level and rank them in increasing order using `Rank`. Display `Dev_ID` as well.

select 
Dev_Id,Score,Difficulty,
rank() over (order by score) as scores_ranking
from ld
limit 5;

------- 10 Find the device ID that is first logged in (based on `start_datetime`) for each player 
------------ (`P_ID`). Output should contain player ID, device ID, and first login datetime.


SELECT
    pd.P_ID,
    ld.Dev_Id,
    MIN(ld.start_datetime) AS first_login
FROM
    pd
JOIN
    ld ON pd.P_ID = ld.P_ID
GROUP BY
    pd.P_ID,
    ld.Dev_Id;
    
    ---  11 For each player and date, determine how many `kill_counts` were played by the player so far.
select * from ld;
--- a) Using window functions

select 
PName,start_datetime,
sum(Kill_Count)  over(partition by PName) as kill_counts
from pd
join ld on pd.P_ID = ld.P_ID;

--- using non window fuction
select 
PName,start_datetime,
sum(Kill_Count)   as kill_counts
from pd
join ld on pd.P_ID = ld.P_ID
group by PName,start_datetime;

----- 12 Find the cumulative sum of stages crossed over `start_datetime` for each `P_ID`, 
--- excluding the most recent start_datetime
WITH RankedData AS (
    SELECT
        ld.Stages_crossed,
        ld.start_datetime,
        pd.P_ID,
        RANK() OVER (ORDER BY ld.start_datetime) AS date_ranking
    FROM ld
    JOIN pd ON ld.P_ID = pd.P_ID
)
SELECT
    SUM(Stages_crossed) AS Cumulative_Stages_crossed,
    start_datetime,
    P_ID,date_ranking
FROM RankedData
WHERE date_ranking > 1
GROUP BY start_datetime, P_ID;

--- 13 Extract the top 3 highest sums of scores for each `Dev_ID` and the corresponding `P_ID`------
 
  SELECT
    SUM(ld.Score) AS tot_score,
    ld.Dev_Id,
    pd.P_ID
FROM
    ld
JOIN
    pd ON ld.P_ID = pd.P_ID
GROUP BY
    ld.Dev_Id,
    pd.P_ID
ORDER BY
   tot_score DESC
LIMIT 3;
------- 14 Find players who scored more than 50% of the average score, scored by the sum of scores for each `P_ID`-----------
select
avg(ld.Score),0.5*avg(ld.Score),sum(ld.Score)
from ld;



SELECT pd.P_ID, SUM(ld.Score) AS Total_Score
FROM pd
JOIN ld ON pd.P_ID = ld.P_ID
GROUP BY pd.P_ID
HAVING SUM(ld.Score) > (SELECT AVG(Score) * 0.5 FROM ld);

---------- 15 Create a stored procedure to find the top `n` `headshots_count` based on each `Dev_ID` and rank them in increasing order using `Row_Number`. Display the difficulty as well ---------

DELIMITER //

CREATE PROCEDURE TopHeadshots
    (IN n INT)
BEGIN
    SELECT Dev_ID, Headshots_count,  ranking,Difficulty
    FROM (
        SELECT 
            Dev_ID,
            Headshots_count,
            Difficulty,
            ROW_NUMBER() OVER (PARTITION BY Dev_ID ORDER BY headshots_count) AS ranking
        FROM 
           ld
    ) AS RankedHeadshots
    WHERE ranking <= n
    ORDER BY Dev_ID, ranking;
END //

call TopHeadshots(2)

