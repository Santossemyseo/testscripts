import os

def list_folders(directory):
    try:
        with os.scandir(directory) as entries:
            for entry in entries:
                if entry.is_dir():
                    print(entry.name)
    except FileNotFoundError:
        print(f"El directorio '{directory}' no existe.")
    except PermissionError:
        print(f"No tienes permisos para acceder al directorio '{directory}'.")

# Reemplaza 'C:\\ruta\\a\\tu\\carpeta' con la ruta de la carpeta que deseas listar
#directory = 'C:\\ruta\\a\\tu\\carpeta'
directory = 'C:\\Users\\andres.santos.ASOPAGOS\\Documents\\despliegues\\DESPLIEGUES SISE-20240621T132824Z-001\\DESPLIEGUES SISE\\Pruebas\\2024'
list_folders(directory)
