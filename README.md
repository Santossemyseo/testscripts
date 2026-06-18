# testscripts

Colección de scripts de automatización y utilidades (Python, BAT, VBS, JS, XML).

## Estado funcional general

- **Funcionales con dependencias instaladas**: `calculadora.py`, `scri.py`, `grid.py`, `admin.py`, `listar carpetas.py`, `parametrizacion progradada.py`, `openvpn.bat`, `compara contenido de dos archivos.bat`, `EjeutarTareas.vbs`, `noclosedcolab`, `task schedelure sin logueo.xml`.
- **Ajustados para quedar funcionales**: `admin.py`, `hi.py`, `hi2.py`, `script_personalizado.py`, `parametrizacion progradada.py`.
- **Sensibles a entorno**: scripts con rutas absolutas Windows o que requieren interfaz gráfica/foco de teclado.

## Dependencias

Python:
- Estándar: `tkinter`, `subprocess`, `os`, `pathlib`, `time`, `argparse`
- Externas: `Pillow`, `requests`, `pyautogui`, `pandas`

## Interrelaciones (mapa)

- `grid.py` ➜ ejecuta `scri.py` y `calculadora.py` por comandos de botón.
- `admin.py` ➜ genera/usa `script_personalizado.py` y también ejecuta `calculadora.py`.
- `EjeutarTareas.vbs` ➜ orquesta múltiples `.bat` externos no incluidos en este repositorio.
- `task schedelure sin logueo.xml` ➜ agenda la ejecución de un `.bat` externo del sistema.

## Casos de uso prácticos

1. **Mesa de ayuda / operaciones**: abrir `grid.py` o `admin.py` para lanzar utilidades frecuentes sin usar terminal.
2. **Control de cambios en archivos planos**: usar `compara contenido de dos archivos.bat` para validar diferencias entre versiones de reportes TXT.
3. **Automatización de respaldos/reportes nocturnos**: usar `EjeutarTareas.vbs` junto al Programador de Tareas de Windows.
4. **Conversión de datos**: usar `parametrizacion progradada.py` para convertir CSV a JSON para APIs o integraciones.
5. **Persistencia de sesión en Colab**: pegar `noclosedcolab` en consola del navegador cuando se requiere mantener sesión activa.
6. **Arranque rápido de VPN corporativa**: usar `openvpn.bat` como acceso directo de conexión.

## Resumen por archivo

- `scripts/admin.py`: GUI que descarga un logo opcional y permite ejecutar scripts predefinidos.
- `scripts/grid.py`: tablero de botones para abrir scripts locales.
- `scripts/scri.py`: selector de archivo para ejecutar scripts/programas.
- `scripts/calculadora.py`: calculadora básica con `tkinter`.
- `scripts/hi.py`: ejemplo de automatización de teclado con `pyautogui`.
- `scripts/hi2.py`: edición automatizada de archivo con `nano` vía teclado simulado.
- `scripts/listar carpetas.py`: lista carpetas de una ruta dada.
- `scripts/parametrizacion progradada.py`: convierte CSV a JSON por CLI.
- `scripts/script_personalizado.py`: script simple generado desde `admin.py`.
- `scripts/EjeutarTareas.vbs`: ejecuta lote de BATs y respalda TXT con logging.
- `scripts/compara contenido de dos archivos.bat`: compara dos archivos con `fc`.
- `scripts/openvpn.bat`: inicia OpenVPN GUI y conecta un perfil.
- `scripts/keys.bat.txt`: comandos de referencia para `cmdkey`.
- `scripts/noclosedcolab`: JavaScript para clic periódico en Colab.
- `scripts/task schedelure sin logueo.xml`: export de tarea programada Windows.

## Script forense DRP / Hyper-V

- `scripts/Forensic-Investigation-V1.6.ps1`: version mejorada del recolector forense para archivo/carpeta. Acepta `-TargetPath` y `-BasePath`, conserva modo interactivo si no se pasa ruta, corrige el mapeo de campos Hyper-V, normaliza rutas para correlacion de discos, integra analisis avanzado de VMMS/Worker, checkpoints, merges, snapshots, AVHDX, tipo de VHD y relacion VM-disco, genera manifiesto SHA256 de salidas y mantiene limites configurables para evitar barridos excesivos de eventos.

Ejemplo:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\Forensic-Investigation-V1.6.ps1 -TargetPath "C:\Ruta\Objetivo" -BasePath "C:\DRP\reporte"
```

## Nota

Si quieres, en un siguiente PR puedo dejar una estructura por carpetas (`python/`, `windows/`, `browser/`) y parametrizar todas las rutas absolutas.

## Nota de versionado de PR

Este repositorio debe publicarse con el **PR de versión 2** (incluye fix de XML en texto y `.gitattributes`), no con el PR inicial.

