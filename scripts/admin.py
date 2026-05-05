# Script: interfaz GUI para ejecutar utilidades Python y generar un script personalizado.
import subprocess
import tkinter as tk
from tkinter import messagebox
from pathlib import Path
from io import BytesIO

import requests
from PIL import Image, ImageTk

BASE_DIR = Path(__file__).resolve().parent


class EjecutarScripts(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Lanzador de scripts")
        self.geometry("600x600")
        self.logo = None
        self.cargar_logo("https://cdn.pixabay.com/photo/2016/09/21/13/44/corporate-1684924_960_720.jpg")
        self.crear_interfaz()

    def cargar_logo(self, url):
        try:
            response = requests.get(url, timeout=8)
            if response.status_code == 200:
                image_data = BytesIO(response.content)
                self.logo = ImageTk.PhotoImage(Image.open(image_data))
        except Exception:
            self.logo = None

    def crear_interfaz(self):
        if self.logo:
            tk.Label(self, image=self.logo).grid(row=0, column=0, columnspan=3, pady=10)
        else:
            tk.Label(self, text="Logo no disponible").grid(row=0, column=0, columnspan=3, pady=10)

        scripts = [
            ("Script personalizado", self.crear_script("script_personalizado.py")),
            ("Calculadora", f'python "{BASE_DIR / "calculadora.py"}"'),
        ]

        for index, (script_name, script_command) in enumerate(scripts):
            tk.Button(
                self,
                text=script_name,
                command=lambda cmd=script_command: self.ejecutar_script(cmd),
            ).grid(row=index + 1, column=0, padx=5, pady=5, sticky="ew")

    def ejecutar_script(self, command):
        try:
            subprocess.Popen(command, shell=True)
        except Exception as e:
            messagebox.showerror("Error", f"No se pudo ejecutar el script:\n{str(e)}")

    def crear_script(self, script_filename):
        script_path = BASE_DIR / script_filename
        script_content = '# Script: ejemplo generado desde admin.py\nprint("Hola desde el script personalizado!")\n'
        script_path.write_text(script_content, encoding="utf-8")
        return f'python "{script_path}"'


if __name__ == "__main__":
    app = EjecutarScripts()
    app.mainloop()
