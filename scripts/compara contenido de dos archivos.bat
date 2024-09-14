@echo on

rem Especifica las rutas completas de los archivos de entrada
set archivo1="C:\santos\lif9.txt"
set archivo2="C:\santos\lif8.txt"

rem Especifica la ruta completa y el nombre del archivo de salida para las diferencias
set archivo_salida="C:\santos\diferenciasvm.txt"

rem Compara los archivos usando el comando fc y guarda las diferencias en el archivo de salida
fc %archivo1% %archivo2% > %archivo_salida%

rem Muestra un mensaje indicando que la comparación ha finalizado
echo Comparación completada. El archivo de diferencias se ha guardado en %archivo_salida%

pause
