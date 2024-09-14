import pyautogui
import subprocess
import time
# Usar comillas simples o dobles para indicar la combinación de teclas
pyautogui.hotkey('win', 'r')
time.sleep(1)
# Escribir "cmd" para buscar el navegador Chrome
pyautogui.write('cmd')
time.sleep(1)
# Presionar Enter para navegar a la página de Google
pyautogui.press('enter')
time.sleep(1)
# Escribir "pwd" para buscar el navegador Chrome
pyautogui.press('esto es una prueba')
time.sleep(1)
pyautogui.press('desde python')
time.sleep(1)
