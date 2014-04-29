//1.6 se cambiaron los procedimientos de levantarbloque

unit Unidad;

interface

Uses
	sysUtils;

const
	LongBloque = 1024;

type
	tArchivoLibres = file of word;
	tNroBloque = word;							//tipo de numero de bloque
	tBloque = array [1 .. LongBloque] of byte;	//buffer bloque
	archivo = File;
	tEstado = (C, E, LE);						
	{ C = Cerrado; E = Escritura (append) no busca espacios libres;
	LE = lectura y escritura, con posicionamiento en bloques.		}

	tPersona = record
		nombre: string[20]; 				// Nombre y Apellido
		apellido: string[20];
		dni: longword;						//longword(4bytes) o string, elijan alguno.
	end;
	
	ctlPersonas = record
		estado: tEstado;
		arch: archivo;
		b: tBloque;
		ib: word;
		libres: tArchivoLibres;				//Archivo auxiliar con la cantidad de bytes libres por bloque
		libre: word;
		p: tPersona;
		pe: array[1..60] of byte;			//Si no es 52, cual sería más conveniente'
		lpe: byte;
	end;



procedure cargar (var ctrl: ctlPersonas);

procedure crear (var ctrl: ctlPersonas; nombre:string);

procedure abrir (var ctrl: ctlPersonas; modo: tEstado; nombre: String);

procedure cerrar (var ctrl: ctlPersonas);

procedure primero (var ctrl: ctlPersonas; var estado: boolean);				

procedure siguiente (var ctrl: ctlPersonas; var estado: boolean);

procedure recuperar (var ctrl: ctlPersonas; dni: longword; var estado: boolean);

procedure exportar (var ctrl: ctlPersonas; nomLogTXT : string);

procedure insertar (var ctrl: ctlPersonas; var estado: boolean);

procedure eliminar (var ctrl: ctlPersonas; var estado: boolean);

procedure modificar (var ctrl: ctlPersonas; var estado: boolean);

procedure respaldar (var ctrl: ctlPersonas; var estado: boolean);

Implementation


function libre (var ctrl: ctlPersonas): integer; 									//En lpe se envía el tamaño del registro empaquetado persona que se guardará en el archivo. La función retorna la posición del bloque con tamaño buscado.
var
	encontrado : boolean;
begin
	seek (ctrl.libres, 0);
	encontrado := false;
	while ((not encontrado) and (FilePos (ctrl.libres) < FileSize (ctrl.libres))) do begin
		read (ctrl.libres, ctrl.libre);
		encontrado := (ctrl.libre >= ctrl.lpe);
	end;
	if encontrado then
		libre := FilePos ((ctrl.libres)) -1							//Le retorno el número de bloque que contiene el espacio libre. Por eso retorno la posición, ya que son relacionales.
	else
		libre:= -1;													//Si no hallo libre retorno un valor absurdo.
end;


{
* PRE: el índice pasado como argumento es una posición de lectura
* válida.
}
procedure LeerPersona(var b: tBloque; var i: word; var p: tPersona);
  var
    longNombre: byte;
  begin
    //levanto el dni
    move(b[i+1], p.dni, sizeof(p.dni));
    inc(i, sizeof(p.dni) +1);
    
    //levanto el length del nombre
    move(b[i], longNombre, 1);
    
    //levanto el nombre (con el byte de longitud al comienzo)
    move(b[i], p.nombre, longNombre+1);
    inc(i, longNombre+1);
  end;
  
  
procedure LeerPersona1(var ctrl: ctlPersonas; var res: boolean);
var
	aux : word;
begin
	aux:= 1024 - (ctrl.libre) - (ctrl.ib+1);
	if ( aux > 0 ) then
	begin
		Move(ctrl.b[ctrl.ib+1], ctrl.p.nombre, SizeOf(ctrl.p.nombre)); 		//desde donde apunta IB, +1 para no incluir la longitud del string
		Inc(ctrl.ib, SizeOf(ctrl.p.nombre)+1); 									//me queda la duda si el SizeOf al string, tambien cuenta el bye de longitud
		Move(ctrl.b[ctrl.ib+1], ctrl.p.apellido, SizeOf(ctrl.p.apellido)); 	//pero por las dudas, lo escribo así.
		Inc(ctrl.ib, SizeOf(ctrl.p.nombre)+1);
		Move(ctrl.b[ctrl.ib], ctrl.p.dni, SizeOf(longword));
		Inc(ctrl.ib, SizeOf(longword));
		res := true;
	end
	else
	 	res := false;
end;  


