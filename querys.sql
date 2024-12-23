
update public.tickets
set ean_desc = upper(trim(ean_desc));

ALTER TABLE public.tickets ALTER COLUMN fecha TYPE date USING fecha::date;
ALTER TABLE public.tickets ALTER COLUMN precio_regular TYPE numeric USING precio_regular::numeric;
ALTER TABLE public.tickets ALTER COLUMN precio_promocional TYPE numeric USING precio_promocional::numeric;
ALTER TABLE public.tickets ALTER COLUMN unidades_vendidas TYPE numeric USING unidades_vendidas::numeric;

update public.productos
set descripcion = replace(upper(trim(descripcion)),'NAN',''), 
	sector = replace(upper(trim(sector)),'NAN',''), 
	seccion = replace(upper(trim(seccion)),'NAN',''), 
	categoria = replace(upper(trim(categoria)),'NAN',''), 
	subcategoria = replace(upper(trim(subcategoria)),'NAN',''), 
	fabricante = replace(upper(trim(fabricante)),'NAN',''), 
	marca =  replace(upper(trim(marca)),'NAN',''), 
	contenido =  replace(upper(trim(contenido)),'NAN',''), 
	pesovolumen =  replace(upper(trim(pesovolumen)),'NAN',''), 
	unidadmedida =  replace(upper(trim(unidadmedida)),'NAN',''), 
	granfamilia =  replace(upper(trim(granfamilia)),'NAN',''), 
	familia = replace(upper(trim(familia)),'NAN',''), 
	categoria_nueva = replace(upper(trim(categoria_nueva)),'NAN',''), 
	subcategoria_nueva = replace(upper(trim(subcategoria_nueva)),'NAN','');
	
/***********************/
-- Hay productos que tiene doble codificación
/***********************/
select p.eancode ,p.idcadena, count(distinct descripcion) --p.descripcion ,t.*
from public.tickets t left join public.productos p on t.eancode = p.eancode
and t.idcadena = p.idcadena 
group by p.eancode ,p.idcadena
having count(distinct descripcion) > 1;

create table dim_fecha as 
SELECT 
    fecha::DATE AS fecha,
    EXTRACT(YEAR FROM fecha)::INT AS anio,
    EXTRACT(MONTH FROM fecha)::INT AS mes,
    EXTRACT(DAY FROM fecha)::INT AS dia,
    TO_CHAR(fecha, 'TMMonth') AS nombre_mes,
    TO_CHAR(fecha, 'TMDay') AS nombre_dia,
    EXTRACT(WEEK FROM fecha)::INT AS semana,
    EXTRACT(QUARTER FROM fecha)::INT AS trimestre,
    CASE WHEN EXTRACT(DOW FROM fecha) IN (0, 6) THEN 'S' ELSE 'N' END AS es_fin_de_semana,
    CASE WHEN EXTRACT(DOW FROM fecha) BETWEEN 1 AND 5 THEN 'S' ELSE 'N' END AS es_dia_laboral
FROM 
    generate_series('2020-01-01'::DATE, '2030-12-31'::DATE, '1 day') AS fecha;
  
  
create or replace view h_tickets as
select
	punto,
	ticket,
	fecha,
	hora,
	eancode,
	-- ean_desc,
	unidades_vendidas,
	sum(precio_regular) precio_regular,
	sum(precio_promocional) precio_promocional,
	tipo_venta,
	idcadena, 
	anulado,
	count(id) cantidad_id
from
	tickets t
group by punto,
	fecha,
	ticket,
	hora,
	eancode,
	-- ean_desc,
	unidades_vendidas,
	tipo_venta,
	idcadena, 
	anulado;
	
create or replace view d_productos as
select *
from public.productos p 
where p.id = 
(
select min(p2.id)
from public.productos p2
where p2.idcadena = p.idcadena 
and p2.eancode = p2.eancode 
);

CREATE INDEX productos_idcadena_idx ON public.productos (idcadena,eancode);

/************************/
-- Nombre de la categoría.
/***********************/
select p.categoria, count(distinct t.ticket) cantidad_ventas
from d_productos p
 join h_tickets t 
on p.idcadena = t.idcadena
and p.eancode = t.eancode
group by p.categoria;

/************************/
-- Total de productos vendidos por categoría.
/***********************/
select p.categoria, count(distinct p.idcadena||'_'|| p.eancode) cantidad_productos
from d_productos p
 join h_tickets t 
on p.idcadena = t.idcadena
and p.eancode = t.eancode
group by p.categoria;

/************************/
-- La facturación por día 
/************************/
select fecha, round(sum(unidades_vendidas * precio_promocional),2) facturacion
from h_tickets t 
group by fecha;

/************************/
-- Cantidad total de productos vendidos.
/************************/
select count(distinct t.ticket||'_'|| t.fecha) cantidad_tickets
from h_tickets t ;


/************************/
-- ¿Cuáles son los 5 productos más vendidos en el último mes?
/************************/
select p.descripcion, count(distinct t.fecha::text ||''|| t.ticket) cantidad_ventas
from d_productos p
 join h_tickets t 
on p.idcadena = t.idcadena
and p.eancode = t.eancode
where TO_CHAR(t.fecha, 'YYYY-MM') = 
TO_CHAR(DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month'), 'YYYY-MM')
group by p.descripcion
order by 2 desc
limit 5;

/************************/
-- Obtener el total de ingresos generados por categoría en las últimas 3 semanas
/************************/
select p.categoria, round(sum(unidades_vendidas * precio_promocional),2) ingresos
from d_productos p
 join h_tickets t 
on p.idcadena = t.idcadena
and p.eancode = t.eancode
where t.fecha >= date(CURRENT_DATE - INTERVAL '3 weeks')
group by p.categoria;


/************************/
-- Listar los días con mayor venta y cantidad de tickets.
/************************/
select t.fecha, count(distinct t.ticket) cantidad_ventas
from  h_tickets t  
group by t.fecha
order by 2 desc;


/************************/
-- Mostrar la categoría con el mayor volumen de ventas por sucursal.
/************************/
select DISTINCT ON (t.punto) t.punto, p.categoria,round(sum(unidades_vendidas),2) ingresos
from d_productos p
 join h_tickets t 
on p.idcadena = t.idcadena
and p.eancode = t.eancode
group by p.categoria, t.punto