program pruebaTADarchivos;

uses crt, Unidad;

var
  archivo: ctlPersonas;
  nomb: String;

//NUEVO
procedure crearArch;
 begin
   crear(archivo, nomb);
 end; 

//REVISADO. SIRVE
procedure leerPersonaP(var p: tPersona);
  begin
    writeln('');
    write('Ingrese dni. 0 para terminar');
    readln(p.dni);
    if (p.dni <> 0) then begin
      write('Ingrese nombre persona: ');
      readln(p.nombre);
    end;
  end;
  
//REVISADO. SIRVE
procedure cargarSinValidar;
 // var
   // resultado: boolean;
  begin
    writeln('');

    leerPersonaP(archivo.p);

    while (archivo.p.dni <> 0) do begin
	  abrir(archivo, E, nomb);
      cargar(archivo);
	  cerrar(archivo);
      leerPersonaP(archivo.p);
    end;
  end;
  
//REVISADO. SIRVE
  procedure insert;
  var
    resultado: boolean;
  begin
	//writeln('archivo: ', archivo.proxLibre);
    leerPersonaP(archivo.p);
    while (archivo.p.dni <> 0) do begin
	  abrir(archivo, LE, nomb);
      insertar(archivo, resultado);
      cerrar(archivo);
      leerPersonaP(archivo.p);
    end;
  end;
    
//REVISADO. SIRVE
procedure modificarPersonas;
  var
    resultado: boolean;
  begin
    writeln;
    leerPersonaP(archivo.p);
    while (archivo.p.dni <> 0) do begin
	  abrir(archivo, LE, nomb);
      modificar(archivo, resultado);
	  cerrar(archivo);
      if (resultado) then
        writeln('Modificacion exitosa')
      else
        writeln('Modificacion fallida');
      leerPersonaP(archivo.p);
    end;
  end;

//REVISADO. SIRVE
procedure eliminarPersonas;
  var
    resultado: boolean;
  begin
    writeln('');
    write('Ingrese dni. 0 para terminar: ');
    readln(archivo.p.dni);
    while (archivo.p.dni <> 0) do begin
	abrir (archivo, E, nomb);
      eliminar(archivo, resultado);
	cerrar (archivo);

      writeln('');
      write('Eliminacion '); 
      if (resultado) then
        writeln('exitosa')
      else
        writeln('fallida');
        
      write('Ingrese dni. 0 para terminar: ');
      readln(archivo.p.dni);
    end;
  end;
  
//REVISADO. SIRVE
procedure imprimirPersonas;
  var
    resultado: boolean;
  begin
    abrir(archivo, LE, nomb);
    writeln('');
    writeln('ARCHIVO DE PERSONAS');
    writeln('');

    primero(archivo, resultado);
    while (resultado) do begin
      writeln(archivo.p.dni);
      writeln(archivo.p.nombre);
      
      writeln();
      siguiente(archivo, resultado);
    end;
    
    cerrar(archivo);

    writeln('Presione cualquier tecla para volver al menu');
    readkey;
  end;
  
//REVISADO. SIRVE
procedure exportarAtxt;
var
  nombre: string[20];
begin
  //reset(archivo.arch);
  
  abrir (archivo, LE, nomb);
  write('Ingrese nombre que desea para su archivo de texto: ');
  read(nombre);
  exportar(archivo, nombre);
  writeln('');
  writeln('Exportado completo');
  cerrar(archivo);
readkey;
end;


procedure respald;
var
  resultado: boolean;
begin
  //reset(archivo.archPersonas);
  respaldar(archivo, resultado);
  writeln('');
  writeln('Respaldo completo');
  readkey;
end;

procedure recuper;
var
  resultado: boolean;
  dni: longword;
begin
  writeln('');
  writeln('Ingrese dni de persona a buscar: ');
  readln(dni);
  abrir(archivo,LE,nomb);
  recuperar(archivo,dni,resultado);
  cerrar(archivo);
  if ( resultado ) then
	writeln('Persona encontrada: ', archivo.p.nombre)
  else
	writeln('La persona con dni: ',dni,' no existe');
  readkey;
end;
  

  
  
  { aca arranca el programa }

  
  
  
var
  control: integer;

 // x: boolean;
begin
  control:= 1;

{    ----------------ESTO HABRIA QUE VERLO BIEN, SI EL USUARIO INGRESAR EL NOMBRE DEL ARCHIVO-----------------
  assign(archivo.archPersonas, 'personas');
 
  x:= false;
  if (x) then begin
  	rewrite(archivo.archPersonas);
	archivo.persona.estado:= false;
	archivo.proxLibre:= 0; 				//Actualizo la variable, no hay elementos libre.
	write(archivo.archPersonas, archivo.persona);
	close(archivo.archPersonas);
  end
  
if (fileSize) begin
    reset(archivo.archPersonas);
    archivo.persona.estado := false;
    read(archivo.archPersonas, archivo.persona);
    archivo.proxLibre := archivo.persona.proxLibre;
    writeln(archivo.proxLibre);
  end;
  ----------------------------------------------------------------------------------------------------------
 } 
  
   write('Ingrese nombre que desea para su archivo: ');
   read(nomb);
   writeln;
  
  while (control <> 0) do begin
    clrscr;

    writeln('ARCHIVO DE PERSONAS');
    writeln('--------------------------------------');
    writeln('');
    writeln('1. Crear personas');
    writeln('2. Cargar personas');
    writeln('3. Insertar personas');
    writeln('4. Modificar una persona');
    writeln('5. Eliminar una persona');
    writeln('6. Imprimir todas las personas');
    writeln('7. Exportar a txt');
    writeln('8. Respaldar');
    writeln('9. Recuperar una persona');
  //  writeln('0. Salir');
    writeln('');
    readln(control);
   
    case (control) of
      1: crearArch;
      2: cargarSinValidar;
      3: insert;
      4: modificarPersonas;
      5: eliminarPersonas;
      6: imprimirPersonas;
      7: exportarAtxt;
      8: respald;
      9: recuper;
      else begin
        writeln('Opción no válida, intente nuevamente (presione Enter para continuar)');
        readln(control);
      end;
    end;
  end;

end.
