unit Unidad;

interface

Uses
	sysUtils;

const
	LongBloque = 1024;

type
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
		libres: File of word;				//Archivo auxiliar con la cantidad de bytes libres por bloque
		libre: word;
		p: tPersona;
		pe: array[1..60] of byte;			//Si no es 52, cual sería más conveniente'
		lpe: byte;
	end;



procedure cargar (var ctrl: ctlPersonas);

procedure crear (var ctrl: ctlPersonas; nombre:string);

procedure abrir (var ctrl: ctlPersonas);

procedure cerrar (var ctrl: ctlPersonas);

procedure primero (var ctrl: ctlPersonas; var estado: integer);				

procedure siguiente (var ctrl: ctlPersonas; var estado: integer);

procedure recuperar (var ctrl: ctlPersonas; dni: longword; var estado: integer);

procedure exportar (var ctrl: ctlPersonas; nomLogTXT : string);

procedure insertar (var ctrl: ctlPersonas; var estado: integer);

procedure eliminar (var ctrl: ctlPersonas; dni: longword; var estado: integer);

procedure modificar (var ctrl: ctlPersonas; dni: longword; var estado: integer);

procedure respaldar (var ctrl: ctlPersonas);

Implementation


function libre (var ctrl: ctlPersonas): tNroBloque; 									//En lpe se envía el tamaño del registro empaquetado persona que se guardará en el archivo. La función retorna la posición del bloque con tamaño buscado.
var
	encontrado : boolean;
begin
	seek (ctrl.libres, 0);
	encontrado := false;
	while ((not encontrado) and (FilePos (ctrl.libres) < FileSize (ctrl.libres))) do begin
		read (ctrl.libres, ctrl.libre);
		encontrado := (ctrl.libre < ctrl.lpe);
	end;
	if encontrado then
		libre := FilePos ((ctrl.libres) -1)							//Le retorno el número de bloque que contiene el espacio libre. Por eso retorno la posición, ya que son relacionales.
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
    move(b[i], p.dni, sizeof(p.dni));
    inc(i, sizeof(p.dni));
    
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


procedure cargar (var ctrl: ctlPersonas; p : tPersona);						//Carga en los bloques y cuando está lleno lo vuelco en el archivo???
begin																		//
	if (ctrl.estado = E) then begin
		ctrl.lpe :=2;															//Inicializo el índice para recorrer el registro de empaquetamiento.
		move (ctrl.p.dni, ctrl.pe[ctrl.lpe], SizeOf(ctrl.p.dni));				//Copio el dni en pe.
		ctrl.lpe:= ctrl.lpe + SizeOf(ctrl.p.dni);
		move (ctrl.p.nombre, ctrl.pe[ctrl.lpe], Length(ctrl.p.nombre)+1);		//Copio el nombre en pe e incluyo el prefijo del tamaño.
		ctrl.lpe:= ctrl.lpe + Length (ctrl.p.nombre);							//Queda guardado la longitud del registro empaquetado.
		ctrl.pe[1] := ctrl.lpe -2;												//Guardo el prefijo de longitud del registro empaquetado. Resto dos porque lo inicialicé con ese valor (para manipular arreglo).
		//Guardo en el bloque buffer y actualizo su índice y la cantidad de espacio libre:
		if (ctrl.libre > ctrl.lpe) then begin
			move (ctrl.pe[2], ctrl.b[ctrl.ib], ctrl.lpe-1);
			ctrl.ib := ctrl.ib + ctrl.lpe;
			ctrl.libre := ctrl.libre - ctrl.lpe;
		end
		else begin															//En el caso de que no me alcance el tamaño libre debo crear otro bloque y volcar este.
			blockWrite (ctrl.arch, ctrl.b, 1);									//Guardo el bloque buffer y creo uno nuevo.
			write (ctrl.libres, ctrl.libre);
			
			ctrl.ib:=1;
			ctrl.libre:=LongBloque;
			move (ctrl.pe[1], ctrl.b[1], ctrl.lpe-1);
			ctrl.ib := ctrl.ib + ctrl.lpe -1;								//Cómo se los voy a explicar???						
			ctrl.libre := ctrl.libre - (ctrl.lpe -1);

		end;
	end;
end;


