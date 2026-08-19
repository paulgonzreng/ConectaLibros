use Master
go

if(exists(Select * FROM SysDataBases WHERE name='ConectaLibros'))
Begin
	Drop DATABASE ConectaLibros
End
go

-- esto crea la bd en el directorio databases en donde esta instalado el Sql server
Create Database ConectaLibros
go

--necesito abrir la bd para crear las tablas aca, sino se crean en la master (la bd del servidor)
Use ConectaLibros
go

--------------------- TABLAS --------------------- 

CREATE TABLE Pais
(
	CodP varchar(3) primary key,
	NomP varchar(30) not null,
	Continente varchar(2) not null
)
go

CREATE TABLE Autor
(
	CodA varchar(10) primary key,
	NomA varchar(30) not null,
	FechaNacA date not null,
	FechaDefA date null,
	CodP varchar(3) not null References Pais(CodP)
)
go

CREATE TABLE Editorial
(
	NomE varchar(30) primary key,
	Dir varchar(50) not null,
	NomUsuE varchar(15) not null,
	PassUsuE varchar(20) not null,
	CodP varchar(3) not null References Pais(CodP)
)
go

CREATE TABLE Libreria
(
	RUT varchar(12) primary key,
	NomL varchar(30) not null,
	NomUsuL varchar(15) not null,
	PassUsuL varchar(20) not null
)
go

CREATE TABLE Libros
(
	ISBN varchar(13) primary key,
	NomLib varchar(30) not null,
	Genero varchar(20) not null,
	Reseña varchar(200) not null,
	Stock int not null,
	CodA varchar(10) not null References Autor(CodA),
	NomE varchar(30) not null References Editorial(NomE)
)
go

CREATE TABLE Solicitud
(
	idSolicitud int identity primary key, -- autogenerada por el sistema
	FechaS datetime not null Default GetDate(), -- automatica
	FechaEntrega datetime not null,
	RUT varchar(12) not null References Libreria(RUT)
)
go

CREATE TABLE Incluye
(
	idSolicitud int not null References Solicitud(idSolicitud),
	ISBN varchar(13) not null References Libros(ISBN),
	Cantidad int not null,

	Primary Key(idSolicitud, ISBN)
)
go

------------------------- INDICES -------------------------
-- Se crean índices únicos sobre NomUsuE y NomUsuL porque la letra indica que los nombres de usuario deben ser únicos. 
-- No se usa UNIQUE a nivel de tabla, ya que las restricciones permitidas en tablas son PK, FK y DEFAULT. 
-- Además, el índice mejora las búsquedas por usuario.

CREATE UNIQUE INDEX Editorial_NomUsuE
ON Editorial(NomUsuE)
go

CREATE UNIQUE INDEX Libreria_NomUsuL
ON Libreria(NomUsuL)
go

------------------------- VISTAS -------------------------

CREATE VIEW Procedencia
AS
SELECT CodP 'IDProcedencia', NomP 'Denominacion', Continente 'Region'
FROM Pais
go

CREATE VIEW Escritores 
AS
SELECT CodA 'IDEscritor', NomA 'Denominacion', FechaNacA 'Nacimiento',
	   FechaDefA 'Fallecimiento', CodP 'IDProcedencia'
FROM Autor
go

CREATE VIEW ProveedoresLibros
AS
SELECT NomE 'IDProveedor', Dir 'Ubicacion', NomUsuE 'Acceso',
	   PassUsuE 'Clave', CodP 'IDProcedencia'
FROM Editorial
go

CREATE VIEW ClientesComerciales
AS
SELECT RUT 'IDCliente', NomL 'Denominacion', NomUsuL 'Acceso',
	   PassUsuL 'Clave'
FROM Libreria
go

CREATE VIEW Catalogo
AS
SELECT ISBN 'IDLibro', NomLib 'Denominacion', Genero 'Tipo',
	   Reseña 'Descripcion', Stock 'Disponible', 
	   CodA 'IDEscritor', NomE 'IDProveedor'
FROM Libros
go

CREATE VIEW Pedidos 
AS
SELECT idSolicitud 'IDPedido', FechaS 'FechaIngreso', FechaEntrega 'FechaLlegada',
	   RUT 'IDCliente'
FROM Solicitud
go

CREATE VIEW DetallePedido 
AS
SELECT idSolicitud 'IDPedido', ISBN 'IDLibro', Cantidad 'Total'
FROM Incluye
go

------------------------- TRIGGERS -------------------------
-- VISTA: Procedencia
-- TABLA: Pais
CREATE TRIGGER ValidoInsertProcedencia ON Procedencia INSTEAD OF insert
AS
BEGIN
	if exists(select * from inserted
          where IDProcedencia is null
             or Denominacion is null
             or Region is null)
	begin
		RAISERROR('Todos los campos de PAIS son obligatorios',16,1)
		return
	end

	-- validamos que el formato IDProcedencia (CodP) sea solo de 3 letras
	if exists(select * from inserted where LEN(IDProcedencia) <> 3 OR IDProcedencia LIKE '%[^a-zA-Z]%')
	begin
		RAISERROR('El código debe tener 3 letras, no se da de alta', 16,1)
		return
	end

	-- validamos que no exista la PK (CodP) en la bd
	if exists(select * from Pais where codP = (select IDProcedencia from inserted))
	begin
		RAISERROR('Ya existe, no podemos darlo de alta', 16,1)
		return
	end

	-- validamos formato
	if exists(select * from inserted where Region NOT IN ('AF', 'OC', 'EU', 'AS', 'AA'))
	begin
		RAISERROR('El continente ingresado no es valido, no se da de alta', 16,1)
		return
	end

	-- Si llego acá todo esta OK
	insert Pais(CodP, NomP, Continente)
	select IDProcedencia, Denominacion, Region
	from inserted
END
go

CREATE TRIGGER ValidoUpdateProcedencia ON Procedencia INSTEAD OF update
AS
BEGIN
	if exists(select * from inserted
          where IDProcedencia is null
             or Denominacion is null
             or Region is null)
	begin
		RAISERROR('Todos los campos de PAIS son obligatorios',16,1)
		return
	end

	-- validamos formato de IDProcedencia: exactamente 3 letras
	if exists(select * from inserted where LEN(IDProcedencia) <> 3 OR IDProcedencia LIKE '%[^a-zA-Z]%')
	begin
		RAISERROR('El codigo del Pais debe tener exactamente 3 letras', 16,1)
		return
	end

	-- validamos que el pais exista (PK) en la bd
	if not exists(select * from Pais where codP = (select IDProcedencia from inserted))
	begin
		RAISERROR('No existe el pais, no se puede modificar', 16,1)
		return
	end

	-- validamos formato
	if exists(select * from inserted where Region not in ('AF','OC','EU','AS','AA'))
	begin
		RAISERROR('El continente ingresado no es valido, no se modifica',16,1)
		return
	end

	-- Si llego acá todo esta OK, se puede modificar
	UPDATE Pais
	set NomP = (select Denominacion from inserted),
		Continente = (select Region from inserted)
	where CodP = (select IDProcedencia from inserted)

END
go

CREATE TRIGGER ValidoDeleteProcedencia ON Procedencia INSTEAD OF delete
AS
BEGIN

	-- validamos que exista el Pais (PK)
	if not exists(select * from Pais where codP = (select IDProcedencia from deleted))
	begin
		RAISERROR('No existe el Pais, no se elimina', 16,1)
		return
	end
	 
	-- validamos dependencia con Autor
	if exists(select * from Autor where CodP = (select IDProcedencia from deleted))
	begin
		RAISERROR('Existen Autores asociados a este Pais, no se elimina', 16,1)
		return
	end

	-- validamos dependencia con Editorial
	if exists(select * from Editorial where CodP = (select IDProcedencia from deleted))
	begin
		RAISERROR('Existen Editoriales asociados a este Pais, no se elimina', 16,1)
		return
	end

	-- Si llego acá todo esta OK, se puede eliminar
	DELETE Pais
	where CodP = (select IDProcedencia from deleted)
END
go

-- VISTA: Escritores
-- TABLA: Autor
CREATE TRIGGER ValidoInsertEscritores ON Escritores INSTEAD OF insert
AS
BEGIN
	-- validamos campos obligatorios
	if exists(select * from inserted
          where IDEscritor is null
             or Denominacion is null
             or Nacimiento is null
             or IDProcedencia is null)
	begin
		RAISERROR('Todos los campos del Autor son obligatorios',16,1)
		return
	end

	-- validamos formato de IDEscritor: 10 caracteres alfanumericos, con letras y numeros
	if exists(select * from inserted where LEN(IDEscritor) <> 10 
										OR IDEscritor LIKE '%[^a-zA-Z0-9]%'
										OR IDEscritor NOT LIKE '%[a-zA-Z]%'
										OR IDEscritor NOT LIKE '%[0-9]%')
	begin
		RAISERROR('El codigo del Autor debe tener 10 caracteres alfanumericos, con letras y numeros', 16,1)
		return
	end

	-- validamos que no exista la PK (CodA) en la bd
	if exists(select * from Autor where codA = (select IDEscritor from inserted))
	begin
		RAISERROR('Ya existe el Autor, no podemos darlo de alta', 16,1)
		return
	end

	-- validamos formato de IDProcedencia
	if exists(select * from inserted where LEN(IDProcedencia) <> 3 OR IDProcedencia LIKE '%[^a-zA-Z]%')
	begin
		RAISERROR('El codigo del Pais debe tener exactamente 3 letras', 16,1)
		return
	end

	-- validamos que exista el Pais (FK)
	if not exists(select * from Pais where CodP = (SELECT IDProcedencia FROM inserted))
	begin
		RAISERROR('No existe el Pais ingresado, no se da de alta', 16,1)
		return
	end

	-- validamos que el Autor sea mayor de edad
	if exists(select * from inserted where Nacimiento > dateadd(year, -18, getdate()))
	begin
		RAISERROR('El Autor es menor de edad, no se da de alta', 16,1)
		return
	end

	-- validamos fecha de fallecimiento
	if exists(select * from inserted 
			  where Fallecimiento is not null 
			    and (Fallecimiento <= Nacimiento OR Fallecimiento > GETDATE()))
	begin
		RAISERROR('La fecha de fallecimiento es invalida, no se da de alta', 16,1)
		return
	end

	-- Si llego acá todo esta OK
	insert Autor(CodA,NomA,FechaNacA, FechaDefA, CodP)
	select IDEscritor, Denominacion, Nacimiento, Fallecimiento, IDProcedencia
	from inserted
END
go