procedure cargar (var ctrl: ctlPersonas);						//Carga en los bloques y cuando está lleno lo vuelco en el archivo???
var
	i: byte;
begin																		
	if ((ctrl.estado = E) or (ctrl.estado = LE)) then begin
		i:= 2;															//Inicializo el índice para recorrer el registro de empaquetamiento.
		move (ctrl.p.dni, ctrl.pe[i], SizeOf(ctrl.p.dni));				//Copio el dni en pe.
		i:= i + SizeOf(ctrl.p.dni);
		move (ctrl.p.nombre, ctrl.pe[i], (Length(ctrl.p.nombre)+1));		//Copio el nombre en pe e incluyo el prefijo del tamaño.
		i:= i + Length (ctrl.p.nombre)+1;									//Queda guardado la longitud del registro empaquetado.
		ctrl.lpe:= i -2;
		ctrl.pe[1] := ctrl.lpe;												//Guardo el prefijo de longitud del registro empaquetado. Resto dos porque lo inicialicé con ese valor (para manipular arreglo).
		//Guardo en el bloque buffer y actualizo su índice y la cantidad de espacio libre:
		if (ctrl.libre >= ctrl.lpe) then begin
			move (ctrl.pe[1], ctrl.b[ctrl.ib], ctrl.lpe +1 );
			ctrl.ib := ctrl.ib + i;
			ctrl.libre := ctrl.libre - (i - 1);
		end
		else begin																//En el caso de que no me alcance el tamaño libre debo crear otro bloque y volcar este.
			blockWrite (ctrl.arch, ctrl.b, 1);									//Guardo el bloque buffer y creo uno nuevo.
			write (ctrl.libres, ctrl.libre);
			
			ctrl.ib:=1;
			ctrl.libre:=LongBloque;
			move (ctrl.pe[1], ctrl.b[1], ctrl.lpe + 1);
			ctrl.ib := ctrl.ib + ctrl.lpe -1;													
			ctrl.libre := ctrl.libre - (ctrl.lpe + 1);
		end;
	end;
end;


procedure crear (var ctrl: ctlPersonas; nombre:string);
var
	b: tBloque;
	i: integer;
begin
	assign(ctrl.arch, nombre);
	assign(ctrl.libres, nombre + 'Libres');
	rewrite (ctrl.arch, LongBloque);
	rewrite (ctrl.libres);
	for i := 1 to LongBloque do
		b[i]:= 0;
	blockwrite (ctrl.arch, b,1);
	write (ctrl.libres, LongBloque);
	ctrl.estado := C; 														//Ver después que decide hacer con estado. Al crearlo ya queda abierto para escrituras. (O conviene cerrarlo y abrirlo luego?)
	ctrl.ib := 1;		
	close(ctrl.arch);
	close(ctrl.libres);													//Inicializo el índice del bloque buffer b para recorrerlo.
end;


procedure abrir (var ctrl: ctlPersonas; modo: tEstado; nombre: String);
begin
	if(modo <> C) then
	begin
		assign(ctrl.arch, nombre);
		assign(ctrl.libres, nombre + 'Libres');
		reset (ctrl.arch, LongBloque);										//Abro el archivo para lectura y le envío tamano de bloque.
		reset (ctrl.libres);
		ctrl.estado := modo;
		if (modo = E) then begin
			seek (ctrl.arch, FileSize (ctrl.arch)-1);							//Me posiciono en el último bloque del archivo y lo levanto a continuación.
			BlockRead (ctrl.arch, ctrl.b,1);									//Guardo el bloque del archivo en el bloque buffer.
			seek (ctrl.libres, FileSize (ctrl.libres)-1);						//Lo mismo para el archivo de libres.
			read (ctrl.libres, ctrl.libre);
			ctrl.ib := LongBloque - (ctrl.libre - 1);							//inicializo el puntero de b para escritura.
		end; 
	end;
end;


procedure cerrar (var ctrl: ctlPersonas);
begin
	if (ctrl.estado = E) or (ctrl.estado = LE) then begin					//Verifico el estado del archivo antes de cerrar del todo.
		seek (ctrl.libres,filepos(ctrl.libres)-1);
		seek (ctrl.arch,filepos (ctrl.arch)-1);
		blockwrite (ctrl.arch, ctrl.b, 1);								//Escribo el último bloque en el archivo.
		write (ctrl.libres, ctrl.libre);							 	//Escribo la cantidad de espacio libre en el archivo de espacios libres.
	end;
	ctrl.estado := C;
	close (ctrl.arch);
	close (ctrl.libres);
end;

