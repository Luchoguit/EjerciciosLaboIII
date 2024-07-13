
/*
1) Crear una función llamada FN_CantidadConcursos que reciba un año y devuelva la cantidad de concursos que transcurrieron durante el mismo.
ACLARACION: Tanto la fecha de inicio como la fecha de fin del concurso debe estar dentro de ese año.

2) Crear una vista llamada VW_ConcursosSinVotaciones que liste los concursos que no tienen ninguna votación registrada. 
La vista debe mostrar el título del concurso, la fecha de inicio, la fecha de fin y la cantidad de fotografias asociadas al mismo.

3) Crear un procedimiento almacenado llamado SP_MostrarGanador que reciba el ID de un concurso y liste la informacion de la fotografia ganadora (puntaje promedio mas alto).
Verificar que el concurso ya haya terminado, de lo contrario mostrar un mensaje de error acorde.
Se debe mostrar; Titulo del concurso, titulo de la fotografia, puntaje promedio, y apellido y nombre del participante ganador.

4) Crear un trigger llamado TRG_ValidarVoto para la tabla votaciones.
Al agregar una votacion, se debe validar que;
- El participante que emite el voto no tenga ninguna fotografia descalificada en ese concurso.
- El ranking del votante sea igual o mayor al ranking minimo del concurso en el que esta participando la fotografia que esta votando.
- El concurso este vigente
Si ninguna validación lo impide insertar el registro, de lo contrario, informar un mensaje de error.

5) Crear un trigger llamado TR_DescalificarFotografia para la tabla votaciones. 
Si al agregar una votacion, el puntaje promedio de esa fotografia es menor a 4 puntos, el trigger debe descalificar la fotografía.
ACLARACION: Esta validacion solo debe hacerse si la fotografía ya recibió tres o más puntuaciones antes de ejecutar el trigger.

6) Crear una vista llamada VW_ParticipantesConBuenPuntaje que liste los participantes que tienen 
un promedio de puntajes de fotografías mayor o igual a 8. La vista debe mostrar; 
Apellido y nombre del participante, la cantidad de fotografias y el promedio total de puntajes de las mismas.
ACLARACION: No se deben de tener en cuenta las fotografias descalificadas ni para el promedio ni para la cantidad de fotografias.
*/

--1) Crear una función llamada FN_CantidadConcursos que reciba un año y devuelva la cantidad de concursos que transcurrieron durante el mismo.
--ACLARACION: Tanto la fecha de inicio como la fecha de fin del concurso debe estar dentro de ese año.

CREATE OR ALTER FUNCTION FN_CantidadConcursos (@Anio INT)
RETURNS INT
AS BEGIN

	DECLARE @Cantidad INT

	SELECT @Cantidad = COUNT(ID) FROM Concursos WHERE YEAR(Inicio) = @Anio AND YEAR(Fin) = @Anio

	RETURN @Cantidad
END;

SELECT dbo.FN_CantidadConcursos(2024) AS CantidadConcursos

--2) Crear una vista llamada VW_ConcursosSinVotaciones que liste los concursos que no tienen ninguna votación registrada. 
--La vista debe mostrar el título del concurso, la fecha de inicio, la fecha de fin y la cantidad de fotografias asociadas al mismo.

CREATE OR ALTER VIEW VW_ConcursosSinVotaciones AS
SELECT C.Titulo, C.Inicio, C.Fin, COUNT(F.ID) AS CantidadFotografias
FROM Concursos C
LEFT JOIN Fotografias F ON F.IDConcurso = C.ID
LEFT JOIN Votaciones V ON V.IDFotografia = F.ID
WHERE F.ID IS NULL
GROUP BY C.Titulo, C.Inicio, C.Fin;

SELECT * FROM VW_ConcursosSinVotaciones

--3) Crear un procedimiento almacenado llamado SP_MostrarGanador que reciba el ID de un concurso y liste la informacion de la fotografia ganadora (Gana el puntaje promedio mas alto).
--Verificar que el concurso ya haya terminado, de lo contrario mostrar un mensaje de error acorde.
--Se debe mostrar; Titulo del concurso, titulo de la fotografia, puntaje promedio, y apellido y nombre del participante ganador.

CREATE OR ALTER PROCEDURE SP_MostrarGanador(@IDConcurso BIGINT)
AS BEGIN

DECLARE @FechaFin DATE

SELECT @FechaFin = C.Fin FROM Concursos C WHERE C.ID = @IDConcurso

IF GETDATE() < @FechaFin
BEGIN
PRINT('El concurso todavia no ha concluido')
RETURN
END

DECLARE @IDGanador BIGINT


--SACAR EL PROMEDIO DE TODAS LAS VOTACIONES CORRESPONDIENTES A CADA FOTOGRAFIA
--ALMACENAR EL ID DE LA FOTOGRAFIA

SELECT TOP 1 @IDGanador = F.ID
FROM Fotografias F
JOIN Votaciones V ON V.IDFotografia = F.ID
WHERE F.IDConcurso = @IDConcurso
GROUP BY F.ID
ORDER BY AVG(V.Puntaje) DESC

--LISTAR LOS DATOS USANDO ESE ID

SELECT C.Titulo AS Concurso, F.Titulo AS Fotografia, AVG(V.Puntaje) AS Puntaje, P.Apellidos + ', ' + P.Nombres AS ApellidoNombre
FROM Concursos C
JOIN Fotografias F ON F.IDConcurso = C.ID
JOIN Participantes P ON P.ID = F.IDParticipante
JOIN Votaciones V ON V.IDFotografia = F.ID
WHERE F.ID = @IDGanador
GROUP BY C.Titulo, F.Titulo,P.Apellidos,P.Nombres

END;

EXEC SP_MostrarGanador 1

