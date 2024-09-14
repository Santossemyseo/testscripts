import tkinter as tk
from tkinter import filedialog
from PIL import Image, ImageTk
import subprocess
import os
import requests
from io import BytesIO

class EjecutarScripts(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("este es el logo de whatsapp")
        self.geometry("600x600")
        self.cargar_logo("https://cdn.pixabay.com/photo/2016/09/21/13/44/corporate-1684924_960_720.jpg")  # Coloca la URL de tu logo aquí
        self.crear_interfaz()

    def cargar_logo(self, url):
        try:
            response = requests.get(url)
            if response.status_code == 200:
                image_data = BytesIO(response.content)
                self.logo = ImageTk.PhotoImage(Image.open(image_data))
            else:
                self.logo = None
        except Exception as e:
            self.logo = None

    def crear_interfaz(self):
        # Mostrar el logo
        if self.logo:
            tk.Label(self, image=self.logo).grid(row=0, column=0, columnspan=9, pady=10)
        else:
            tk.Label(self, text="Logo no disponible").grid(row=0, column=0, columnspan=9, pady=10)

        # Botones para ejecutar scripts
        scripts = [
            ("Scrip", "python scri.py"),
            ("Calculadora", "python calculadora.py"),
            ("Scrip", "python scri.py"),
            ("Calculadora", "python calculadora.py"),
            ("Scrip", "python scri.py"),
            ("Calculadora", "python calculadora.py"),
            ("Scrip", "python scri.py"),
            ("Calculadora", "python calculadora.py"),
            ("Scrip", "python scri.py"),
            ("Calculadora", "python calculadora.py"),
            ("Scrip", "python scri.py"),
            ("Calculadora", "python calculadora.py"),
            ("Scrip", "python scri.py"),
            ("Calculadora", "python calculadora.py"),
            ("Scrip", "python scri.py"),
            ("Calculadora", "python calculadora.py"),
            ("Scrip", "python scri.py"),
            ("Calculadora", "python calculadora.py"),
            ("Scrip", "python scri.py"),
            ("Calculadora", "python calculadora.py"),
            # Agrega más scripts según tus necesidades
            # Cada tupla tiene el nombre del script y el comando para ejecutarlo
        ]

        for i in range(9):
            for j in range(9):
                if scripts:
                    script_name, script_command = scripts.pop(0)
                    tk.Button(self, text=script_name, command=lambda cmd=script_command: self.ejecutar_script(cmd)).grid(row=i+1, column=j, padx=5, pady=5)

    def ejecutar_script(self, command):
        try:
            subprocess.Popen(command, shell=True)
        except Exception as e:
            tk.messagebox.showerror("Error", f"No se pudo ejecutar el script:\n{str(e)}")

if __name__ == "__main__":
    app = EjecutarScripts()
    app.mainloop()