{
* Busca secuencialmente en el archivo de espacios libres (a partir 
* de donde esté parado) un bloque que no se encuentre vacío 
* (espacios libre != longBloque)
}
function getPosSiguienteBloqueNoVacio (var a: tArchivoLibres): integer;
    var
        libresTemp: integer;
        result: integer;
    begin
        result:= -1;

        while ((not EOF(a)) and (result = -1)) do begin
            read(a, libresTemp);

            if (libresTemp <> longBloque) then
                result:= filePos(a) - 1;
        end;

        getPosSiguienteBloqueNoVacio:= result;
    end;

{
* Levanta el bloque y setea todos los datos adyacentes correspondientes.
* Recibe el puntero del archivo posicionado en el bloque que se quiere
* levantar.
}
procedure levantarBloque(var ctrl: ctlPersonas);

    begin
		//levanto el bloque
		blockRead(ctrl.arch, ctrl.b, 1);

		//leo espacios libres del bloque actual
		seek(ctrl.libres, filePos(ctrl.arch) - 1);
		read(ctrl.libres, ctrl.libre);
    end;

procedure levantarBloqueEscritura(var ctrl: ctlPersonas);
	begin
		levantarBloque(ctrl);
        //posiciono el índice acorde al estado del archivo
		ctrl.ib:= longBloque - ctrl.libre + 1;
	end;
	
procedure levantarBloqueLectura(var ctrl: ctlPersonas);
	begin
		levantarBloque(ctrl);
        //posiciono el índice acorde al estado del archivo
        ctrl.ib:= 1;
	end;
	
{
* PRE: archivo creado y abierto
* 
* POST: 
* · Deja en el bloque buffer el primer bloque en el que haya al menos un registro
* de persona (alberga la posibilidad de que haya bloques vacíos).
* · Deja el índice del bloque buffer posicionado en el primer byte del siguiente
* registro de persona.
* · Devuelve en el registro de persona del handler la persona leída.
* · result es 1 si la operación se concretó correctamente
*             0 si la operación no se concretó porque el archivo no contenía personas
}
procedure primero(var ctrl: ctlPersonas; var estado: boolean);
  var
    iBloqueValido: integer;
  begin	
	
    if (ctrl.estado = LE) then begin
      iBloqueValido:= getPosSiguienteBloqueNoVacio(ctrl.libres);
      
      if (iBloqueValido <> -1) then begin
        seek(ctrl.arch, iBloqueValido);
        levantarBloqueLectura(ctrl);

        leerPersona(ctrl.b, ctrl.ib, ctrl.p);
        
        estado:= true;
      end
      else
        estado:= false; //todos los bloques están vacíos
    end;
  end;


procedure siguiente (var ctrl: ctlPersonas; var estado: boolean);
var
    iBloqueValido : integer;
Begin
	
	if (longBloque - ctrl.libre + 1 > ctrl.ib) then begin
		leerPersona(ctrl.b, ctrl.ib, ctrl.p);
	end
	else begin
        iBloqueValido:= getPosSiguienteBloqueNoVacio(ctrl.libres);

        if (iBloqueValido <> -1) then begin
            seek(ctrl.arch, iBloqueValido);
            levantarBloqueLectura(ctrl);

            leerPersona(ctrl.b, ctrl.ib, ctrl.p);

            estado := true;
        end
		else
            estado := false;	//Sino, ya no habia más registro. No hay siguiente porque estaba al final.
    end;
End;


procedure empaquetar (var ctrl: ctlPersonas);
begin
	ctrl.lpe:= 2;
	move(ctrl.p.dni, ctrl.pe[ctrl.lpe], sizeof(ctrl.p.dni));
	inc(ctrl.lpe, sizeof(ctrl.p.dni));
	move(ctrl.p.nombre, ctrl.pe[ctrl.lpe], length(ctrl.p.nombre) + 1);
	inc(ctrl.lpe, length(ctrl.p.nombre) + 1);
	ctrl.pe[1]:= ctrl.lpe - 2;
	dec(ctrl.lpe, 1);
end;


{
	* Params
	* @arch ctlPersonas
	* @dni longword
	* @p TPersona
	* @estado integer
	* 
	* Recibe el registro de control con el archivo abierto
	* Devuelve un registro de la persona con el dni que busca
	* Devuelve el resultado de la operación.	
	* Queda apuntando IB al siguiente reg. del bloque }
procedure recuperar (var ctrl: ctlPersonas; dni: longword; var estado: boolean);
var
	encontrado : boolean;
	est:boolean;
