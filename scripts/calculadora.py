# es una calculadora muy basica
import tkinter as tk

class Calculadora(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Calculadora")
        self.geometry("300x400")
        self.resultado_var = tk.StringVar()
        self.crear_interfaz()

    def crear_interfaz(self):
        # Pantalla
        pantalla = tk.Entry(self, textvariable=self.resultado_var, font=("Helvetica", 20), justify="right")
        pantalla.grid(row=0, column=0, columnspan=4, sticky="nsew")
        self.resultado_var.set("")

        # Botones
        botones = [
            ("7", 1, 0), ("8", 1, 1), ("9", 1, 2), ("/", 1, 3),
            ("4", 2, 0), ("5", 2, 1), ("6", 2, 2), ("*", 2, 3),
            ("1", 3, 0), ("2", 3, 1), ("3", 3, 2), ("-", 3, 3),
            ("0", 4, 0), (".", 4, 1), ("=", 4, 2), ("+", 4, 3),
        ]

        for (text, row, column) in botones:
            tk.Button(self, text=text, command=lambda t=text: self.presionar_boton(t), height=2, width=5).grid(row=row, column=column)

        # Ajuste de las filas y columnas
        for i in range(5):
            self.grid_rowconfigure(i, weight=1)
            self.grid_columnconfigure(i, weight=1)

    def presionar_boton(self, texto):
        if texto == "=":
            try:
                resultado = eval(self.resultado_var.get())
                self.resultado_var.set(str(resultado))
            except Exception as e:
                self.resultado_var.set("Error")
        else:
            self.resultado_var.set(self.resultado_var.get() + texto)

if __name__ == "__main__":
    app = Calculadora()
    app.mainloop()
