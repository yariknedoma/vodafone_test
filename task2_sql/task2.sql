-- сначала я разделил lvl2.xlsx на employees.csv и equipment.csv, для того дальнейшего удобства работы с ними

-- создание БД и заполнение данными

CREATE DATABASE test_task;

USE test_task;

CREATE TABLE employees (
    id INT PRIMARY KEY,      
    FirstName VARCHAR(50),      
    SecondName VARCHAR(50),     
    Division VARCHAR(50),     
    Position VARCHAR(50),     
    DateFrom DATE,     
    DateTo DATE,     
    id_status VARCHAR(50),     
    ZP INT);

LOAD DATA LOCAL INFILE "/Users/yarik/Desktop/employees.csv" 
INTO TABLE test_task.employees 
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n' 
IGNORE 1 LINES 
(id, FirstName, SecondName, Division, Position, @datevar1,  @datevar2, id_status, ZP) 
SET DateFrom = STR_TO_DATE(@datevar1,'%m/%d/%Y'), 
    DateTo = STR_TO_DATE(@datevar2, '%m/%d/%Y');

CREATE TABLE equipment (
    id INT PRIMARY KEY, 
    HW_Type VARCHAR(50), 
    DateFrom DATE, 
    DateTo DATE);    
    
LOAD DATA LOCAL INFILE "/Users/yarik/Desktop/equipment.csv" 
INTO TABLE test_task.equipment 
FIELDS TERMINATED BY ',' 
LINES TERMINATED BY '\n' 
IGNORE 1 LINES 
(id, HW_Type, @datevar1, @datevar2) 
SET DateFrom = STR_TO_DATE(@datevar1,'%m/%d/%Y'), 
    DateTo = STR_TO_DATE(@datevar2, '%m/%d/%Y');

-- 1. Кто из сотрудников дольше всех работает в каждом из подразделений компании и в целом в компании? Каков средний стаж работы в компании?

SELECT e.FirstName, e.SecondName, e.Division, tmp.Workdays
FROM employees e JOIN (
                        SELECT Division, 
                               MAX(DATEDIFF(IFNULL(DateTo, (SELECT CURDATE())), DateFrom)) 'Workdays' 
                        FROM employees
                        GROUP BY Division
    ) tmp 
                 ON (e.Division = tmp.Division AND 
                     DATEDIFF(IFNULL(e.DateTo, (SELECT CURDATE())), e.DateFrom)=tmp.Workdays)
ORDER BY Workdays DESC;  

+--------------+--------------------+----------+----------+
| FirstName    | SecondName         | Division | Workdays |
+--------------+--------------------+----------+----------+
| Віктор       | Поливаний          | IT       |     7549 |
| Оксана       | Алдошина           | DM       |     6305 |
| Тимур        | Самойлов           | TD       |     6263 |
+--------------+--------------------+----------+----------+
3 rows in set (0.01 sec)

    Дольше всего в компании работает Віктор Поливаний из IT подразделения, в подразделении DM это Оксана Алдошина, в TD - Тимур Самойлов.

SELECT ROUND(AVG(DATEDIFF(IFNULL(DateTo, (SELECT CURDATE())), DateFrom)), 1) 'Avg_workdays' 
FROM employees;

+--------------+
| Avg_workdays |
+--------------+
|       4165.9 |
+--------------+
1 row in set (0.01 sec)

    Средний стаж работы сотрудников на 06.09.21 равен 4165.9 дней (учитывались и текущие сотрудники, и те которые уже не работают в компании).

-- 2. Какое максимальное и минимальное количество дней между увольнением и приемом нового сотрудника?

SELECT e.DateTo 'fired', 
      (SELECT MIN(DateFrom)
       FROM employees
       WHERE DateFrom >= e.DateTo) 'next_hired',
      DATEDIFF((SELECT MIN(DateFrom)
       FROM employees
       WHERE DateFrom >= e.DateTo), e.DateTo) 'days_between'
FROM employees e
WHERE e.DateTo IS NOT NULL
ORDER BY 3 DESC;

+------------+------------+--------------+
| fired      | next_hired | days_between |
+------------+------------+--------------+
| 2010-04-08 | 2010-06-28 |           81 |
| 2016-08-30 | 2016-09-02 |            3 |
| 2009-05-25 | 2009-05-26 |            1 |
| 2018-09-24 | NULL       |         NULL |
+------------+------------+--------------+
4 rows in set (0.03 sec)

    Максимальное количество между увольнением старого и приемом нового сотрудника на данный момент составляет 81 день, минимальное - 1 день. 
    В случае принятия нового сотрудника максимальное количество дней сильно увеличится, т.к. последний сотрудник был уволен почти 2 года назад.

-- 3. Какой ФОТ (фонд оплаты труда) у каждого из подразделений компании?

SELECT Division, SUM(ZP) Salary_budget
FROM employees
GROUP BY Division
ORDER BY Salary_budget DESC;

+----------+---------------+
| Division | Salary_budget |
+----------+---------------+
| DM       |         32700 |
| TD       |         26400 |
| IT       |         20300 |
+----------+---------------+
3 rows in set (0.01 sec)

    DM - 32700,
    TD - 26400,
    IT - 20300

-- 4. Сколько сотрудников с именем, содержащим букву "О"?
SELECT COUNT(*) 'names_containing_o'
FROM (
      SELECT FirstName, SecondName
      FROM employees 
      WHERE FirstName LIKE '%о%') tmp;