procedure crear (var ctrl: ctlPersonas; nombre:string);
begin
	rewrite (ctrl.arch, LongBloque);
	rewrite (ctrl.libres);
	ctrl.estado := E; 														//Ver después que decide hacer con estado. Al crearlo ya queda abierto para escrituras. (O conviene cerrarlo y abrirlo luego?)
	ctrl.ib := 1;															//Inicializo el índice del bloque buffer b para recorrerlo.
end;

procedure abrir (var ctrl: ctlPersonas; modo: tEstado);
begin
	if(modo <> C) then
	begin
		reset (ctrl.arch, LongBloque);										//Abro el archivo para lectura y le envío tamano de bloque.
		reset (ctrl.libres);
		ctrl.estado := modo;
		if (modo = E) then begin
			seek (ctrl.arch, FileSize (ctrl.arch)-1);							//Me posiciono en el último bloque del archivo y lo levanto a continuación.
			BlockRead (ctrl.arch, ctrl.b,1);									//Guardo el bloque del archivo en el bloque buffer.
			seek (ctrl.libres, FileSize (ctrl.libres)-1);						//Lo mismo para el archivo de libres.
			read (ctrl.libres, ctrl.libre);
			ctrl.ib := LongBloque - (ctrl.libre +1);							//inicializo el puntero de b para escritura.
		end; 
	end;
end;

procedure cerrar (var ctrl: ctlPersonas);
begin
	if (ctrl.estado = E) or (ctrl.estado = LE) then begin						//Verifico el estado del archivo antes de cerrar del todo.
		blockwrite (ctrl.arch, ctrl.b, 1);										//Escribo el último bloque en el archivo.
		write (ctrl.libres, ctrl.libre);										//Escribo la cantidad de espacio libre en el archivo de espacios libres.
	end;
	ctrl.estado := C;
	close (ctrl.arch);
	close (ctrl.libres);
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
* · result es 0 si la operación se concretó correctamente
*             1 si la operación no se concretó porque el archivo no contenía personas
}
procedure primero(var ctrl: ctlPersonas; var result: byte);
  var
    hayBloqueNoVacio: boolean;
    iBloqueValido: word;
    libresTemp: word;
  begin
  
    if (ctrl.estado = LE) then begin
      //seek(control.arch, filePos(control.arch)-1);
      //blockWrite(control.);
      
      //Busco en el archivo de libres un bloque que seguro tenga
      //personas.
      seek(ctrl.libres, 0);
      hayBloqueNoVacio:= false;
      iBloqueValido:= 0;
      while (not (EOF(ctrl.libres)) and (not(hayBloqueNoVacio))) do begin
        read(ctrl.libres, libresTemp);
        hayBloqueNoVacio:= libresTemp < 1024;
        
        inc(iBloqueValido);
      end;
      
      if (hayBloqueNoVacio) then begin
        dec(iBloqueValido);
        seek(ctrl.arch, iBloqueValido);
        
        blockRead(ctrl.arch, ctrl.b, 1);
        ctrl.ib:= 0;
        
        ctrl.libre:= libresTemp;
        
        LeerPersona(ctrl.b, ctrl.ib, ctrl.p);
        
        result:= 0;
      end
      else
        result:= 1; //todos los bloques están vacíos
    end;
  end;


procedure siguiente (var ctrl: ctlPersonas; var estado: integer);
var
	res : boolean;
Begin
	LeerPersona1(ctrl, res);							//Lee una persona desde donde estaba apuntando IB
	if (res) then									//Si el resultado fue positivo, se devuelve el regitro persona 
		estado := 1									// y estado exitoso
	else
		if (not EOF (ctrl.arch))  then				//Si esta apuntando al final del bloque, y todavia hay mas bloques
			begin
			
			Seek(ctrl.libres, Filepos(ctrl.libres)-1);	//me posiciono en el archivo de libres, donde estaba trabajando
			write(ctrl.libres, ctrl.libre); 		//escribo en el archivo de libres y avanza
			read(ctrl.libres, ctrl.libre);			//leo la cantidad del libres del siguiente bloque
			
			Seek(ctrl.arch, FilePos(ctrl.arch)-1);		//me posiciono en el archivo de persona, donde estaba trabajando
			BlockWrite(ctrl.arch, ctrl.b, 1); 		//escribo en el archivo, el buffer b y avanzo
			BlockRead(ctrl.arch, ctrl.b, 1);		//levanto el siguiente bloque
			ctrl.ib := 1024 - ctrl.libre; 			//actualizo el indice de libre del buffer

			LeerPersona1(ctrl, res);
			estado := 1;
			end
		else
		estado := 0;								//Sino, ya no habia más registro. No hay siguiente porque estaba al final.