Begin
	encontrado := false;
	primero(ctrl, est);
	if ( est ) then										
	begin
		while ((est) and (not encontrado)) do 		//mientras no encuentro la persona con el dni o no se termine el archivo
		begin
			if ( ctrl.p.dni <> dni) then begin				//busco dni
				siguiente(ctrl, est)					//si no lo encuentro, sigo con el proximo registro
			end else
			begin
				encontrado := true;
				empaquetar(ctrl);
			end;
		end;
		estado := encontrado;							//en el caso de haber recorrido todos los registros y no
	end 												// encontrarlo, devuelvo 0. No se encontraba el registro
	else
		estado := false;
end;

procedure exportar (var ctrl: ctlPersonas; nomLogTXT : string);
var
	F: text;
	estado: boolean;
Begin
	if (ctrl.estado = LE) then begin
		assign(F, nomLogTXT+'.txt');
		rewrite(F);
		primero(ctrl, estado);
		while ( estado ) do begin
			writeln(F, ctrl.p.nombre:20 ,' ', ctrl.p.dni );
			siguiente(ctrl, estado);
		end;
		close(F);
	end;
End;


procedure insertar (var ctrl: ctlPersonas; var estado: boolean);
var
	encontrado: boolean;
	nBloqueAInsertar: integer;
	p: tPersona;
Begin
	if ( ctrl.estado = LE) then begin
		p := ctrl.p;
		// verificacion unicidad
		recuperar(ctrl, ctrl.p.dni, encontrado); // Busco si existe en el archivo
		if ( not encontrado ) then begin
			
			ctrl.p := p;
			empaquetar(ctrl);
			
			nBloqueAInsertar := libre(ctrl);
			ctrl.ib:= longBloque - ctrl.libre + 1;
			
			if ( nBloqueAInsertar <> -1 ) then begin // inserto en el bloque
				seek(ctrl.arch, nBloqueAInsertar); // me posiciono en el bloque del archivo a escribir
				levantarBloqueEscritura(ctrl);
				move(ctrl.pe[1], ctrl.b[ctrl.ib], ctrl.lpe);
				inc(ctrl.ib, ctrl.lpe);
				dec(ctrl.libre, ctrl.lpe);
				seek(ctrl.libres, nBloqueAInsertar);
				write(ctrl.libres, ctrl.libre);
			end else begin // inserto al final
				cargar(ctrl);
			end;
		end;
	end;
End;


procedure eliminar (var ctrl: ctlPersonas; var estado: boolean);
var
   est: boolean;
   cant: longword;
Begin

    recuperar(ctrl,ctrl.p.dni,est);                                     // llamo a recup para buscar el registro, si no lo encuentro sale directamente
    
    if ( est ) then begin                                              // encontro la persona
		        
        //No cambien estas dos líneas, sé que es ilegible, pero funciona; cuando nos veamos les explicaré
        //cómo funciona (pero funciona).
        cant := LongBLoque - ctrl.libre  - (ctrl.ib - 1);
        move(ctrl.b[ctrl.ib], ctrl.b[ctrl.ib-ctrl.lpe], cant);   		// Mueve los registros que estaban despues del eliminado
                
        ctrl.libre := ctrl.libre + ctrl.lpe;
        
        seek(ctrl.arch,filepos(ctrl.arch)-1);	                      // se posiciona y vuelve a escribir en el bloque del archivo
        Blockwrite(ctrl.arch,ctrl.b,1);                                // el registro sin la persona para modificar
        seek(ctrl.libres,filepos(ctrl.libres)-1);                     // se posiciona y vuelve a escribir
        
        write(ctrl.libres,ctrl.libre);                                // en el archivo de espacios libres
        
        estado:=true;                                                    //retorna 1 si es verdadero
    end
    else
        estado:=false;                                                    // retorna 0 si es falso
End;


procedure modificar (var ctrl: ctlPersonas;  var estado: boolean);
var
   est: boolean;
   per:	tPersona;
Begin
	per.dni:=ctrl.p.dni;					// hacemos un
    per.nombre:=ctrl.p.nombre;				// backup de los datos

	eliminar(ctrl, est);
	if ( est ) then begin
		ctrl.ib := LongBloque - (ctrl.libre - 1);
		ctrl.p.dni := per.dni;
		ctrl.p.nombre := per.nombre;
		cargar(ctrl);						// Lo ponemos al final para tener una mejor eficiencia en la escritura
		estado := true;
	end else
		estado := false;
End;


procedure respaldar (var ctrl: ctlPersonas; var estado: boolean);
//var
	
Begin

End;

End.
