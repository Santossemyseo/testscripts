#busca un scrip y lo ejecuta

import tkinter as tk
from tkinter import filedialog
import subprocess
import os

class EjecutarScripts(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Ejecutar Scripts")
        self.geometry("400x200")
        self.script_path = tk.StringVar()
        self.crear_interfaz()

    def crear_interfaz(self):
        # Seleccionar archivo
        tk.Label(self, text="Seleccionar Script:").pack(pady=10)
        tk.Button(self, text="Buscar", command=self.seleccionar_script).pack()

        # Botón para ejecutar
        tk.Button(self, text="Ejecutar", command=self.ejecutar_script).pack(pady=20)

    def seleccionar_script(self):
        file_path = filedialog.askopenfilename(filetypes=[("Archivos de Scripts", "*.py;*.bat;*.exe;*.sh")])
        self.script_path.set(file_path)

    def ejecutar_script(self):
        script_path = self.script_path.get()
        if os.path.exists(script_path):
            try:
                subprocess.Popen([script_path], shell=True)
            except Exception as e:
                tk.messagebox.showerror("Error", f"No se pudo ejecutar el script:\n{str(e)}")
        else:
            tk.messagebox.showwarning("Advertencia", "Selecciona un archivo de script válido.")

if __name__ == "__main__":
    app = EjecutarScripts()
    app.mainloop()
