# Script: automatiza la apertura de CMD y escritura de comandos de prueba con pyautogui.
import time
import pyautogui

pyautogui.hotkey('win', 'r')
time.sleep(1)
pyautogui.write('cmd')
time.sleep(1)
pyautogui.press('enter')
time.sleep(1)
pyautogui.write('echo esto es una prueba')
pyautogui.press('enter')
time.sleep(1)
pyautogui.write('echo desde python')
pyautogui.press('enter')