End;


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
procedure recuperar (var ctrl: ctlPersonas; dni: longword; var estado: integer);
var
	encontrado, est : integer;
Begin
	encontrado := 0;
	primero(ctrl, est);							//utilizo primero, para posicionarme en el primer registro
	if (est) then										
	begin
		while ((est <> 0) and (encontrado = 0)) do 		//mientras no encuentro la persona con el dni o no se termine el archivo
		begin
			if (ctrl.p.dni <> dni) then					//busco dni
				siguiente(ctrl, est)			//si no lo encuentro, sigo con el proximo registro
			else
				encontrado := 1;						
		end;
		estado := encontrado;								//en el caso de haber recorrido todos los registros y no
	end 												// encontrarlo, devuelvo 0. No se encontraba el registro
	else
		estado := 0;
End;


procedure exportar (var ctrl: ctlPersonas; nomLogTXT : string);
var
	F: text;
	p: tPersona;
	estado: boolean;
Begin
	if (ctrl.estado = LE) then begin
		assign(F, nomLogTXT+'.txt');
		rewrite(F);
		primero(ctrl, p, estado);
		while ( estado ) do begin
			writeln(F, p.nombre:20,' ', p.dni );
			siguiente(ctrl,p,estado);	
		end;
		close(F);
	end;
End;


procedure insertar (var ctrl: ctlPersonas; var estado: integer);
var
	encontrado: integer;
	nBloqueAInsertar: integer;
Begin
	if ( ctrl.estado = LE) then begin
		encontrado := 0;
		recuperar(ctrl, ctrl.p.dni, encontrado); // Busco si existe en el archivo
		if ( encontrado <> 1 ) then begin
			nBloqueAInsertar := libre(ctrl);
			if ( nBloqueAInsertar <> -1 ) then begin // inserto en el bloque
				seek(ctrl.arch, nBloqueAInsertar); // me posiciono en el bloque del archivo a escribir
				// obtengo el espacio libre
				seek(ctrl.libres, nBloqueAInsertar);
				read(ctrl.libres, ctrl.libre);
				{ volcar la persona en el archivo }
				BlockRead(ctrl.arch, ctrl.b, 1); // levanto el bloque
				indice := LongBloque - ctrl.libre; // me posiciono al final
				// copio el dni
				Move(ctrl.p.dni, ctrl.b[indice], sizeOf(ctrl.p.dni)); 
				Inc(indice, sizeOf(ctrl.p.dni));
				// copio nombre y prefijo
				Move(ctrl.p.nombre, ctrl.b[indice], length(ctrl.p.nombre) + 1);
				Inc(indice,length(ctrl.p.nombre) + 1);
			end else // inserto al final
				cargar(ctrl);
		end;
	end;
End;



procedure eliminar (var ctrl: ctlPersonas; dni: longword; var estado: integer);
var
   est: integer;
   resto:word;
   tamReg:byte;
   per:	tPersona;
Begin
     recuperar(ctrl,ctrl.p.dni,est);                  // llamo a recup para buscar el registro, si no lo encuentro sale directamente
     if est=1 then begin                                // encontro la persona
        resto:=Longword-ctrl.libre-ctrl.ib+1;           // cantidad de bytes con informacion de registros queda en el bloque
        tamReg:=0;
        inc(tamReg,sizeof(ctrl.p.dni));                 // van incrementando
        inc(tamReg,length(ctrl.p.nombre)+1);            // el valor de temReg
        inc(tamReg,length(ctrl.p.apellido)+1);          // para saber la cantidad de bytes
        if resto>0 then                                 // chequea que no este al final, si no lo es puede moverse a la izquierda
           move(ctrl.b[ctrl.ib],ctrl.b[ctrl.ib-tamReg],resto);    // mueve los bytes que estan despues de la personaba buscada, sobreescribiendo
        inc(ctrl.libre,tamReg);                         // Incremento el tamaño de espacio libres
        seek(ctrl.arch,filepos(ctrl.arch)-1);           // se posiciona y vuelve a escribir en el bloque del archivo
        write(ctrl.arch,ctrl.b);                        // el registro sin la persona para modificar
        seek(ctrl.libres,filepos(ctrl.libres)-1);       // se posiciona y vuelve a escribir
        write(ctrl.libres,ctrl.b);                      // en el archivo de espacios libres
        estado:=1;                                      //retorna 1 si es verdadero
    end
    else
        estado:=0;                                      // retorna 0 si es falso