-- 4) Crear un trigger llamado TR_ValidarVoto para la tabla votaciones.
-- Al agregar una votacion, se debe validar que;
-- - El participante que emite el voto no tenga ninguna fotografia descalificada en ese concurso.
-- - El ranking del votante sea igual o mayor al ranking minimo del concurso en el que esta participando la fotografia que esta votando.
-- - El concurso este vigente
-- Si ninguna validación lo impide insertar el registro, de lo contrario, informar un mensaje de error.

CREATE OR ALTER TRIGGER TR_ValidarVoto ON Votaciones
INSTEAD OF INSERT
AS BEGIN
		BEGIN TRY
		BEGIN TRANSACTION

		--DECLARO VARIABLES/COLUMNAS
		DECLARE @IDVotante BIGINT, @IDFotografia BIGINT, @Fecha DATE, @Puntaje DECIMAL (5,2)
		--OBTENGO DATOS DE INSERTED
		SELECT @IDVotante = IDVotante, @IDFotografia = IDFotografia, @Fecha = Fecha, @Puntaje = Puntaje
		FROM inserted

-- - El participante que emite el voto no tenga ninguna fotografia descalificada en ese concurso.

	DECLARE @CantDescalificadas INT, @IDConcurso BIGINT

	SELECT @IDConcurso = F.IDConcurso FROM Fotografias F WHERE F.ID = @IDFotografia

	SELECT @CantDescalificadas = COUNT(F.ID) FROM Fotografias F WHERE F.Descalificada = 1 AND F.IDParticipante = @IDVotante AND F.IDConcurso = @IDConcurso;

	IF @CantDescalificadas > 0
	BEGIN
	RAISERROR('Solo pueden votar participantes que no tengan fotos descalificadas en este concurso',16,1)
	RETURN
	END

-- - El ranking del votante sea igual o mayor al ranking minimo del concurso en el que esta participando la fotografia que esta votando.

DECLARE @RankingVotante DECIMAL(5,2), @RankingConcurso DECIMAL(5,2)

SELECT @RankingVotante = AVG(V.Puntaje) FROM Votaciones V
JOIN Fotografias F ON F.ID = V.IDFotografia
WHERE F.IDParticipante = @IDVotante

SELECT @RankingConcurso = C.RankingMinimo FROM Concursos C
WHERE C.ID = @IDConcurso;

IF @RankingVotante < @RankingConcurso
BEGIN
RAISERROR('El ranking del usuario es insuficiente. Debe ser mayor o igual al ranking necesario para participar del concurso',16,1)
RETURN
END

-- - El concurso este vigente

DECLARE @FechaInicio DATE, @FechaFin DATE

SELECT @FechaInicio = C.Inicio, @FechaFin = C.Fin
FROM Concursos C
WHERE C.ID = @IDConcurso;

IF @Fecha NOT BETWEEN @FechaInicio AND @FechaFin
BEGIN
RAISERROR('El concurso no se encuentra vigente',16,1)
RETURN
END

INSERT INTO Votaciones(IDVotante, IDFotografia, Fecha, Puntaje)
VALUES (@IDVotante, @IDFotografia, @Fecha, @Puntaje)

		COMMIT TRANSACTION
		END TRY
		BEGIN CATCH
		PRINT ERROR_MESSAGE()
		ROLLBACK TRANSACTION
		END CATCH
END;

-- 5) Crear un trigger llamado TR_DescalificarFotografia para la tabla votaciones. 
-- Si al agregar una votacion, el puntaje promedio de esa fotografia es menor a 4 puntos, el trigger debe descalificar la fotografía.
-- ACLARACION: Esta validacion solo debe hacerse si la fotografía ya recibió tres o más puntuaciones luego de realizarse la insercion del voto.

CREATE OR ALTER TRIGGER TR_DescalificarFotografia ON Votaciones
AFTER INSERT
AS BEGIN

	--OBTENGO DATOS DE INSERTED
	DECLARE @IDFotografia BIGINT
	SELECT @IDFotografia = IDFotografia FROM inserted

	-- CUENTO CANTIDAD DE VOTOS
	DECLARE @CantVotos INT
	SELECT @CantVotos = COUNT(V.ID) FROM Votaciones V WHERE V.IDFotografia = @IDFotografia

	--OBTENGO PUNTAJE PROMEDIO
	DECLARE @Promedio DECIMAL(5,2)
	SELECT @Promedio = AVG(V.Puntaje) FROM Votaciones V WHERE V.IDFotografia = @IDFotografia

	IF @CantVotos >= 3 AND @Promedio < 4
	BEGIN
	UPDATE Fotografias
	SET Descalificada = 1
	WHERE ID = @IDFotografia
	PRINT('La fotografia fue descalificada')
	END
END;

--6) Crear una vista llamada VW_ParticipantesConBuenPuntaje que liste los participantes que tienen 
--un promedio de puntajes de fotografías mayor o igual a 8. La vista debe mostrar; 
--Apellido y nombre del participante, la cantidad de fotografias y el promedio total de puntajes de las mismas.
--ACLARACION: No se deben de tener en cuenta las fotografias descalificadas ni para el promedio ni para la cantidad de fotografias.

CREATE OR ALTER VIEW VW_ParticipantesConBuenPuntaje AS
SELECT P.Apellidos + ', ' + P.Nombres AS ApellidoNombre,
COUNT(F.ID) AS CantidadFotografias,
AVG(V.Puntaje) AS PuntajePromedio
FROM Participantes P
JOIN Fotografias F ON F.IDParticipante = P.ID
JOIN Votaciones V ON V.IDFotografia = F.ID
WHERE F.Descalificada = 0
GROUP BY P.Apellidos, P.Nombres
HAVING AVG(V.Puntaje) >= 8;
