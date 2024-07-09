--------------------------------------------------
----------------- EJERCICIOS ---------------------
--------------------------------------------------



/* 
1. Listar los nombres, apellidos y sueldo de los empleados cuyo sueldo es mayor que el sueldo promedio de todos los empleados. 
También se debe incluir el sueldo promedio en los resultados. 

2. Listar el nombre, apellido y sueldo de cada empleado, con columna adicional llamada SueldoConBonus que calcule un 5% adicional al sueldo para empleados con más de 10 años de antigüedad, 
y un 3% para empleados con antigüedad entre 5 y 10 años. Los empleados con menos de 5 años de antigüedad no reciben bonus.

3. Listar la cantidad de empleados por categoría, pero solo para las categorías "Administrativo", "Gerente" y "Supervisor". 

4. Crea un procedimiento almacenado llamado SP_EmpleadosConAdelantos que reciba un año como parámetro 
y liste los nombres y apellidos de los empleados que han solicitado adelantos en ese año. 
La lista debe incluir también la cantidad total de dinero adelantado.

5. Crea una función llamada fn_CalcularAntiguedad que reciba como parámetro el año de ingreso de un empleado y devuelva la antigüedad en años. 
Usa esta función en una consulta que liste los nombres, apellidos y la antigüedad de todos los empleados.

6. Crea una vista llamada VW_AdelantosAprobados que muestre todos los adelantos aprobados. 
La vista debe mostrar; Nombre, apellido y categoria de empleado, Fecha y Monto de los adelantos 
y una columna adicional Estado que debe mostrar "Aprobado" en caso de que el monto sea inferior al 50% de su sueldo. 
Caso contrario, debe mostrar "No aprobado".

7. Crear un trigger que valide la inserción de registros en la tabla Empleados.
- Verificar que el sueldo del empleado no sea menor al sueldo base de acuerdo a su categoría.
- Verificar que el sueldo del empleado no sea mayor al doble del sueldo base de acuerdo a su categoría.
- Verificar que el año de ingreso del empleado no sea posterior al año actual. En caso de serlo, insertar el empleado con el año actual 
*/




----------------------------------------------------
----------------- RESOLUCIONES ---------------------
----------------------------------------------------



/* 1. Listar los nombres, apellidos y sueldo de los empleados cuyo sueldo es mayor que el sueldo promedio de todos los empleados. 
También se debe incluir el sueldo promedio en los resultados. */

SELECT Nombre + ', ' + Apellido AS ApellidoNombre, Sueldo,(SELECT AVG(Sueldo) FROM Empleados) AS SueldoPromedio 
FROM Empleados
WHERE Sueldo > (SELECT AVG(Sueldo) FROM Empleados);

/* 2. Listar el nombre, apellido y sueldo de cada empleado, con columna adicional llamada SueldoConBonus que calcule un 5% adicional al sueldo para empleados con más de 10 años de antigüedad, 
y un 3% para empleados con antigüedad entre 5 y 10 años. Los empleados con menos de 5 años de antigüedad no reciben bonus.*/

SELECT Nombre + ', ' + Apellido AS ApellidoNombre,
CASE
	WHEN (YEAR(GETDATE() - AnioIngreso)) > 10 THEN Sueldo * 1.05
	WHEN (YEAR(GETDATE() - AnioIngreso)) BETWEEN 5 AND 10 THEN Sueldo * 1.03
	ELSE Sueldo
END AS SueldoConBonus
FROM Empleados;

-- 3. Listar la cantidad de empleados por categoría, pero solo para las categorías "Administrativo", "Gerente" y "Supervisor". 

SELECT COUNT(*) AS CantidadEmpleados, Categorias.Nombre FROM Empleados
LEFT JOIN Categorias ON Categorias.IDCategoria = Empleados.IDCategoria
WHERE Categorias.Nombre IN ('Administrativo','Gerente','Supervisor')
GROUP BY Categorias.Nombre;

/* 4. Crea un procedimiento almacenado llamado SP_EmpleadosConAdelantos que reciba un año como parámetro 
y liste los nombres y apellidos de los empleados que han solicitado adelantos en ese año. 
La lista debe incluir también la cantidad total de dinero adelantado.*/

CREATE OR ALTER PROCEDURE SP_EmpleadosConAdelantos (@Year INT)
AS BEGIN
 
 SELECT E.Nombre + ', ' + E.Apellido AS NombreApellido,
 SUM(A.Monto) AS TotalAdelantado
 FROM Empleados E
 JOIN Adelantos A ON A.IDEmpleado = E.IDEmpleado
 WHERE YEAR(A.Fecha) = @YEAR
 GROUP BY E.Nombre,E.Apellido

END;

/* 5. Crea una función llamada fn_CalcularAntiguedad que reciba como parámetro el año de ingreso de un empleado y devuelva la antigüedad en años. 
Usa esta función en una consulta que liste los nombres, apellidos y la antigüedad de todos los empleados.*/