CREATE TRIGGER ValidoUpdateEscritores ON Escritores INSTEAD OF update
AS
BEGIN
	-- validamos campos obligatorios
	if exists(select * from inserted
          where IDEscritor is null
             or Denominacion is null
             or Nacimiento is null
             or IDProcedencia is null)
	begin
		RAISERROR('Todos los campos del Autor son obligatorios',16,1)
		return
	end
		
	-- validamos formato de IDEscritor
	if exists(select * from inserted where LEN(IDEscritor) <> 10 
										OR IDEscritor LIKE '%[^a-zA-Z0-9]%'
										OR IDEscritor NOT LIKE '%[a-zA-Z]%'
										OR IDEscritor NOT LIKE '%[0-9]%')
	begin
		RAISERROR('El codigo del Autor debe tener 10 caracteres alfanumericos, con letras y numeros', 16,1)
		return
	end

	-- validamos que el Autor exista (PK) en la bd
	if not exists(select * from Autor where codA = (select IDEscritor from inserted))
	begin
		RAISERROR('No existe el Autor, no se puede modificar', 16,1)
		return
	end

	-- validamos formato de IDProcedencia
	if exists(select * from inserted where LEN(IDProcedencia) <> 3 OR IDProcedencia LIKE '%[^a-zA-Z]%')
	begin
		RAISERROR('El codigo del Pais debe tener exactamente 3 letras', 16,1)
		return
	end

	-- validamos que exista el Pais
	if not exists(select * from Pais where CodP  = (select IDProcedencia from inserted))
	begin
		RAISERROR('El Pais ingresado no existe, no se modifica',16,1)
		return
	end

	-- Validamos Fecha de nacimiento >= 18
	if exists(select * from inserted where Nacimiento > dateadd(year, -18, getdate()))
	begin
		RAISERROR('El Autor es menor de edad, no se modifica', 16,1)
		return
	end

	-- Validamos Fecha de defuncion > Fecha de Nac y <= hoy
	if exists(select * from inserted where Fallecimiento is not null AND (Fallecimiento <= Nacimiento OR Fallecimiento > GETDATE()))
	begin
		RAISERROR('La fecha de fallecimiento es invalida, no se modifica', 16,1)
		return
	end

	-- Si llego acá todo esta OK, se puede modificar
	UPDATE Autor
	set NomA = (select Denominacion from inserted),
		FechaNacA = (select Nacimiento from inserted),
		FechaDefA = (select Fallecimiento from inserted),
		CodP =(select IDProcedencia from inserted)
	where CodA = (select IDEscritor from inserted)

END
go

CREATE TRIGGER ValidoDeleteEscritores ON Escritores INSTEAD OF delete
AS
BEGIN

	-- validamos que exista el Autor (PK)
	if not exists(select * from Autor where codA = (select IDEscritor from deleted))
	begin
		RAISERROR('No existe el Autor, no se elimina', 16,1)
		return
	end
	 
	-- validamos dependencia con Libros
	if exists(select * from Libros where CodA = (select IDEscritor from deleted))
	begin
		RAISERROR('Existen Libros asociados a este Autor, no se elimina', 16,1)
		return
	end

	-- Si llego acá todo esta OK, se puede eliminar
	DELETE Autor
	where CodA = (select IDEscritor from deleted)
END
go

-- VISTA: ProveedoresLibros
-- TABLA: Editorial
CREATE TRIGGER ValidoInsertProveedores ON ProveedoresLibros INSTEAD OF insert
AS
BEGIN
	-- validamos campos obligatorios
	if exists(select * from inserted
			where IDProveedor is null
				or Ubicacion is null
				or Acceso is null
				or Clave is null
				or IDProcedencia is null)
	begin
		RAISERROR('Todos los campos de la Editorial son obligatorios',16,1)
		return
	end

	-- validamos que no exista la PK (NomE) en la bd
	if exists(select * from Editorial where NomE = (select IDProveedor from inserted))
	begin
		RAISERROR('La Editorial ya existe, no podemos darlo de alta', 16,1)
		return
	end

	-- validamos formato del pais
	if exists(select * from inserted where LEN(IDProcedencia) <> 3 OR IDProcedencia LIKE '%[^a-zA-Z]%')
	begin
		RAISERROR('El codigo del Pais debe tener exactamente 3 letras', 16,1)
		return
	end

	-- validamos que exista el Pais (FK)
	if not exists(select * from Pais where CodP = (select IDProcedencia from inserted))
	begin
		RAISERROR('El Pais no existe', 16,1)
		return
	end

	-- validamos que el formato de Acceso (NomUsuE) - entre 8 y 15 caracteres
	if exists(select * from inserted where LEN(Acceso) not between 8 and 15)
	begin
		RAISERROR('El usuario debe tener entre 8 y 15 caracteres', 16,1)
		return
	end
	
	-- validamos que el usuario sea unico
	-- ya lo hace el indice pero aca mostramos el error
	if exists(select * from Editorial where NomUsuE = (select Acceso from inserted))
	begin
		RAISERROR('El usuario ya existe, no se da el alta', 16,1)
		return
	end

	-- validamos contraseña (PassUsuE)
	if exists(select * from inserted where LEN(Clave) < 8
										OR LEN(Clave) > 20
										OR Clave not like '%[0-9]%'
										OR Clave not like '%[a-zA-Z]%'
										OR Clave not like '%[^a-zA-Z0-9]%')
	begin
		RAISERROR('La contraseña debe tener minimo de 8 caracteres, debe contener al menos 1 dígito, una letra y un símbolo', 16,1)
		return
	end

	-- Si llego acá todo esta OK
	insert Editorial(NomE, Dir, NomUsuE, PassUsuE, CodP)
	select IDProveedor, Ubicacion, Acceso, Clave, IDProcedencia
	from inserted
END
go

CREATE TRIGGER ValidoUpdateProveedores ON ProveedoresLibros INSTEAD OF update
AS
BEGIN
	-- validamos campos obligatorios
	if exists(select * from inserted
			where IDProveedor is null
				or Ubicacion is null
				or Acceso is null
				or Clave is null
				or IDProcedencia is null)
	begin
		RAISERROR('Todos los campos de la Editorial son obligatorios',16,1)
		return
	end

	-- validamos que la Editorial exista (PK) en la bd
	if not exists(select * from Editorial where NomE = (select IDProveedor from inserted))
	begin
		RAISERROR('No existe la Editorial, no se puede modificar', 16,1)
		return
	end

	-- validamos formato del pais
	if exists(select * from inserted where LEN(IDProcedencia) <> 3 OR IDProcedencia LIKE '%[^a-zA-Z]%')
	begin
		RAISERROR('El codigo del Pais debe tener exactamente 3 letras', 16,1)
		return
	end

	-- validamos que exista el Pais (FK)
	if not exists(select * from Pais where CodP  = (select IDProcedencia from inserted))
	begin
		RAISERROR('El Pais ingresado no existe, no se modifica',16,1)
		return
	end

	-- validamos que el formato de Acceso (NomUsuE) - entre 8 y 15 caracteres
	if exists(select * from inserted where LEN(Acceso) not between 8 and 15)
	begin
		RAISERROR('El usuario debe tener entre 8 y 15 caracteres', 16,1)
		return
	end
	
	-- validamos que el usuario sea unico
	-- Se excluye la editorial actual para permitir mantener su mismo usuario
	if exists(select * from Editorial where NomUsuE = (select Acceso from inserted) AND NomE <> (select IDProveedor from inserted))
	begin
		RAISERROR('El usuario ya existe, no se modifica', 16,1)
		return
	end

	-- validamos contraseña (PassUsuE)
	if exists(select * from inserted where LEN(Clave) < 8
										OR LEN(Clave) > 20
										OR Clave not like '%[0-9]%'
										OR Clave not like '%[a-zA-Z]%'
										OR Clave not like '%[^a-zA-Z0-9]%')
	begin
		RAISERROR('La contraseña debe tener minimo de 8 caracteres, debe contener al menos 1 dígito, una letra y un símbolo', 16,1)
		return
	end

	-- Si llego acá todo esta OK, se puede modificar
	UPDATE Editorial
	set Dir = (select Ubicacion from inserted),
		NomUsuE = (select Acceso from inserted),
		PassUsuE = (select Clave from inserted),
		CodP =(select IDProcedencia from inserted)
	where NomE = (select IDProveedor from inserted)

END
go

CREATE TRIGGER ValidoDeleteProveedores ON ProveedoresLibros INSTEAD OF delete
AS
BEGIN
	-- validamos que exista la Editorial (PK)
	if not exists(select * from Editorial where NomE = (select IDProveedor from deleted))
	begin
		RAISERROR('No existe la Editorial, no se elimina', 16,1)
		return
	end
	 
	-- validamos dependencia con Libros
	if exists(select * from Libros where NomE = (select IDProveedor from deleted))
	begin
		RAISERROR('Existen Libros asociados a esta Editorial, no se elimina', 16,1)
		return
	end

	-- Si llego acá todo esta OK, se puede eliminar
	DELETE Editorial
	where NomE = (select IDProveedor from deleted)
END
go

-- VISTA: ClientesComerciales
-- TABLA: Librería
CREATE TRIGGER ValidoInsertCliComerciales ON ClientesComerciales INSTEAD OF insert
AS
BEGIN
	-- validamos campos obligatorios
	if exists(select * from inserted
          where IDCliente is null
             or Denominacion is null
             or Acceso is null
             or Clave is null)
	begin
		RAISERROR('Todos los campos de la Libreria son obligatorios',16,1)
		return
	end

	-- validamos formato del RUT - 12 digitos numericos
	if exists(select * from inserted where LEN(IDCliente) <> 12 OR IDCliente LIKE '%[^0-9]%')
	begin
		RAISERROR('El RUT debe tener 12 digitos numericos, no se da de alta', 16,1)
		return
	end

	-- validamos que no exista la PK (RUT) en la bd
	if exists(select * from Libreria where RUT = (select IDCliente from inserted))
	begin
		RAISERROR('La Librería ya existe, no podemos darlo de alta', 16,1)
		return
	end

	-- validamos que el formato de Acceso (NomUsuL) - entre 8 y 15 caracteres
	if exists(select * from inserted where LEN(Acceso) not between 8 and 15)
	begin
		RAISERROR('El usuario debe tener entre 8 y 15 caracteres', 16,1)
		return
	end
	
	-- validamos que el usuario sea unico
	-- ya lo hace el indice pero aca mostramos el error
	if exists(select * from Libreria where NomUsuL = (select Acceso from inserted))
	begin
		RAISERROR('El usuario ya existe, no se da el alta', 16,1)
		return
	end

	-- validamos contraseña (PassUsuL)
	if exists(select * from inserted where LEN(Clave) < 8
										OR LEN(Clave) > 20
										OR Clave not like '%[0-9]%'
										OR Clave not like '%[a-zA-Z]%'
										OR Clave not like '%[^a-zA-Z0-9]%')
	begin
		RAISERROR('La contraseña debe tener minimo de 8 caracteres y maximo 20, debe contener al menos 1 dígito, una letra y un símbolo', 16,1)
		return
	end

	-- Si llego acá todo esta OK
	insert Libreria(RUT, NomL, NomUsuL, PassUsuL)
	select IDCliente, Denominacion, Acceso, Clave
	from inserted
END
go

