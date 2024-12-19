 --	Задание 1.Выведите название самолетов, которые имеют менее 50 посадочных мест.
 
 select model
 from (select aircraft_code from seats group by aircraft_code having count(seat_no) < 50) as s
 inner join aircrafts a on a.aircraft_code = s.aircraft_code


-- Задание 2.Выведите процентное изменение ежемесячной суммы бронирования билетов, округленной до сотых.
		
select 
	date_trunc('month',book_date::date),
	round(sum(total_amount)*100/lag(sum(total_amount)) over (order by date_trunc('month',book_date::date))-100,2) diff 
from bookings b
group by date_trunc('month',book_date::date)
  
 --Задание 3.Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть через функцию array_agg.
 select model from (
	select aircraft_code
	from seats s
	group by aircraft_code
	having 'Business' != all(ARRAY_AGG(fare_conditions))
	) s
 inner join aircrafts a on a.aircraft_code = s.aircraft_code
 
/* Задание 4. Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый день,
 *  учитывая только те самолеты, которые летали пустыми и только те дни,
 *  где из одного аэропорта таких самолетов вылетало более одного.
 В результате должны быть код аэропорта, дата, количество пустых мест в самолете и накопительный итог.*/

with empty_planes as (
select
	departure_airport,
	f.aircraft_code,
	actual_departure,
	count(f.flight_id) over(partition by departure_airport, actual_departure::date) flights_count,
	count(s.seat_no) seats
	from 
	flights f
	left join (select distinct flight_id from boarding_passes) bp ON f.flight_id = bp.flight_id
	left join seats s on s.aircraft_code = f.aircraft_code
	where bp.flight_id IS null and actual_departure is not null
	group by f.aircraft_code, f.flight_id
	order by seats desc
)

	select a.airport_code,
	actual_departure,
	seats,
	sum(seats) over (partition by airport_code, actual_departure::date, aircraft_code order by actual_departure) total_seats_count
	from empty_planes ep
	inner join airports a on a.airport_code = ep.departure_airport
	where flights_count > 1

 /*Задание 5.Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов.
  Выведите в результат названия аэропортов и процентное отношение.
 Решение должно быть через оконную функцию.*/
	select a.airport_name, round(sum(flights)*100/total_count,2) percent
	from airports a 
	left join (
		select departure_airport, arrival_airport, flight_no, count(flight_id) flights
		from flights f where status != 'Canceled'
		group by departure_airport, arrival_airport, flight_no
	) fc on fc.departure_airport = a.airport_code
	left join (
		select distinct flight_no, count(f.flight_id) over() total_count from flights f where status != 'Canceled'
	) tf on tf.flight_no=fc.flight_no
	group by airport_code, total_count
	order by sum(flights) desc
	
	
-- Задание 6.Выведите количество пассажиров по каждому коду сотового оператора, если учесть, что код оператора - это три символа после +7
select substring(contact_data ->> 'phone',3,3) code, count(passenger_id) passengers_count
from tickets
group by code
order by code

/* Задание 7.Классифицируйте финансовые обороты (сумма стоимости перелетов) по маршрутам:
 До 50 млн - low
 От 50 млн включительно до 150 млн - middle
 От 150 млн включительно - high
 Выведите в результат количество маршрутов в каждом полученном классе*/

select count(flight_no) flight_count, class from (
	select flight_no ,
			case 
				when sum(total_amount) < 50000000 then 'low'
				when sum(total_amount) between 50000000 and 149999999 then 'middle'
				when sum(total_amount) >= 150000000 then 'high'
			end class
		from bookings b
		right join tickets t on b.book_ref=t.book_ref
		inner join ticket_flights tf on t.ticket_no = tf.ticket_no
		inner join flights f on f.flight_id = tf.flight_id
		group by flight_no
		order by class 
)
group by class



/* Задание 8. Вычислите медиану стоимости перелетов,
 медиану размера бронирования и отношение медианы бронирования к медиане стоимости перелетов,
 округленной до сотых
*/
with m1 as (
	SELECT 
	    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount
	 from ticket_flights tf ),
m2 as (
	SELECT 
	    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_amount) AS median_total_amount
	 from bookings b 
)

select median_total_amount, median_amount, round((median_total_amount/median_amount)::numeric,2) from m1,m2


/*9. Найдите значение минимальной стоимости полета 1 км для пассажиров. 
 * То есть нужно найти расстояние между аэропортами 
 * и с учетом стоимости перелетов получить искомый результат
  Для поиска расстояния между двумя точками на поверхности Земли используется модуль earthdistance.
  Для работы модуля earthdistance необходимо предварительно установить модуль cube.
  Установка модулей происходит через команду: create extension название_модуля.*/
CREATE EXTENSION cube SCHEMA bookings;
CREATE EXTENSION earthdistance SCHEMA bookings;

select round(min(amount/(earth_distance(ll_to_earth(aa.latitude,aa.longitude),ll_to_earth(ad.latitude,ad.longitude))/1000)::numeric), 2) cost
from flights f
inner join (
	select flight_id, min(amount) amount from ticket_flights tf group by flight_id
	) tf on tf.flight_id = f.flight_id
inner join airports aa on aa.airport_code = f.arrival_airport
inner join airports ad on ad.airport_code = f.departure_airport 