CREATE OR ALTER FUNCTION FN_CalcularAntiguedad(@YearIngreso INT)
RETURNS INT
AS BEGIN
	DECLARE @Antiguedad INT

	SELECT @Antiguedad = YEAR(GETDATE()) - @YearIngreso

	RETURN @Antiguedad

END;

SELECT E.Nombre, E.Apellido, dbo.FN_CalcularAntiguedad(AnioIngreso) AS Antiguedad
FROM Empleados E;

/* 6. Crea una vista llamada VW_AdelantosAprobados que muestre todos los adelantos aprobados. 
La vista debe mostrar; Nombre, apellido y categoria de empleado, Fecha y Monto de los adelantos 
y una columna adicional Estado que debe mostrar "Aprobado" en caso de que el monto sea inferior al 50% de su sueldo. Caso contrario, debe mostrar "No aprobado" */

CREATE OR ALTER VIEW VW_AdelantosAprobados AS
SELECT E.Nombre, E.Apellido, C.Nombre AS Categoria, A.Fecha, A.Monto, 
CASE
WHEN A.Monto < (E.Sueldo*0.5) THEN 'Aprobado'
ELSE 'No Aprobado'
END AS Estado
FROM Adelantos A
JOIN Empleados E ON E.IDEmpleado = A.IDEmpleado
JOIN Categorias C ON C.IDCategoria = E.IDCategoria;


/* 7. Crear un trigger que valide la inserción de registros en la tabla Empleados.
- Verificar que el sueldo del empleado no sea menor al sueldo base de acuerdo a su categoría.
- Verificar que el sueldo del empleado no sea mayor al doble del sueldo base de acuerdo a su categoría.
- Verificar que el año de ingreso del empleado no sea posterior al año actual. En caso de serlo, insertar el empleado con el año actual */

CREATE OR ALTER TRIGGER TR_VALIDAR_EMPLEADO ON Empleados
INSTEAD OF INSERT
AS BEGIN

	BEGIN TRY
	BEGIN TRANSACTION
	--VARIABLES/COLUMNAS EMPLEADO
	DECLARE @IDCategoria INT, @Nombre VARCHAR(50), @Apellido VARCHAR(50), @AnioIngreso INT, @Sueldo MONEY
	--OBTENGO DESDE INSERTED
	SELECT @IDCategoria = IDCategoria, @Nombre = Nombre, @Apellido = Apellido, @AnioIngreso = AnioIngreso, @Sueldo = Sueldo
	FROM inserted

	--VARIABLES AUX
	DECLARE @SueldoBase MONEY, @SueldoMax MONEY

	-- OBTENGO EL SUELDO BASE
	SELECT @SueldoBase = C.SueldoBase FROM Categorias C WHERE C.IDCategoria = @IDCategoria

	--- VALIDO QUE EL SUELDO SEA MAYOR AL SUELDO BASE
	IF @Sueldo < @SueldoBase
	BEGIN
	RAISERROR('El sueldo no puede ser menor al sueldo base correspondiente por categoria',16,1)
	RETURN
	END

	-- OBTENGO EL SUELDO MAXIMO
	SELECT @SueldoMax = @SueldoBase * 2

	-- VALIDO QUE EL SUELDO NO SEA MAYOR AL DOBLE DEL SUELDO BASE
	IF @Sueldo > @SueldoMax
	BEGIN
	RAISERROR('El suedo no puede ser mayor al doble del sueldo base correspondiente',16,1)
	RETURN
	END

	-- VALIDO EL ANIO DE INGRESO
	IF @AnioIngreso > YEAR(GETDATE())
	BEGIN
	SET @AnioIngreso = YEAR(GETDATE())
	END

	INSERT INTO Empleados(IDCategoria, Nombre, Apellido, AnioIngreso, Sueldo)
	VALUES (@IDCategoria, @Nombre, @Apellido, @AnioIngreso, @Sueldo)

	PRINT('Registro de empleado insertado correctamente')

	COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
	PRINT ERROR_MESSAGE()
	ROLLBACK TRANSACTION
	END CATCH
END;


---- CODIGO DE PRUEBA
INSERT INTO Empleados (IDCategoria, Nombre, Apellido, AnioIngreso, Sueldo)
VALUES (2, 'Test', 'Empleado', 2020, 700); -- Sueldo menor al sueldo base de $800

INSERT INTO Empleados (IDCategoria, Nombre, Apellido, AnioIngreso, Sueldo)
VALUES (2, 'Test', 'Empleado', 2020, 1700); -- Sueldo mayor al doble del sueldo base de $800

INSERT INTO Empleados (IDCategoria, Nombre, Apellido, AnioIngreso, Sueldo)
VALUES (2, 'Test', 'Empleado', 2025, 1000); -- Año de ingreso mayor al año actual

SELECT * FROM Empleados