CREATE TRIGGER ValidoUpdateCliComerciales ON ClientesComerciales INSTEAD OF update
AS
BEGIN
	-- validamos campos obligatorios
	if exists(select * from inserted
          where IDCliente is null
             or Denominacion is null
             or Acceso is null
             or Clave is null)
	begin
		RAISERROR('Todos los campos de la Libreria son obligatorios',16,1)
		return
	end

	-- validamos formato del RUT: 12 digitos numericos
	if exists(select * from inserted where LEN(IDCliente) <> 12 OR IDCliente LIKE '%[^0-9]%')
	begin
		RAISERROR('El RUT debe tener 12 digitos numericos, no se modifica', 16,1)
		return
	end

	-- validamos que la Libreria exista (PK) en la bd
	if not exists(select * from Libreria where RUT = (select IDCliente from inserted))
	begin
		RAISERROR('No existe la Libreria, no se puede modificar', 16,1)
		return
	end

	-- validamos que el formato de Acceso (NomUsuL) - entre 8 y 15 caracteres
	if exists(select * from inserted where LEN(Acceso) not between 8 and 15)
	begin
		RAISERROR('El usuario debe tener entre 8 y 15 caracteres', 16,1)
		return
	end
	
	-- validamos que el usuario sea unico
	-- Se excluye la Libreria actual para permitir mantener su mismo usuario
	if exists(select * from Libreria where NomUsuL = (select Acceso from inserted) AND RUT <> (select IDCliente from inserted))
	begin
		RAISERROR('El usuario ya existe, no se modifica', 16,1)
		return
	end

	-- validamos contraseña (PassUsuL)
	if exists(select * from inserted where LEN(Clave) < 8
										OR LEN(Clave) > 20
										OR Clave not like '%[0-9]%'
										OR Clave not like '%[a-zA-Z]%'
										OR Clave not like '%[^a-zA-Z0-9]%')
	begin
		RAISERROR('La contraseña debe tener minimo de 8 caracteres y maximo 20, debe contener al menos 1 dígito, una letra y un símbolo', 16,1)
		return
	end

	-- Si llego acá todo esta OK, se puede modificar
	UPDATE Libreria
	set NomL = (select Denominacion from inserted),
		NomUsuL = (select Acceso from inserted),
		PassUsuL = (select Clave from inserted)
	where RUT = (select IDCliente from inserted)

END
go

CREATE TRIGGER ValidoDeleteCliComerciales ON ClientesComerciales INSTEAD OF delete
AS
BEGIN
	-- validamos que exista la Libreria (PK)
	if not exists(select * from Libreria where RUT = (select IDCliente from deleted))
	begin
		RAISERROR('No existe la Libreria, no se elimina', 16,1)
		return
	end
	 
	-- validamos dependencia con Solicitudes
	if exists(select * from Solicitud where RUT = (select IDCliente from deleted))
	begin
		RAISERROR('Existen pedidos asociados a esta Libreria, no se elimina', 16,1)
		return
	end

	-- Si llego acá todo esta OK, se puede eliminar
	DELETE Libreria
	where RUT = (select IDCliente from deleted)
END
go

-- VISTA: Catalogo
-- TABLA: Libros
CREATE TRIGGER ValidoInsertCatalogo ON Catalogo INSTEAD OF insert
AS
BEGIN
	-- validamos campos obligatorios
	if exists(select * from inserted
          where IDLibro is null
             or Denominacion is null
             or Tipo is null
             or Descripcion is null
             or Disponible is null
             or IDEscritor is null
             or IDProveedor is null)
	begin
		RAISERROR('Todos los campos del Libro son obligatorios',16,1)
		return
	end

	-- validamos formato del ISBN
	if exists(select * from inserted where LEN(IDLibro) <> 13 OR IDLibro LIKE '%[^0-9]%')
	begin
		RAISERROR('El ISBN debe tener 13 digitos numericos', 16,1)
		return
	end

	-- validamos que no exista la PK (ISBN)
	if exists(select * from Libros where ISBN = (select IDLibro from inserted))
	begin
		RAISERROR('El Libro ya existe, no podemos darlo de alta', 16,1)
		return
	end

	-- validamos formato del Autor
	if exists(select * from inserted where LEN(IDEscritor) <> 10 
										OR IDEscritor LIKE '%[^a-zA-Z0-9]%'
										OR IDEscritor NOT LIKE '%[a-zA-Z]%'
										OR IDEscritor NOT LIKE '%[0-9]%')
	begin
		RAISERROR('El codigo del Autor debe tener 10 caracteres alfanumericos, con letras y numeros', 16,1)
		return
	end

	-- validamos que exista el Autor (FK)
	if not exists(select * from Autor where CodA = (select IDEscritor from inserted))
	begin
		RAISERROR('El Autor no existe', 16,1)
		return
	end

	-- validamos que exista la Editorial (FK)
	if not exists(select * from Editorial where NomE = (select IDProveedor from inserted))
	begin
		RAISERROR('La Editorial no existe', 16,1)
		return
	end

	-- validamos stock no negativo
	if exists(select * from inserted where Disponible < 0)
	begin
		RAISERROR('El Stock no puede ser negativo', 16,1)
		return
	end

	-- Si llego acá todo esta OK
	insert Libros(ISBN, NomLib, Genero, Reseña, Stock, CodA, NomE)
	select IDLibro, Denominacion, Tipo, Descripcion, Disponible, IDEscritor, IDProveedor
	from inserted
END
go

CREATE TRIGGER ValidoUpdateCatalogo ON Catalogo INSTEAD OF update
AS
BEGIN
	-- validamos campos obligatorios
	if exists(select * from inserted
          where IDLibro is null
             or Denominacion is null
             or Tipo is null
             or Descripcion is null
             or Disponible is null
             or IDEscritor is null
             or IDProveedor is null)
	begin
		RAISERROR('Todos los campos del Libro son obligatorios',16,1)
		return
	end

	-- validamos formato del ISBN
	if exists(select * from inserted where LEN(IDLibro) <> 13 OR IDLibro LIKE '%[^0-9]%')
	begin
		RAISERROR('El ISBN debe tener 13 digitos numericos', 16,1)
		return
	end

	-- validamos que el Libro exista (PK)
	if not exists(select * from Libros where ISBN = (select IDLibro from inserted))
	begin
		RAISERROR('No existe el Libro, no se puede modificar', 16,1)
		return
	end

	-- validamos formato del Autor
	if exists(select * from inserted where LEN(IDEscritor) <> 10 
										OR IDEscritor LIKE '%[^a-zA-Z0-9]%'
										OR IDEscritor NOT LIKE '%[a-zA-Z]%'
										OR IDEscritor NOT LIKE '%[0-9]%')
	begin
		RAISERROR('El codigo del Autor debe tener 10 caracteres alfanumericos, con letras y numeros', 16,1)
		return
	end

	-- validamos que exista el Autor (FK)
	if not exists(select * from Autor where CodA = (select IDEscritor from inserted))
	begin
		RAISERROR('El Autor no existe, no se modifica', 16,1)
		return
	end

	-- validamos que exista la Editorial (FK)
	if not exists(select * from Editorial where NomE = (select IDProveedor from inserted))
	begin
		RAISERROR('La Editorial no existe, no se modifica', 16,1)
		return
	end

	-- validamos stock no negativo
	if exists(select * from inserted where Disponible < 0)
	begin
		RAISERROR('El Stock no puede ser negativo', 16,1)
		return
	end

	-- Si llego acá todo esta OK, se puede modificar
	UPDATE Libros
	set NomLib = (select Denominacion from inserted),
		Genero = (select Tipo from inserted),
		Reseña = (select Descripcion from inserted),
		Stock = (select Disponible from inserted),
		CodA = (select IDEscritor from inserted),
		NomE = (select IDProveedor from inserted)
	where ISBN = (select IDLibro from inserted)

END
go

CREATE TRIGGER ValidoDeleteCatalogo ON Catalogo INSTEAD OF delete
AS
BEGIN
	-- validamos que exista el Libro (PK)
	if not exists(select * from Libros where ISBN = (select IDLibro from deleted))
	begin
		RAISERROR('No existe el Libro, no se elimina', 16,1)
		return
	end
	 
	-- validamos dependencia con Incluye
	if exists(select * from Incluye where ISBN = (select IDLibro from deleted))
	begin
		RAISERROR('Existen pedidos asociados a este Libro, no se elimina', 16,1)
		return
	end

	-- Si llego acá todo esta OK, se puede eliminar
	DELETE Libros
	where ISBN = (select IDLibro from deleted)
END
go

------------------------- SP -------------------------
-- Pais: ABM, Busqueda individual y listado completo
CREATE PROCEDURE AltaProcedencia 
@IDProcedencia varchar(3), 
@Denominacion varchar(30), 
@Region varchar(2)
AS
BEGIN
	begin try
		insert Procedencia(IDProcedencia, Denominacion, Region)
		values(@IDProcedencia, @Denominacion, @Region)
	end try
	begin catch
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE ModificarProcedencia 
@IDProcedencia varchar(3), 
@Denominacion varchar(30), 
@Region varchar(2)
AS
BEGIN
	begin try
		update Procedencia
		set Denominacion = @Denominacion,
			Region = @Region
		where IDProcedencia = @IDProcedencia
	end try
	begin catch
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE BajaProcedencia 
@IDProcedencia varchar(3)
AS
BEGIN
	begin try
		delete Procedencia
		where IDProcedencia = @IDProcedencia
	end try
	begin catch
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE BuscarProcedencia 
@IDProcedencia varchar(3)
AS
BEGIN
	select *
	from Procedencia
	where IDProcedencia = @IDProcedencia
END
go

CREATE PROCEDURE ListarProcedencias
AS
BEGIN
	select *
	from Procedencia
END
go

-- Autor: ABM, Busqueda individual y listado completo
CREATE PROCEDURE AltaEscritor 
@IDEscritor varchar(10), 
@Denominacion varchar(30), 
@Nacimiento date, 
@Fallecimiento date, 
@IDProcedencia varchar(3)
AS
BEGIN
	begin try
		insert Escritores(IDEscritor, Denominacion, Nacimiento, Fallecimiento, IDProcedencia)
		values(@IDEscritor, @Denominacion, @Nacimiento, @Fallecimiento, @IDProcedencia)
	end try
	begin catch
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE ModificarEscritor 
@IDEscritor varchar(10), 
@Denominacion varchar(30), 
@Nacimiento date, 
@Fallecimiento date, 
@IDProcedencia varchar(3)
AS
BEGIN
	begin try
		update Escritores
		set Denominacion = @Denominacion,
			Nacimiento = @Nacimiento,
			Fallecimiento = @Fallecimiento,
			IDProcedencia = @IDProcedencia
		where IDEscritor = @IDEscritor
	end try
	begin catch
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE BajaEscritor 
@IDEscritor varchar(10)
AS
BEGIN
	begin try
		delete Escritores
		where IDEscritor = @IDEscritor
	end try
	begin catch
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE BuscarEscritor 
@IDEscritor varchar(10)
AS
BEGIN
	select *
	from Escritores
	where IDEscritor = @IDEscritor
END
go

CREATE PROCEDURE ListarEscritores
AS
BEGIN
	select *
	from Escritores
END
go

