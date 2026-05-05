# Script: automatiza edición básica de un archivo en nano usando secuencias de teclado.
import time
import pyautogui

time.sleep(5)
pyautogui.write('sudo su')
pyautogui.press('enter')
time.sleep(1)
pyautogui.write('cd /bpm/BPM/bin/')
pyautogui.press('enter')
time.sleep(1)
pyautogui.write('nano tx.sh')
pyautogui.press('enter')
time.sleep(1)
pyautogui.write('esta es una prueba de edicion automatizada')
pyautogui.hotkey('ctrl', 'x')
pyautogui.write('y')
pyautogui.press('enter')