+--------------------+
| names_containing_o |
+--------------------+
|                 13 |
+--------------------+
1 row in set (0.00 sec)

    У 13 сотрудников в имени есть буква о.

-- 5. Кто из сотрудников получил оборудование быстрее остальных после приема на работу, кто - дольше остальных?

SELECT FirstName, SecondName, em.DateFrom 'hired', eq.DateFrom 'got_equipment',
       DATEDIFF(eq.DateFrom, em.DateFrom) 'days_between'
FROM employees em JOIN equipment eq USING (id)
WHERE DATEDIFF(eq.DateFrom, em.DateFrom) IN (
        SELECT MAX(DATEDIFF(eq.DateFrom, em.DateFrom)) 'min_max_days_between'
        FROM employees em JOIN equipment eq USING (id)
        UNION
        SELECT MIN(DATEDIFF(eq.DateFrom, em.DateFrom)) 'min_max_days_between'
        FROM employees em JOIN equipment eq USING (id))
ORDER BY days_between DESC;

+--------------+--------------------+------------+---------------+--------------+
| FirstName    | SecondName         | hired      | got_equipment | days_between |
+--------------+--------------------+------------+---------------+--------------+
| Олена        | Ващук              | 2010-03-11 | 2010-04-05    |           25 |
| Віктор       | Поливаний          | 2001-01-05 | 2001-01-08    |            3 |
+--------------+--------------------+------------+---------------+--------------+
2 rows in set (0.02 sec)

    После принятия на работу быстрее всех получил оборудовние Віктор Поливаний, дольше всех получала Олена Ващук.

-- 6. Проранжировать сотрудников по длительности использования выданного оборудования. Кто из сотрудников после увольнения не сдал оборудование?

SELECT FirstName, SecondName, eq.DateFrom 'start_date', IFNULL(eq.DateTo, 'still using') 'return_date', 
       DATEDIFF(IFNULL(eq.DateTo, (SELECT CURDATE())), eq.DateFrom) 'days_using', 
       ROW_NUMBER() OVER (ORDER BY DATEDIFF(IFNULL(eq.DateTo, (SELECT CURDATE())), eq.DateFrom) DESC) 'rank'
FROM employees e JOIN equipment eq USING (id)
ORDER BY days_using DESC; 

+--------------------+--------------------------+------------+-------------+------------+------+
| FirstName          | SecondName               | start_date | return_date | days_using | rank |
+--------------------+--------------------------+------------+-------------+------------+------+
| Віктор             | Поливаний                | 2001-01-08 | still using |       7546 |    1 |
| Оксана             | Алдошина                 | 2004-06-07 | still using |       6300 |    2 |
| Олена              | Третяк                   | 2005-01-19 | still using |       6074 |    3 |
| Ірина              | Соколова                 | 2005-01-31 | still using |       6062 |    4 |
| Ольга              | Михайловська             | 2007-07-05 | still using |       5177 |    5 |
| Тетяна             | Рогова                   | 2008-08-13 | still using |       4772 |    6 |
| Наталя             | Дячук                    | 2009-05-31 | still using |       4481 |    7 |
| Олексій            | Нивников                 | 2009-09-14 | still using |       4375 |    8 |
| Олена              | Ващук                    | 2010-04-05 | still using |       4172 |    9 |
| Михайло            | Новотарський             | 2010-07-03 | still using |       4083 |   10 |
| Ірина              | Далека                   | 2010-10-15 | still using |       3979 |   11 |
| Володимир          | Ткачук                   | 2012-02-06 | still using |       3500 |   12 |
| Вікторія           | Гуць                     | 2008-05-05 | 2016-08-30  |       3039 |   13 |
| Олексій            | Пирогов                  | 2002-06-17 | 2010-04-08  |       2852 |   14 |
| Назар              | Волошин                  | 2012-07-10 | 2018-09-24  |       2267 |   15 |
| Тетяна             | Захарова                 | 2016-09-07 | still using |       1825 |   16 |
| Олександр          | Семенов                  | 2009-12-27 | 2013-12-01  |       1435 |   17 |
| Олександр          | Петров                   | 2017-11-21 | still using |       1385 |   18 |
| Володимир          | Бендзь                   | 2007-04-06 | 2009-05-25  |        780 |   19 |
| Тимур              | Самойлов                 | 2004-07-29 | 2006-07-19  |        720 |   20 |
+--------------------+--------------------------+------------+-------------+------------+------+
20 rows in set (0.00 sec)

SELECT FirstName, SecondName, em.DateTo 'fired', eq.DateTo 'equipment_back'
FROM employees em JOIN equipment eq USING (id)
WHERE em.DateTo IS NOT NULL AND eq.DateTo > em.DateTo;

Empty set (0.01 sec)

SELECT FirstName, SecondName, em.DateTo 'fired', eq.DateTo 'equipment_back'
FROM employees em JOIN equipment eq USING (id)
WHERE em.DateTo IS NOT NULL;

+--------------------+----------------+------------+----------------+
| FirstName          | SecondName     | fired      | equipment_back |
+--------------------+----------------+------------+----------------+
| Олексій            | Пирогов        | 2010-04-08 | 2010-04-08     |
| Вікторія           | Гуць           | 2016-08-30 | 2016-08-30     |
| Назар              | Волошин        | 2018-09-24 | 2018-09-24     |
| Володимир          | Бендзь         | 2009-05-25 | 2009-05-25     |
+--------------------+----------------+------------+----------------+
4 rows in set (0.01 sec)

    Все уволенные сотрудники сдали оборудование в день увольнения.