-- Editorial: ABM, Busqueda individual y listado completo
CREATE PROCEDURE AltaProveedoresLibros 
@IDProveedor varchar(30), 
@Ubicacion varchar(50), 
@Acceso varchar(15), 
@Clave varchar(20), 
@IDProcedencia varchar(3)
AS
BEGIN
	begin transaction
	begin try
		-- El insert dispara el trigger ValidoInsertProveedores
		insert ProveedoresLibros(IDProveedor, Ubicacion, Acceso, Clave, IDProcedencia)
		values(@IDProveedor, @Ubicacion, @Acceso, @Clave, @IDProcedencia)

		declare @varSentencia varchar(200)

		-- creamos login sql
		set @varSentencia = 'CREATE LOGIN [' + @Acceso + '] WITH PASSWORD = ' + QUOTENAME(@Clave, '''')
		exec(@varSentencia)

		-- creamos usuario en la base
		set @varSentencia = 'CREATE USER [' + @Acceso + '] FROM LOGIN [' + @Acceso + ']'
		exec(@varSentencia)

		-- asignamos rol editorial
		set @varSentencia = 'ALTER ROLE RolEditorial ADD MEMBER [' + @Acceso + ']'
		exec(@varSentencia)

		COMMIT
	end try
	begin catch
		ROLLBACK

		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE ModificarProveedoresLibros 
@IDProveedor varchar(30), 
@Ubicacion varchar(50), 
@Acceso varchar(15), 
@ClaveAnt varchar(20),
@ClaveNew varchar(20),
@IDProcedencia varchar(3)
AS
BEGIN
	begin transaction
	begin try
		UPDATE ProveedoresLibros
		set Ubicacion = @Ubicacion,
			Acceso = @Acceso,
			Clave = @ClaveNew,
			IDProcedencia = @IDProcedencia
		where IDProveedor = @IDProveedor

		declare @varSentencia varchar(200)

		--Actualizamos la pass del usuario LOGIN
		set @varSentencia = 'ALTER LOGIN [' + @Acceso + '] WITH PASSWORD = ' + QUOTENAME(@ClaveNew, '''') 
						   + ' OLD_PASSWORD = ' + QUOTENAME(@ClaveAnt, '''')
		exec(@varSentencia)

		COMMIT
	end try
	begin catch
		ROLLBACK
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE BajaProveedoresLibros 
@IDProveedor varchar(30)
AS
BEGIN
	begin transaction
	begin try
		declare @Acceso varchar(15)
		declare @varSentencia varchar(200)

		-- obtengo el usuario antes de eliminar el registro
		select @Acceso = Acceso
		from ProveedoresLibros
		where IDProveedor = @IDProveedor

		-- elimina la editorial, dispara el trigger ValidoDeleteProveedores
		delete ProveedoresLibros
		where IDProveedor = @IDProveedor

		-- elimina el usuario de la bd
		set @varSentencia = 'DROP USER [' + @Acceso + ']'
		exec(@varSentencia)

		-- elimina el login del servidor
		set @varSentencia = 'DROP LOGIN [' + @Acceso + ']'
		exec(@varSentencia)

		COMMIT
	end try
	begin catch
		ROLLBACK
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE BuscarProveedoresLibros 
@IDProveedor varchar(30)
AS
BEGIN
	select *
	from ProveedoresLibros
	where IDProveedor = @IDProveedor
END
go

CREATE PROCEDURE ListarProveedoresLibros
AS
BEGIN
	select *
	from ProveedoresLibros
END
go

-- Librería: ABM, Busqueda individual y listado completo
CREATE PROCEDURE AltaClientesComerciales 
@IDCliente varchar(12), 
@Denominacion varchar(30),
@Acceso varchar(15), 
@Clave varchar(20)
AS
BEGIN
	begin transaction
	begin try
		-- El insert dispara el trigger ValidoInsertCliComerciales
		insert ClientesComerciales(IDCliente, Denominacion, Acceso, Clave)
		values(@IDCliente, @Denominacion, @Acceso, @Clave)

		declare @varSentencia varchar(200)

		-- Creamos login SQL
		set @varSentencia = 'CREATE LOGIN [' + @Acceso + '] WITH PASSWORD = ' + QUOTENAME(@Clave, '''')
		exec(@varSentencia)

		-- Creamos usuario en la base
		set @varSentencia = 'CREATE USER [' + @Acceso + '] FROM LOGIN [' + @Acceso + ']'
		exec(@varSentencia)

		-- Asignamos rol librería
		set @varSentencia = 'ALTER ROLE RolLibreria ADD MEMBER [' + @Acceso + ']'
		exec(@varSentencia)

		COMMIT
	end try
	begin catch
		ROLLBACK

		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE ModificarClientesComerciales 
@IDCliente varchar(12),
@Denominacion varchar(30),
@Acceso varchar(15),
@ClaveAnt varchar(20),
@ClaveNew varchar(20)
AS
BEGIN
	begin transaction
	begin try
		UPDATE ClientesComerciales
		set Denominacion = @Denominacion,
			Acceso = @Acceso,
			Clave = @ClaveNew
		where IDCliente = @IDCliente

		declare @varSentencia varchar(200)

		--Actualizamos la pass del usuario LOGIN
		set @varSentencia = 'ALTER LOGIN [' + @Acceso + '] WITH PASSWORD = ' + QUOTENAME(@ClaveNew, '''') 
						   + ' OLD_PASSWORD = ' + QUOTENAME(@ClaveAnt, '''')
		exec(@varSentencia)

		COMMIT
	end try
	begin catch
		ROLLBACK
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE BajaClientesComerciales 
@IDCliente varchar(12)
AS
BEGIN
	begin transaction
	begin try
		declare @Acceso varchar(15)
		declare @varSentencia varchar(200)

		-- obtengo el usuario antes de eliminar el registro
		select @Acceso = Acceso
		from ClientesComerciales
		where IDCliente = @IDCliente

		-- elimina la librería, dispara el trigger ValidoDeleteCliComerciales
		delete ClientesComerciales
		where IDCliente = @IDCliente

		-- elimina el usuario de la bd
		set @varSentencia = 'DROP USER [' + @Acceso + ']'
		exec(@varSentencia)

		-- elimina el login del servidor
		set @varSentencia = 'DROP LOGIN [' + @Acceso + ']'
		exec(@varSentencia)

		COMMIT
	end try
	begin catch
		ROLLBACK
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch

END
go

CREATE PROCEDURE BuscarClientesComerciales 
@IDCliente varchar(12)
AS
BEGIN
	select *
	from ClientesComerciales
	where IDCliente = @IDCliente
END
go

CREATE PROCEDURE ListarClientesComerciales
AS
BEGIN
	select *
	from ClientesComerciales
END
go

-- Libros: ABM, Busqueda individual y listado completo
CREATE PROCEDURE AltaCatalogo 
@IDLibro varchar(13),
@Denominacion varchar(30),
@Tipo varchar(20),
@Descripcion varchar(200),
@Disponible int,
@IDEscritor varchar(10),
@IDProveedor varchar(30)
AS
BEGIN
	begin try
		insert Catalogo(IDLibro, Denominacion, Tipo, Descripcion, Disponible, IDEscritor, IDProveedor)
		values(@IDLibro, @Denominacion, @Tipo, @Descripcion, @Disponible, @IDEscritor, @IDProveedor)
	end try
	begin catch
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE ModificarCatalogo 
@IDLibro varchar(13),
@Denominacion varchar(30),
@Tipo varchar(20),
@Descripcion varchar(200),
@Disponible int,
@IDEscritor varchar(10),
@IDProveedor varchar(30)
AS
BEGIN
	begin try
		update Catalogo
		set Denominacion = @Denominacion,
			Tipo = @Tipo,
			Descripcion = @Descripcion,
			Disponible = @Disponible,
			IDEscritor = @IDEscritor,
			IDProveedor = @IDProveedor
		where IDLibro = @IDLibro
	end try
	begin catch
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch

END
go

CREATE PROCEDURE BajaCatalogo 
@IDLibro varchar(13)
AS
BEGIN
	begin try
		delete Catalogo
		where IDLibro = @IDLibro
	end try
	begin catch
		declare @Mensaje varchar(200)
		set @Mensaje = ERROR_MESSAGE()
		RAISERROR(@Mensaje,16,1)
	end catch
END
go

CREATE PROCEDURE BuscarCatalogo 
@IDLibro varchar(13)
AS
BEGIN
	select *
	from Catalogo
	where IDLibro = @IDLibro
END
go

CREATE PROCEDURE ListarCatalogo
AS
BEGIN
	select *
	from Catalogo
END
go

-- Listado de Libros con Stock
CREATE PROCEDURE ListarCatalogoConStock
AS
BEGIN
	select *
	from Catalogo
	where Disponible > 0
END
go

------------------------- ROLES Y PERMISOS -------------------------
-- Rol para librerias:
--	pueden ejecutar procedimientos de listados y busquedas individuales 
CREATE ROLE RolLibreria
go

GRANT EXECUTE ON BuscarProcedencia TO RolLibreria
GRANT EXECUTE ON ListarProcedencias TO RolLibreria

GRANT EXECUTE ON BuscarEscritor TO RolLibreria
GRANT EXECUTE ON ListarEscritores TO RolLibreria

GRANT EXECUTE ON BuscarProveedoresLibros TO RolLibreria
GRANT EXECUTE ON ListarProveedoresLibros TO RolLibreria

GRANT EXECUTE ON BuscarClientesComerciales TO RolLibreria
GRANT EXECUTE ON ListarClientesComerciales TO RolLibreria

GRANT EXECUTE ON BuscarCatalogo TO RolLibreria
GRANT EXECUTE ON ListarCatalogo TO RolLibreria
GRANT EXECUTE ON ListarCatalogoConStock TO RolLibreria
go

-- Rol para editoriales:
--	pueden ejecutar procedimientos relativos a Autores, Paises y Libros
--	y tambien listados y busquedas individuales

CREATE ROLE RolEditorial
go

GRANT EXECUTE ON AltaEscritor TO RolEditorial
GRANT EXECUTE ON ModificarEscritor TO RolEditorial
GRANT EXECUTE ON BajaEscritor TO RolEditorial

GRANT EXECUTE ON BuscarEscritor TO RolEditorial
GRANT EXECUTE ON ListarEscritores TO RolEditorial

GRANT EXECUTE ON AltaProcedencia TO RolEditorial
GRANT EXECUTE ON ModificarProcedencia TO RolEditorial
GRANT EXECUTE ON BajaProcedencia TO RolEditorial

GRANT EXECUTE ON BuscarProcedencia TO RolEditorial
GRANT EXECUTE ON ListarProcedencias TO RolEditorial

GRANT EXECUTE ON AltaCatalogo TO RolEditorial
GRANT EXECUTE ON ModificarCatalogo TO RolEditorial
GRANT EXECUTE ON BajaCatalogo TO RolEditorial
GRANT EXECUTE ON BuscarCatalogo TO RolEditorial

GRANT EXECUTE ON ListarCatalogo TO RolEditorial
GRANT EXECUTE ON ListarCatalogoConStock TO RolEditorial

GRANT EXECUTE ON BuscarProveedoresLibros TO RolEditorial
GRANT EXECUTE ON ListarProveedoresLibros TO RolEditorial

GRANT EXECUTE ON BuscarClientesComerciales TO RolEditorial
GRANT EXECUTE ON ListarClientesComerciales TO RolEditorial
go

------------------------- DATOS DE PRUEBA -------------------------
-- Paises - 30 datos
EXEC AltaProcedencia 'URY','Uruguay','AA'
EXEC AltaProcedencia 'ARG','Argentina','AA'
EXEC AltaProcedencia 'BRA','Brasil','AA'
EXEC AltaProcedencia 'CHL','Chile','AA'
EXEC AltaProcedencia 'PRY','Paraguay','AA'
EXEC AltaProcedencia 'BOL','Bolivia','AA'
EXEC AltaProcedencia 'PER','Peru','AA'
EXEC AltaProcedencia 'COL','Colombia','AA'
EXEC AltaProcedencia 'ECU','Ecuador','AA'
EXEC AltaProcedencia 'CAN','Canada','AA'

EXEC AltaProcedencia 'ESP','España','EU'
EXEC AltaProcedencia 'FRA','Francia','EU'
EXEC AltaProcedencia 'ITA','Italia','EU'
EXEC AltaProcedencia 'DEU','Alemania','EU'
EXEC AltaProcedencia 'PRT','Portugal','EU'
EXEC AltaProcedencia 'GBR','Reino Unido','EU'
EXEC AltaProcedencia 'NLD','Paises Bajos','EU'
EXEC AltaProcedencia 'BEL','Belgica','EU'

EXEC AltaProcedencia 'CHN','China','AS'
EXEC AltaProcedencia 'JPN','Japon','AS'
EXEC AltaProcedencia 'KOR','Corea del Sur','AS'
EXEC AltaProcedencia 'IND','India','AS'
EXEC AltaProcedencia 'THA','Tailandia','AS'
EXEC AltaProcedencia 'VNM','Vietnam','AS'

EXEC AltaProcedencia 'AUS','Australia','OC'
EXEC AltaProcedencia 'NZL','Nueva Zelanda','OC'

EXEC AltaProcedencia 'ZAF','Sudafrica','AF'
EXEC AltaProcedencia 'EGY','Egipto','AF'
EXEC AltaProcedencia 'MAR','Marruecos','AF'
EXEC AltaProcedencia 'NGA','Nigeria','AF'
go

-- Autores - 50 datos
EXEC AltaEscritor 'AUT0000001','Miguel Cervantes','1547-09-29','1616-04-22','ESP'
EXEC AltaEscritor 'AUT0000002','Lope de Vega','1562-11-25','1635-08-27','ESP'
EXEC AltaEscritor 'AUT0000003','Benito Galdos','1843-05-10','1920-01-04','ESP'
EXEC AltaEscritor 'AUT0000004','Federico Lorca','1898-06-05','1936-08-18','ESP'
EXEC AltaEscritor 'AUT0000005','Arturo Perez','1951-11-25',NULL,'ESP'

EXEC AltaEscritor 'AUT0000006','Victor Hugo','1802-02-26','1885-05-22','FRA'
EXEC AltaEscritor 'AUT0000007','Jules Verne','1828-02-08','1905-03-24','FRA'
EXEC AltaEscritor 'AUT0000008','Alexandre Dumas','1802-07-24','1870-12-05','FRA'
EXEC AltaEscritor 'AUT0000009','Albert Camus','1913-11-07','1960-01-04','FRA'
EXEC AltaEscritor 'AUT0000010','Marcel Proust','1871-07-10','1922-11-18','FRA'

EXEC AltaEscritor 'AUT0000011','Dante Alighieri','1265-01-01','1321-09-14','ITA'
EXEC AltaEscritor 'AUT0000012','Umberto Eco','1932-01-05','2016-02-19','ITA'
EXEC AltaEscritor 'AUT0000013','Italo Calvino','1923-10-15','1985-09-19','ITA'
EXEC AltaEscritor 'AUT0000014','Alberto Moravia','1907-11-28','1990-09-26','ITA'
EXEC AltaEscritor 'AUT0000015','Elena Ferrante','1943-01-01',NULL,'ITA'

EXEC AltaEscritor 'AUT0000016','Johann Goethe','1749-08-28','1832-03-22','DEU'
EXEC AltaEscritor 'AUT0000017','Thomas Mann','1875-06-06','1955-08-12','DEU'
EXEC AltaEscritor 'AUT0000018','Hermann Hesse','1877-07-02','1962-08-09','DEU'
EXEC AltaEscritor 'AUT0000019','Franz Kafka','1883-07-03','1924-06-03','DEU'
EXEC AltaEscritor 'AUT0000020','Michael Ende','1929-11-12','1995-08-28','DEU'

EXEC AltaEscritor 'AUT0000021','William Shakespeare','1564-04-23','1616-04-23','GBR'
EXEC AltaEscritor 'AUT0000022','Charles Dickens','1812-02-07','1870-06-09','GBR'
EXEC AltaEscritor 'AUT0000023','Jane Austen','1775-12-16','1817-07-18','GBR'
EXEC AltaEscritor 'AUT0000024','George Orwell','1903-06-25','1950-01-21','GBR'
EXEC AltaEscritor 'AUT0000025','J K Rowling','1965-07-31',NULL,'GBR'

EXEC AltaEscritor 'AUT0000026','Jorge Borges','1899-08-24','1986-06-14','ARG'
EXEC AltaEscritor 'AUT0000027','Julio Cortazar','1914-08-26','1984-02-12','ARG'
EXEC AltaEscritor 'AUT0000028','Ernesto Sabato','1911-06-24','2011-04-30','ARG'
EXEC AltaEscritor 'AUT0000029','Adolfo Bioy','1914-09-15','1999-03-08','ARG'
EXEC AltaEscritor 'AUT0000030','Ricardo Piglia','1941-11-24','2017-01-06','ARG'

EXEC AltaEscritor 'AUT0000031','Mario Benedetti','1920-09-14','2009-05-17','URY'
EXEC AltaEscritor 'AUT0000032','Juan Onetti','1909-07-01','1994-05-30','URY'
EXEC AltaEscritor 'AUT0000033','Eduardo Galeano','1940-09-03','2015-04-13','URY'
EXEC AltaEscritor 'AUT0000034','Horacio Quiroga','1878-12-31','1937-02-19','URY'
EXEC AltaEscritor 'AUT0000035','Ida Vitale','1923-11-02',NULL,'URY'

EXEC AltaEscritor 'AUT0000036','Paulo Coelho','1947-08-24',NULL,'BRA'
EXEC AltaEscritor 'AUT0000037','Machado Assis','1839-06-21','1908-09-29','BRA'
EXEC AltaEscritor 'AUT0000038','Jorge Amado','1912-08-10','2001-08-06','BRA'
EXEC AltaEscritor 'AUT0000039','Clarice Lispector','1920-12-10','1977-12-09','BRA'
EXEC AltaEscritor 'AUT0000040','Rubem Fonseca','1925-05-11','2020-04-15','BRA'

EXEC AltaEscritor 'AUT0000041','Pablo Neruda','1904-07-12','1973-09-23','CHL'
EXEC AltaEscritor 'AUT0000042','Isabel Allende','1942-08-02',NULL,'CHL'
EXEC AltaEscritor 'AUT0000043','Roberto Bolano','1953-04-28','2003-07-15','CHL'
EXEC AltaEscritor 'AUT0000044','Gabriela Mistral','1889-04-07','1957-01-10','CHL'
EXEC AltaEscritor 'AUT0000045','Nicanor Parra','1914-09-05','2018-01-23','CHL'

EXEC AltaEscritor 'AUT0000046','Haruki Murakami','1949-01-12',NULL,'JPN'
EXEC AltaEscritor 'AUT0000047','Yasunari Kawabata','1899-06-14','1972-04-16','JPN'
EXEC AltaEscritor 'AUT0000048','Yukio Mishima','1925-01-14','1970-11-25','JPN'
EXEC AltaEscritor 'AUT0000049','Kenzaburo Oe','1935-01-31','2023-03-03','JPN'
EXEC AltaEscritor 'AUT0000050','Banana Yoshimoto','1964-07-24',NULL,'JPN'
go

-- Editoriales - 30 datos
EXEC AltaProveedoresLibros 'Planeta','Av Siempre Viva 123','planeta01','Planeta1!','ESP'
EXEC AltaProveedoresLibros 'Alfaguara','Calle Mayor 45','alfaguara01','Alfaguar1!','ESP'
EXEC AltaProveedoresLibros 'Anagrama','Rambla Central 88','anagrama01','Anagram1!','ESP'
EXEC AltaProveedoresLibros 'Santillana','Av Libertad 1020','santilla01','Santilla1!','ESP'
EXEC AltaProveedoresLibros 'Tusquets','Calle Norte 221','tusquets01','Tusquets1!','ESP'

EXEC AltaProveedoresLibros 'Gallimard','Rue de Paris 10','gallimar01','Gallimar1!','FRA'
EXEC AltaProveedoresLibros 'Hachette','Rue Victor Hugo 50','hachette01','Hachett1!','FRA'
EXEC AltaProveedoresLibros 'Flammarion','Rue Rivoli 75','flammar01','Flammar1!','FRA'

EXEC AltaProveedoresLibros 'Mondadori','Via Roma 15','mondado01','Mondado1!','ITA'
EXEC AltaProveedoresLibros 'Einaudi','Via Torino 42','einaudi01','Einaudi1!','ITA'
EXEC AltaProveedoresLibros 'Feltrinelli','Via Milano 60','feltrin01','Feltrin1!','ITA'

EXEC AltaProveedoresLibros 'Penguin Books','Strand 80','penguin01','Penguin1!','GBR'
EXEC AltaProveedoresLibros 'HarperCollins','London Bridge 12','harper01','Harper1!','GBR'
EXEC AltaProveedoresLibros 'Oxford Press','High Street 90','oxford01','Oxford1!','GBR'

EXEC AltaProveedoresLibros 'Sudamericana','Av Corrientes 1500','sudamer01','Sudamer1!','ARG'
EXEC AltaProveedoresLibros 'Emece','Calle Florida 200','emece001','Emece001!','ARG'
EXEC AltaProveedoresLibros 'Losada','Av Santa Fe 730','losada01','Losada01!','ARG'

EXEC AltaProveedoresLibros 'Banda Oriental','18 de Julio 1222','bandaor01','Bandaor1!','URY'
EXEC AltaProveedoresLibros 'Fin de Siglo','Colonia 985','findesig01','Findes1!','URY'
EXEC AltaProveedoresLibros 'Criatura','Canelones 1540','criatura01','Criatur1!','URY'

EXEC AltaProveedoresLibros 'Companhia Letras','Rua Augusta 100','companhi01','Companh1!','BRA'
EXEC AltaProveedoresLibros 'Record','Rua do Ouvidor 45','record01','Record01!','BRA'
EXEC AltaProveedoresLibros 'Rocco','Av Atlantica 220','rocco001','Rocco001!','BRA'

EXEC AltaProveedoresLibros 'Zig Zag','Av Providencia 300','zigzag01','Zigzag01!','CHL'
EXEC AltaProveedoresLibros 'Planeta Chile','Calle Apoquindo 450','planchil01','Planchil1!','CHL'
EXEC AltaProveedoresLibros 'LOM','Av Italia 850','lomedit01','Lomedit1!','CHL'

EXEC AltaProveedoresLibros 'Kodansha','Chiyoda 2-1','kodansha01','Kodansha1!','JPN'
EXEC AltaProveedoresLibros 'Shueisha','Tokyo Central 33','shueisha01','Shueish1!','JPN'
EXEC AltaProveedoresLibros 'Shogakukan','Kanda 45','shogaku01','Shogaku1!','JPN'

EXEC AltaProveedoresLibros 'Oxford India','Delhi Road 55','oxfindia01','Oxfindia1!','IND'
go

-- Librerias - 30 datos
EXEC AltaClientesComerciales '100000000001','Libreria Central','libcent01','Libcent1!'
EXEC AltaClientesComerciales '100000000002','Letras del Sur','letrsur01','Letrsur1!'
EXEC AltaClientesComerciales '100000000003','El Ateneo','ateneo01','Ateneo01!'
EXEC AltaClientesComerciales '100000000004','Libros y Mas','libymas01','Libymas1!'
EXEC AltaClientesComerciales '100000000005','Pagina Uno','pagina01','Pagina01!'

EXEC AltaClientesComerciales '100000000006','Mundo Libro','mundlib01','Mundlib1!'
EXEC AltaClientesComerciales '100000000007','Lectura Viva','lectviv01','Lectviv1!'
EXEC AltaClientesComerciales '100000000008','Book Center','bookcen01','Bookcen1!'
EXEC AltaClientesComerciales '100000000009','Punto Lectura','puntlec01','Puntlec1!'
EXEC AltaClientesComerciales '100000000010','Libreria Norte','libnort01','Libnort1!'

EXEC AltaClientesComerciales '100000000011','Libreria Sur','libsur01','Libsur01!'
EXEC AltaClientesComerciales '100000000012','Casa del Libro','casalib01','Casalib1!'
EXEC AltaClientesComerciales '100000000013','Lector Feliz','lectfel01','Lectfel1!'
EXEC AltaClientesComerciales '100000000014','Libreria Oeste','liboest01','Liboest1!'
EXEC AltaClientesComerciales '100000000015','Libreria Este','libeste01','Libeste1!'

EXEC AltaClientesComerciales '100000000016','Biblioteca XXI','bibli021','Bibli021!'
EXEC AltaClientesComerciales '100000000017','Universo Libros','unilib01','Unilib01!'
EXEC AltaClientesComerciales '100000000018','Lectores Unidos','lecuni01','Lecuni01!'
EXEC AltaClientesComerciales '100000000019','La Estanteria','estante01','Estante1!'
EXEC AltaClientesComerciales '100000000020','Rincon Literario','rincon01','Rincon01!'

EXEC AltaClientesComerciales '100000000021','Libro Abierto','libabie01','Libabie1!'
EXEC AltaClientesComerciales '100000000022','Lectura Total','lecttot01','Lecttot1!'
EXEC AltaClientesComerciales '100000000023','Ciudad Libro','ciudad01','Ciudad01!'
EXEC AltaClientesComerciales '100000000024','Portal Libros','portal01','Portal01!'
EXEC AltaClientesComerciales '100000000025','Bibliomania','biblio01','Biblio01!'

EXEC AltaClientesComerciales '100000000026','Libreria Delta','delta001','Delta001!'
EXEC AltaClientesComerciales '100000000027','Libreria Sigma','sigma001','Sigma001!'
EXEC AltaClientesComerciales '100000000028','Libreria Alfa','alfa0001','Alfa0001!'
EXEC AltaClientesComerciales '100000000029','Libreria Beta','beta0001','Beta0001!'
EXEC AltaClientesComerciales '100000000030','Libreria Gamma','gamma001','Gamma001!'
go

-- Libros - 100 datos
EXEC AltaCatalogo '9780000000001','Don Quijote','Novela','Clasico de la literatura española',20,'AUT0000001','Planeta'
EXEC AltaCatalogo '9780000000002','La Galatea','Novela','Obra pastoril de Cervantes',15,'AUT0000001','Alfaguara'
EXEC AltaCatalogo '9780000000003','Fuenteovejuna','Teatro','Drama clasico español',18,'AUT0000002','Anagrama'
EXEC AltaCatalogo '9780000000004','Fortunata y Jacinta','Novela','Novela realista española',12,'AUT0000003','Santillana'
EXEC AltaCatalogo '9780000000005','Bodas de Sangre','Teatro','Tragedia poetica española',25,'AUT0000004','Tusquets'

EXEC AltaCatalogo '9780000000006','Los Miserables','Novela','Novela historica francesa',30,'AUT0000006','Gallimard'
EXEC AltaCatalogo '9780000000007','Nuestra Señora Paris','Novela','Clasico de Victor Hugo',14,'AUT0000006','Hachette'
EXEC AltaCatalogo '9780000000008','Viaje al Centro','Aventura','Novela de aventuras',22,'AUT0000007','Flammarion'
EXEC AltaCatalogo '9780000000009','La Isla Misteriosa','Aventura','Aventura cientifica',16,'AUT0000007','Gallimard'
EXEC AltaCatalogo '9780000000010','Los Tres Mosqueteros','Aventura','Novela de capa y espada',28,'AUT0000008','Hachette'

EXEC AltaCatalogo '9780000000011','El Extranjero','Novela','Novela filosofica breve',20,'AUT0000009','Flammarion'
EXEC AltaCatalogo '9780000000012','La Peste','Novela','Historia sobre una epidemia',18,'AUT0000009','Gallimard'
EXEC AltaCatalogo '9780000000013','En Busca Tiempo','Novela','Obra clasica francesa',10,'AUT0000010','Hachette'
EXEC AltaCatalogo '9780000000014','Divina Comedia','Poesia','Poema clasico italiano',30,'AUT0000011','Mondadori'
EXEC AltaCatalogo '9780000000015','El Nombre Rosa','Misterio','Novela historica y policial',22,'AUT0000012','Einaudi'

EXEC AltaCatalogo '9780000000016','Baudolino','Novela','Novela historica italiana',11,'AUT0000012','Feltrinelli'
EXEC AltaCatalogo '9780000000017','Ciudades Invisibles','Ficcion','Relatos breves fantasticos',17,'AUT0000013','Mondadori'
EXEC AltaCatalogo '9780000000018','El Baron Rampante','Ficcion','Novela de Italo Calvino',13,'AUT0000013','Einaudi'
EXEC AltaCatalogo '9780000000019','La Romana','Novela','Novela italiana moderna',9,'AUT0000014','Feltrinelli'
EXEC AltaCatalogo '9780000000020','La Amiga Genial','Novela','Historia de amistad',25,'AUT0000015','Mondadori'

EXEC AltaCatalogo '9780000000021','Fausto','Teatro','Obra clasica alemana',18,'AUT0000016','Penguin Books'
EXEC AltaCatalogo '9780000000022','Los Buddenbrook','Novela','Novela familiar alemana',12,'AUT0000017','HarperCollins'
EXEC AltaCatalogo '9780000000023','La Montaña Magica','Novela','Novela filosofica alemana',10,'AUT0000017','Oxford Press'
EXEC AltaCatalogo '9780000000024','Siddhartha','Novela','Busqueda espiritual',26,'AUT0000018','Penguin Books'
EXEC AltaCatalogo '9780000000025','El Lobo Estepario','Novela','Novela existencial',15,'AUT0000018','HarperCollins'

EXEC AltaCatalogo '9780000000026','La Metamorfosis','Novela','Relato de transformacion',30,'AUT0000019','Oxford Press'
EXEC AltaCatalogo '9780000000027','El Proceso','Novela','Novela sobre justicia',18,'AUT0000019','Penguin Books'
EXEC AltaCatalogo '9780000000028','Historia Interminable','Fantasia','Fantasia juvenil',24,'AUT0000020','HarperCollins'
EXEC AltaCatalogo '9780000000029','Hamlet','Teatro','Tragedia clasica inglesa',27,'AUT0000021','Oxford Press'
EXEC AltaCatalogo '9780000000030','Romeo y Julieta','Teatro','Tragedia romantica',25,'AUT0000021','Penguin Books'

EXEC AltaCatalogo '9780000000031','Oliver Twist','Novela','Novela social inglesa',20,'AUT0000022','HarperCollins'
EXEC AltaCatalogo '9780000000032','Grandes Esperanzas','Novela','Clasico de Dickens',16,'AUT0000022','Oxford Press'
EXEC AltaCatalogo '9780000000033','Orgullo y Prejuicio','Romance','Novela romantica inglesa',30,'AUT0000023','Penguin Books'
EXEC AltaCatalogo '9780000000034','Emma','Romance','Novela de Jane Austen',21,'AUT0000023','HarperCollins'
EXEC AltaCatalogo '9780000000035','1984','Distopia','Novela distopica politica',35,'AUT0000024','Oxford Press'

EXEC AltaCatalogo '9780000000036','Rebelion Granja','Distopia','Fabula politica',28,'AUT0000024','Penguin Books'
EXEC AltaCatalogo '9780000000037','Harry Potter 1','Fantasia','Inicio de saga fantastica',40,'AUT0000025','HarperCollins'
EXEC AltaCatalogo '9780000000038','Harry Potter 2','Fantasia','Segunda parte de la saga',35,'AUT0000025','Oxford Press'
EXEC AltaCatalogo '9780000000039','Ficciones','Cuentos','Cuentos clasicos argentinos',23,'AUT0000026','Sudamericana'
EXEC AltaCatalogo '9780000000040','El Aleph','Cuentos','Relatos de Borges',25,'AUT0000026','Emece'

EXEC AltaCatalogo '9780000000041','Rayuela','Novela','Novela experimental argentina',30,'AUT0000027','Losada'
EXEC AltaCatalogo '9780000000042','Bestiario','Cuentos','Cuentos de Cortazar',14,'AUT0000027','Sudamericana'
EXEC AltaCatalogo '9780000000043','El Tunel','Novela','Novela psicologica',24,'AUT0000028','Emece'
EXEC AltaCatalogo '9780000000044','Sobre Heroes','Novela','Novela argentina extensa',12,'AUT0000028','Losada'
EXEC AltaCatalogo '9780000000045','Invencion Morel','Ficcion','Novela fantastica breve',18,'AUT0000029','Sudamericana'

EXEC AltaCatalogo '9780000000046','Plata Quemada','Policial','Novela policial argentina',16,'AUT0000030','Emece'
EXEC AltaCatalogo '9780000000047','Respiracion Artificial','Novela','Novela intelectual',13,'AUT0000030','Losada'
EXEC AltaCatalogo '9780000000048','La Tregua','Novela','Novela uruguaya clasica',32,'AUT0000031','Banda Oriental'
EXEC AltaCatalogo '9780000000049','Gracias por el Fuego','Novela','Novela de Benedetti',19,'AUT0000031','Fin de Siglo'
EXEC AltaCatalogo '9780000000050','El Astillero','Novela','Novela de Onetti',15,'AUT0000032','Criatura'

EXEC AltaCatalogo '9780000000051','Juntacadaveres','Novela','Obra de Juan Onetti',10,'AUT0000032','Banda Oriental'
EXEC AltaCatalogo '9780000000052','Venas Abiertas','Ensayo','Ensayo historico latinoamericano',27,'AUT0000033','Fin de Siglo'
EXEC AltaCatalogo '9780000000053','Memoria del Fuego','Ensayo','Relato historico americano',20,'AUT0000033','Criatura'
EXEC AltaCatalogo '9780000000054','Cuentos de Amor','Cuentos','Cuentos de Quiroga',31,'AUT0000034','Banda Oriental'
EXEC AltaCatalogo '9780000000055','Anaconda','Cuentos','Relatos de la selva',17,'AUT0000034','Fin de Siglo'

EXEC AltaCatalogo '9780000000056','Procura Imposible','Poesia','Poesia de Ida Vitale',11,'AUT0000035','Criatura'
EXEC AltaCatalogo '9780000000057','El Alquimista','Novela','Novela espiritual',40,'AUT0000036','Companhia Letras'
EXEC AltaCatalogo '9780000000058','Brida','Novela','Novela de Paulo Coelho',22,'AUT0000036','Record'
EXEC AltaCatalogo '9780000000059','Memorias Postumas','Novela','Clasico brasileño',18,'AUT0000037','Rocco'
EXEC AltaCatalogo '9780000000060','Dom Casmurro','Novela','Novela realista brasileña',25,'AUT0000037','Companhia Letras'

EXEC AltaCatalogo '9780000000061','Gabriela Clavo','Novela','Novela brasileña',20,'AUT0000038','Record'
EXEC AltaCatalogo '9780000000062','Capitanes Arena','Novela','Novela social brasileña',16,'AUT0000038','Rocco'
EXEC AltaCatalogo '9780000000063','La Hora Estrella','Novela','Novela de Lispector',19,'AUT0000039','Companhia Letras'
EXEC AltaCatalogo '9780000000064','Agua Viva','Novela','Prosa poetica brasileña',13,'AUT0000039','Record'
EXEC AltaCatalogo '9780000000065','Agosto','Policial','Novela policial brasileña',14,'AUT0000040','Rocco'

EXEC AltaCatalogo '9780000000066','Veinte Poemas','Poesia','Poesia amorosa chilena',33,'AUT0000041','Zig Zag'
EXEC AltaCatalogo '9780000000067','Canto General','Poesia','Poesia historica chilena',15,'AUT0000041','Planeta Chile'
EXEC AltaCatalogo '9780000000068','Casa Espiritus','Novela','Novela familiar chilena',28,'AUT0000042','LOM'
EXEC AltaCatalogo '9780000000069','Eva Luna','Novela','Novela de Isabel Allende',21,'AUT0000042','Zig Zag'
EXEC AltaCatalogo '9780000000070','Los Detectives','Novela','Novela latinoamericana',18,'AUT0000043','Planeta Chile'

EXEC AltaCatalogo '9780000000071','2666','Novela','Novela extensa de Bolano',16,'AUT0000043','LOM'
EXEC AltaCatalogo '9780000000072','Desolacion','Poesia','Poesia de Mistral',14,'AUT0000044','Zig Zag'
EXEC AltaCatalogo '9780000000073','Tala','Poesia','Obra poetica chilena',12,'AUT0000044','Planeta Chile'
EXEC AltaCatalogo '9780000000074','Poemas Antipoemas','Poesia','Antipoesia chilena',20,'AUT0000045','LOM'
EXEC AltaCatalogo '9780000000075','Tokio Blues','Novela','Novela japonesa moderna',30,'AUT0000046','Kodansha'

EXEC AltaCatalogo '9780000000076','Kafka en la Orilla','Novela','Novela surreal japonesa',24,'AUT0000046','Shueisha'
EXEC AltaCatalogo '9780000000077','Pais Nieve','Novela','Clasico japones',17,'AUT0000047','Shogakukan'
EXEC AltaCatalogo '9780000000078','Mil Grullas','Novela','Novela de Kawabata',15,'AUT0000047','Kodansha'
EXEC AltaCatalogo '9780000000079','Confesiones Mascara','Novela','Novela de Mishima',12,'AUT0000048','Shueisha'
EXEC AltaCatalogo '9780000000080','Pabellon de Oro','Novela','Novela japonesa clasica',14,'AUT0000048','Shogakukan'

EXEC AltaCatalogo '9780000000081','Una Cuestion Personal','Novela','Novela japonesa moderna',16,'AUT0000049','Kodansha'
EXEC AltaCatalogo '9780000000082','Arrancad Semillas','Novela','Novela de Kenzaburo Oe',10,'AUT0000049','Shueisha'
EXEC AltaCatalogo '9780000000083','Kitchen','Novela','Novela japonesa breve',22,'AUT0000050','Shogakukan'
EXEC AltaCatalogo '9780000000084','Amrita','Novela','Novela de Yoshimoto',13,'AUT0000050','Kodansha'
EXEC AltaCatalogo '9780000000085','La Tabla Flandes','Misterio','Novela de misterio española',19,'AUT0000005','Planeta'

EXEC AltaCatalogo '9780000000086','Capitan Alatriste','Aventura','Aventura historica española',27,'AUT0000005','Alfaguara'
EXEC AltaCatalogo '9780000000087','Trafalgar','Novela','Episodio nacional español',18,'AUT0000003','Anagrama'
EXEC AltaCatalogo '9780000000088','Yerma','Teatro','Drama rural español',17,'AUT0000004','Santillana'
EXEC AltaCatalogo '9780000000089','Novelas Ejemplares','Novela','Coleccion de relatos',21,'AUT0000001','Tusquets'
EXEC AltaCatalogo '9780000000090','Conde Montecristo','Aventura','Aventura historica francesa',26,'AUT0000008','Gallimard'

EXEC AltaCatalogo '9780000000091','La Reina Margot','Novela','Novela historica francesa',13,'AUT0000008','Hachette'
EXEC AltaCatalogo '9780000000092','Caligula','Teatro','Obra teatral de Camus',11,'AUT0000009','Flammarion'
EXEC AltaCatalogo '9780000000093','Numero Cero','Novela','Novela de Umberto Eco',12,'AUT0000012','Einaudi'
EXEC AltaCatalogo '9780000000094','Si una Noche Invierno','Novela','Novela experimental italiana',14,'AUT0000013','Feltrinelli'
EXEC AltaCatalogo '9780000000095','Sentido Sensibilidad','Romance','Novela clasica inglesa',19,'AUT0000023','Penguin Books'

EXEC AltaCatalogo '9780000000096','David Copperfield','Novela','Clasico de Dickens',16,'AUT0000022','HarperCollins'
EXEC AltaCatalogo '9780000000097','Hacedor','Poesia','Obra breve de Borges',15,'AUT0000026','Emece'
EXEC AltaCatalogo '9780000000098','Final del Juego','Cuentos','Cuentos de Cortazar',18,'AUT0000027','Losada'
EXEC AltaCatalogo '9780000000099','Primavera Esquina','Novela','Novela de Benedetti',20,'AUT0000031','Banda Oriental'
EXEC AltaCatalogo '9780000000100','De Amor y Sombra','Novela','Novela de Isabel Allende',23,'AUT0000042','Planeta Chile'
go

-- Solicitudes - 100 datos
INSERT Solicitud(FechaEntrega, RUT) VALUES 
('2026-12-01 10:00:00','100000000001'),
('2026-12-02 10:00:00','100000000002'),
('2026-12-03 10:00:00','100000000003'),
('2026-12-04 10:00:00','100000000004'),
('2026-12-05 10:00:00','100000000005'),
('2026-12-06 10:00:00','100000000006'),
('2026-12-07 10:00:00','100000000007'),
('2026-12-08 10:00:00','100000000008'),
('2026-12-09 10:00:00','100000000009'),
('2026-12-10 10:00:00','100000000010'),
('2026-12-11 10:00:00','100000000011'),
('2026-12-12 10:00:00','100000000012'),
('2026-12-13 10:00:00','100000000013'),
('2026-12-14 10:00:00','100000000014'),
('2026-12-15 10:00:00','100000000015'),
('2026-12-16 10:00:00','100000000016'),
('2026-12-17 10:00:00','100000000017'),
('2026-12-18 10:00:00','100000000018'),
('2026-12-19 10:00:00','100000000019'),
('2026-12-20 10:00:00','100000000020'),
('2026-12-21 10:00:00','100000000021'),
('2026-12-22 10:00:00','100000000022'),
('2026-12-23 10:00:00','100000000023'),
('2026-12-24 10:00:00','100000000024'),
('2026-12-25 10:00:00','100000000025'),
('2026-12-26 10:00:00','100000000026'),
('2026-12-27 10:00:00','100000000027'),
('2026-12-28 10:00:00','100000000028'),
('2026-12-29 10:00:00','100000000029'),
('2026-12-30 10:00:00','100000000030'),
('2027-01-01 10:00:00','100000000001'),
('2027-01-02 10:00:00','100000000002'),
('2027-01-03 10:00:00','100000000003'),
('2027-01-04 10:00:00','100000000004'),
('2027-01-05 10:00:00','100000000005'),
('2027-01-06 10:00:00','100000000006'),
('2027-01-07 10:00:00','100000000007'),
('2027-01-08 10:00:00','100000000008'),
('2027-01-09 10:00:00','100000000009'),
('2027-01-10 10:00:00','100000000010'),
('2027-01-11 10:00:00','100000000011'),
('2027-01-12 10:00:00','100000000012'),
('2027-01-13 10:00:00','100000000013'),
('2027-01-14 10:00:00','100000000014'),
('2027-01-15 10:00:00','100000000015'),
('2027-01-16 10:00:00','100000000016'),
('2027-01-17 10:00:00','100000000017'),
('2027-01-18 10:00:00','100000000018'),
('2027-01-19 10:00:00','100000000019'),
('2027-01-20 10:00:00','100000000020'),
('2027-01-21 10:00:00','100000000021'),
('2027-01-22 10:00:00','100000000022'),
('2027-01-23 10:00:00','100000000023'),
('2027-01-24 10:00:00','100000000024'),
('2027-01-25 10:00:00','100000000025'),
('2027-01-26 10:00:00','100000000026'),
('2027-01-27 10:00:00','100000000027'),
('2027-01-28 10:00:00','100000000028'),
('2027-01-29 10:00:00','100000000029'),
('2027-01-30 10:00:00','100000000030'),
('2027-02-01 10:00:00','100000000001'),
('2027-02-02 10:00:00','100000000002'),
('2027-02-03 10:00:00','100000000003'),
('2027-02-04 10:00:00','100000000004'),
('2027-02-05 10:00:00','100000000005'),
('2027-02-06 10:00:00','100000000006'),
('2027-02-07 10:00:00','100000000007'),
('2027-02-08 10:00:00','100000000008'),
('2027-02-09 10:00:00','100000000009'),
('2027-02-10 10:00:00','100000000010'),
('2027-02-11 10:00:00','100000000011'),
('2027-02-12 10:00:00','100000000012'),
('2027-02-13 10:00:00','100000000013'),
('2027-02-14 10:00:00','100000000014'),
('2027-02-15 10:00:00','100000000015'),
('2027-02-16 10:00:00','100000000016'),
('2027-02-17 10:00:00','100000000017'),
('2027-02-18 10:00:00','100000000018'),
('2027-02-19 10:00:00','100000000019'),
('2027-02-20 10:00:00','100000000020'),
('2027-02-21 10:00:00','100000000021'),
('2027-02-22 10:00:00','100000000022'),
('2027-02-23 10:00:00','100000000023'),
('2027-02-24 10:00:00','100000000024'),
('2027-02-25 10:00:00','100000000025'),
('2027-02-26 10:00:00','100000000026'),
('2027-02-27 10:00:00','100000000027'),
('2027-02-28 10:00:00','100000000028'),
('2027-03-01 10:00:00','100000000029'),
('2027-03-02 10:00:00','100000000030'),
('2027-03-03 10:00:00','100000000001'),
('2027-03-04 10:00:00','100000000002'),
('2027-03-05 10:00:00','100000000003'),
('2027-03-06 10:00:00','100000000004'),
('2027-03-07 10:00:00','100000000005'),
('2027-03-08 10:00:00','100000000006'),
('2027-03-09 10:00:00','100000000007'),
('2027-03-10 10:00:00','100000000008'),
('2027-03-11 10:00:00','100000000009'),
('2027-03-12 10:00:00','100000000010')
go

-- Incluye, las solicitudes del 1 a 50 tienen 2 libros. Las de 51 a 100 tienen 1 libro
INSERT Incluye VALUES
(1,'9780000000001',2),(1,'9780000000002',1),
(2,'9780000000003',3),(2,'9780000000004',1),
(3,'9780000000005',2),(3,'9780000000006',1),
(4,'9780000000007',1),(4,'9780000000008',2),
(5,'9780000000009',3),(5,'9780000000010',1),
(6,'9780000000011',2),(6,'9780000000012',1),
(7,'9780000000013',1),(7,'9780000000014',2),
(8,'9780000000015',3),(8,'9780000000016',1),
(9,'9780000000017',2),(9,'9780000000018',2),
(10,'9780000000019',1),(10,'9780000000020',3),
(11,'9780000000021',2),(11,'9780000000022',1),
(12,'9780000000023',3),(12,'9780000000024',1),
(13,'9780000000025',2),(13,'9780000000026',1),
(14,'9780000000027',1),(14,'9780000000028',2),
(15,'9780000000029',3),(15,'9780000000030',1),
(16,'9780000000031',2),(16,'9780000000032',1),
(17,'9780000000033',1),(17,'9780000000034',2),
(18,'9780000000035',3),(18,'9780000000036',1),
(19,'9780000000037',2),(19,'9780000000038',1),
(20,'9780000000039',1),(20,'9780000000040',2),
(21,'9780000000041',3),(21,'9780000000042',1),
(22,'9780000000043',2),(22,'9780000000044',1),
(23,'9780000000045',1),(23,'9780000000046',2),
(24,'9780000000047',3),(24,'9780000000048',1),
(25,'9780000000049',2),(25,'9780000000050',1),
(26,'9780000000051',1),(26,'9780000000052',2),
(27,'9780000000053',3),(27,'9780000000054',1),
(28,'9780000000055',2),(28,'9780000000056',1),
(29,'9780000000057',1),(29,'9780000000058',2),
(30,'9780000000059',3),(30,'9780000000060',1),
(31,'9780000000061',2),(31,'9780000000062',1),
(32,'9780000000063',1),(32,'9780000000064',2),
(33,'9780000000065',3),(33,'9780000000066',1),
(34,'9780000000067',2),(34,'9780000000068',1),
(35,'9780000000069',1),(35,'9780000000070',2),
(36,'9780000000071',3),(36,'9780000000072',1),
(37,'9780000000073',2),(37,'9780000000074',1),
(38,'9780000000075',1),(38,'9780000000076',2),
(39,'9780000000077',3),(39,'9780000000078',1),
(40,'9780000000079',2),(40,'9780000000080',1),
(41,'9780000000081',1),(41,'9780000000082',2),
(42,'9780000000083',3),(42,'9780000000084',1),
(43,'9780000000085',2),(43,'9780000000086',1),
(44,'9780000000087',1),(44,'9780000000088',2),
(45,'9780000000089',3),(45,'9780000000090',1),
(46,'9780000000091',2),(46,'9780000000092',1),
(47,'9780000000093',1),(47,'9780000000094',2),
(48,'9780000000095',3),(48,'9780000000096',1),
(49,'9780000000097',2),(49,'9780000000098',1),
(50,'9780000000099',1),(50,'9780000000100',2),

(51,'9780000000001',1),
(52,'9780000000002',2),
(53,'9780000000003',1),
(54,'9780000000004',2),
(55,'9780000000005',1),
(56,'9780000000006',2),
(57,'9780000000007',1),
(58,'9780000000008',2),
(59,'9780000000009',1),
(60,'9780000000010',2),
(61,'9780000000011',1),
(62,'9780000000012',2),
(63,'9780000000013',1),
(64,'9780000000014',2),
(65,'9780000000015',1),
(66,'9780000000016',2),
(67,'9780000000017',1),
(68,'9780000000018',2),
(69,'9780000000019',1),
(70,'9780000000020',2),
(71,'9780000000021',1),
(72,'9780000000022',2),
(73,'9780000000023',1),
(74,'9780000000024',2),
(75,'9780000000025',1),
(76,'9780000000026',2),
(77,'9780000000027',1),
(78,'9780000000028',2),
(79,'9780000000029',1),
(80,'9780000000030',2),
(81,'9780000000031',1),
(82,'9780000000032',2),
(83,'9780000000033',1),
(84,'9780000000034',2),
(85,'9780000000035',1),
(86,'9780000000036',2),
(87,'9780000000037',1),
(88,'9780000000038',2),
(89,'9780000000039',1),
(90,'9780000000040',2),
(91,'9780000000041',1),
(92,'9780000000042',2),
(93,'9780000000043',1),
(94,'9780000000044',2),
(95,'9780000000045',1),
(96,'9780000000046',2),
(97,'9780000000047',1),
(98,'9780000000048',2),
(99,'9780000000049',1),
(100,'9780000000050',2)
go


------------------------- DATOS DE PRUEBA CON ERRORES -------------------------
-- Procedencia / Pais
INSERT INTO Procedencia VALUES(NULL,'Pais Error','AA') -- PK NULL
INSERT INTO Procedencia VALUES('A1B','Pais Error','AA') -- PK combinacion de numero y letras 
INSERT INTO Procedencia VALUES('ESP','España Repetida','EU') -- PK duplicada
INSERT INTO Procedencia VALUES('AAA','Pais Error','ZZ') -- Continente invalido
INSERT INTO Procedencia VALUES('BBB','Pais Error','A1') -- Continente invalido
go

-- Escritores / Autor
INSERT INTO Escritores VALUES(NULL,'Autor Error','1980-01-01',NULL,'ESP') -- PK NULL
INSERT INTO Escritores VALUES('1234567890','Autor Solo Numeros','1980-01-01',NULL,'ESP') -- PK solo numeros
INSERT INTO Escritores VALUES('ABCDEFGHIJ','Autor Solo Letras','1980-01-01',NULL,'ESP') -- PK solo letras
INSERT INTO Escritores VALUES('AUT0000001','Autor Repetido','1980-01-01',NULL,'ESP') -- PK duplicada
INSERT INTO Escritores VALUES('AUT0000099','Autor Pais Error','1980-01-01',NULL,'XXX') -- No existe el pais
INSERT INTO Escritores VALUES('AUT0000098','Autor Menor','2015-01-01',NULL,'ESP') -- Autor es menor de edad
INSERT INTO Escritores VALUES('AUT0000097','Autor Fechas','1990-01-01','1980-01-01','ESP') -- Fecha de fallecimiento invalida
go

-- ProveedoresLibros / Editorial
INSERT INTO ProveedoresLibros VALUES(NULL,'Dir Error','editor01','Clave123!','ESP') -- PK NULL
INSERT INTO ProveedoresLibros VALUES('Planeta','Dir Error','editor02','Clave123!','ESP') -- PK duplicada
INSERT INTO ProveedoresLibros VALUES('Editorial Error','Dir Error','editor03','Clave123!','XXX') -- Pais no existe
INSERT INTO ProveedoresLibros VALUES('Editorial Error','Dir Error','abc','Clave123!','ESP') -- usuario invalido
INSERT INTO ProveedoresLibros VALUES('Editorial Error','Dir Error','planeta01','Clave123!','ESP') -- usuario ya existe
INSERT INTO ProveedoresLibros VALUES('Editorial Error','Dir Error','editor04','12345678','ESP') -- contraseña incorrecta
go

-- ClientesComerciales / Libreria
INSERT INTO ClientesComerciales VALUES(NULL,'Libreria Error','usuario01','Clave123!') -- PK NULL
INSERT INTO ClientesComerciales VALUES('123','Libreria Error','usuario02','Clave123!') -- RUT invalido
INSERT INTO ClientesComerciales VALUES('ABCDEFGHIJKL','Libreria Error','usuario03','Clave123!') -- RUT con letras
INSERT INTO ClientesComerciales VALUES('100000000001','Libreria Repetida','usuario04','Clave123!') -- libreria ya existe
INSERT INTO ClientesComerciales VALUES('100000000031','Libreria Error','abc','Clave123!') -- usuario invalido
INSERT INTO ClientesComerciales VALUES('100000000032','Libreria Error','libcent01','Clave123!') -- usuario ya existe
go

-- Catalogo / Libros
INSERT INTO Catalogo VALUES('9780000000009',NULL,'Drama','Desc',10,'AUT0000001','Planeta') -- Nombre NULL
INSERT INTO Catalogo VALUES('123','Libro Error','Drama','Desc',10,'AUT0000001','Planeta') -- ISBN invalido
INSERT INTO Catalogo VALUES('9780000000001','Libro Repetido','Drama','Desc',10,'AUT0000001','Planeta') -- libro ya existe
INSERT INTO Catalogo VALUES('9789999999999','Libro Error','Drama','Desc',10,'XXX9999999','Planeta') -- el autor no existe
INSERT INTO Catalogo VALUES('9789999999998','Libro Error','Drama','Desc',10,'AUT0000001','EditorialX') -- la editorial no existe
INSERT INTO Catalogo VALUES('9789999999997','Libro Error','Drama','Desc',-5,'AUT0000001','Planeta') -- stock negativo
go