End;


procedure modificar (var ctrl: ctlPersonas; dni: longword; var estado: integer);
var
   est: integer;
   resto:word;
   tamReg:byte;
   per:	tPersona;
Begin
    per.dni:=ctrl.p.dni;                               // pienso que el los campos que son para actualizar estan el ctlperonas
    per.nombre:=ctrl.p.nombre;                         // si es asi, lo que hago es pasar lo que trajo el restro a per, asi si lo
    per.apellido:=ctrl.p.apellido;                     // cuando llamo a recuperar no lo pierdo
    recuperar(ctrl.dni,per,est)                        // llamo a recup para buscar el registro, si no lo encuentro sale directamente
    if est=1 then begin                                // encontro la persona
       resto:=Longword-ctrl.libre-arch.ib+1;           // Archivo auxiliar con la cantidad de bytes libres por bloque
       inc(tamReg,sizeof(ctrl.p.dni));                 // van incrementando
       inc(tamReg,length(ctrl.p.nombre)+1);            // el valor de temReg
       inc(tamReg,length(ctrl.p.apellido)+1);          // para saber la cantidad de bytes
       if resto>0 then                                 // chequea que no este al final, si no lo es puede moverse a la izquierda
          move(ctrl.b[ib],ctrl.b[ib-temReg],resto);    // mueve los bytes que estan despues de la personaba buscada, sobreescribiendo
       inc(ctrl.libre,temReg);                         // Incremento el tamaño de espacio libres
       ctrl.ib:=  Longword-ctrl.libre+1;               // posiciono el indice de bloque en el primer lugar libre
       inc(tamReg,sizeof(per.dni));                    // van incrementando
       inc(tamReg,length(per.nombre)+1);               // el valor de temReg
       inc(tamReg,length(per.apellido)+1);             // para saber la cantidad de bytes
       if temReg> ctrl.libre then begin                // no entra en el bloque actual, asi que grabo el bloque e inserto el otro archivo normal en otro bloque
          seek(ctrl.arch,filepos(ctrl.arch)-1);        // se posiciona y vuelve a escribir en el bloque del archivo
          write(ctrl.arch,ctrl.b);                     // el registro sin la persona para modificar
          seek(ctrl.libres,filepos(ctrl.libres)-1);    // se posiciona y vuelve a escribir
          write(ctrl.libres,ctrl.b);                   // en el archivo de espacios libres
          ctrl.p.dni=per.dni;                          // paso el registro
          ctrl.p.nombre=per.nombre;                    // que estaba en per, que seria el modificado
          ctrl.p.apellido=per.apellido;                // a arch
          insertar(ctrl,est);                          // y llamo a insertar, para que lo inserte
       end
       else begin                                      // aca hay espacio suficiente para guardarlo en el bloque
            move(per,ctrl.b[ctrl.ib],temReg);          // pongo en el bloque el registro
            dec(ctrl.b,temReg);                        // decremento la cantidad de espacios libres
            seek(ctrl.arch,filepos(ctrl.arch)-1);      // se posiciona y vuelve a escribir en el bloque del archivo
            write(ctrl.arch,ctrl.b);                   // el registro sin la persona para modificar
            seek(ctrl.libres,filepos(ctrl.libres)-1);  // se posiciona y vuelve a escribir
            write(ctrl.libres,ctrl.b);                 // en el archivo de espacios libres
       end;
       estado:=1;                                      //retorna 1 si es verdadero
    end
    else
        estado:=0;                                     // retorna 0 si es falso
End;


procedure respaldar (var ctrl: ctlPersonas);
//var
	
Begin

End;

End.
