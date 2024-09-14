# el archivo se pasa desde csv a json
import pandas as pd


# Leer el archivo CSV
df = pd.read_csv('C:\santos\.csv')

# Convertir el DataFrame a JSON
json_data = df.to_json(orient='records')

# Guardar el JSON en un archivo
with open('aaa.json', 'w') as f:
    f.write(json_data)
