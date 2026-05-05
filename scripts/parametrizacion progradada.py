# Script: convierte un archivo CSV a JSON con salida parametrizable por línea de comandos.
import argparse
import pandas as pd


def main():
    parser = argparse.ArgumentParser(description="Convierte CSV a JSON")
    parser.add_argument("csv_entrada", help="Ruta del CSV de entrada")
    parser.add_argument("json_salida", help="Ruta del JSON de salida")
    args = parser.parse_args()

    df = pd.read_csv(args.csv_entrada)
    json_data = df.to_json(orient='records', force_ascii=False)

    with open(args.json_salida, 'w', encoding='utf-8') as f:
        f.write(json_data)


if __name__ == '__main__':
    main()
