# -*- coding: utf-8 -*-
"""
WoW Smart Pixel Recruiter: Virtual Desktop & OpenCV Edition + GUI (NumPad 5, NumPad 4)
- МЕНЕДЖЕР ВИРТУАЛЬНЫХ РАБОЧИХ СТОЛОВ:
  - Автоматическое создание / привязка выделенного рабочего стола для World of Warcraft.
  - Принудительный перенос окна WoW на выделенный стол.
  - NumPad 4: Быстрое всплывающее меню переключения (Перейти в WoW <-> Вернуться на основной стол).
- ИЗОЛИРОВАННЫЙ ВВОД (CLICK ISOLATION):
  - Клик (SendInput F12 / PostMessage) отправляется ИСКЛЮЧИТЕЛЬНО в окно WoW.
  - Когда вы работаете на основном столе (браузер, чаты, видео), фоновые нажатия НИКОГДА не попадут в ваши активные окна!
- ПОСТОЯННЫЙ ОПТИЧЕСКИЙ КОНТЕЙНЕР & СКАНИРОВАНИЕ ВСЕГО ЭКРАНА (OpenCV):
  - В левом верхнем углу игры закреплен распознаваемый постоянный контейнер (kar_container.png).
  - OpenCV сканирует ВЕСЬ экран / окно игры, находит контейнер с точностью 100% за 20-300 мс и вычисляет координаты центра.
  - Никакой ручной калибровки мышью не требуется!
- СИСТЕМНАЯ СЛУЖБА С ЕДИНЫМ ЭКЗЕМПЛЯРОМ (Single Instance IPC):
  - Повторный запуск не плодит процессы, а открывает меню.
- УПРАВЛЕНИЕ:
  - NumPad 4: Меню переключения рабочих столов (WoW <-> Основной)
  - NumPad 5: Открыть / скрыть панель управления службой
  - NumPad 1: Включить / приостановить авто-набор
  - F11: Запуск авто-поиска контейнера через OpenCV на всем экране
"""

import time
import sys
import os
import json
import random
import threading
import queue
import socket
import winsound
from http.server import ThreadingHTTPServer, HTTPServer, BaseHTTPRequestHandler
import subprocess
# import keyboard (заменен на нативный Win32 RegisterHotKey)
import win32gui
import win32api
import win32service
import win32process
import winreg
import ctypes
from ctypes import wintypes
try:
    import tkinter as tk
    from tkinter import ttk, messagebox, filedialog
except ImportError:
    tk = None

import cv2
import numpy as np

try:
    import pyvda
except ImportError:
    pyvda = None

# Раннее подключение к интерактивному рабочему столу до любых вызовов User32/COM
def attach_to_desktop():
    try:
        import pythoncom
        pythoncom.CoInitialize()
    except Exception:
        pass
    try:
        hdesk = win32service.GetThreadDesktop(win32api.GetCurrentThreadId())
        desk_name = win32service.GetUserObjectInformation(hdesk, 2)
        if str(desk_name).lower() == 'default':
            return
    except Exception:
        pass
    try:
        hwinsta = win32service.OpenWindowStation('WinSta0', False, 0x10000000)
        hwinsta.SetProcessWindowStation()
        hdesk = win32service.OpenDesktop('Default', 0, False, 0x10000000)
        hdesk.SetThreadDesktop()
    except Exception:
        pass

attach_to_desktop()

# Инициализация высокой четкости DPI (для точного попадания пиксель-в-пиксель в окне)
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:
    try:
        ctypes.windll.user32.SetProcessDPIAware()
    except Exception:
        pass

if getattr(sys, 'frozen', False):
    SCRIPT_DIR = os.path.dirname(os.path.abspath(sys.executable))
    BASE_DIR = getattr(sys, '_MEIPASS', SCRIPT_DIR)
else:
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    BASE_DIR = SCRIPT_DIR
SERVICE_LOG_PATH = os.path.join(SCRIPT_DIR, "service.log")

class SafeLogStream:
    def __init__(self, log_path, fallback_stream=None):
        self.log_path = log_path
        self.fallback = fallback_stream

    def write(self, s):
        try:
            with open(self.log_path, "a", encoding="utf-8") as f:
                f.write(s)
        except Exception:
            pass
        if self.fallback:
            try:
                self.fallback.write(s)
            except Exception:
                pass

    def flush(self):
        if self.fallback:
            try:
                self.fallback.flush()
            except Exception:
                pass

sys.stdout = SafeLogStream(SERVICE_LOG_PATH, sys.stdout)
sys.stderr = SafeLogStream(SERVICE_LOG_PATH, sys.stderr)

if sys.stderr is not None:
    try:
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

WM_KEYDOWN = 0x0100
WM_KEYUP   = 0x0101
VK_F12     = 0x7B
IPC_PORT   = 49285

CONFIG_PATH = os.path.join(SCRIPT_DIR, "pixel_config.json")
TEXTURE_CONTAINER_PATH = os.path.join(SCRIPT_DIR, "Textures", "kar_container.png")

# -------------------------------------------------------------
# Анализ папки WoW и авто-определение путей
# -------------------------------------------------------------
def analyze_wow_folder(folder_path):
    """
    Анализирует указанную пользователем папку WoW:
    - Извлекает путь к исполняемому файлу WoW (*.exe)
    - Извлекает путь к Interface\\AddOns
    - Извлекает путь к Logs\\WoWChatLog.txt
    - Извлекает путь к WTF\\Config.wtf (проверяет SET chatLog '1')
    """
    if not folder_path or not os.path.exists(folder_path):
        return None

    folder_path = os.path.abspath(folder_path)
    result = {
        "root_dir": folder_path,
        "exe_path": None,
        "addons_dir": None,
        "log_path": None,
        "config_wtf": None
    }

    # 1. Поиск exe в указанной папке и подпапках
    candidate_exes = []
    for root_dir, dirs, files in os.walk(folder_path):
        for f in files:
            if f.lower().endswith(".exe") and ("wow" in f.lower() or "firestorm" in f.lower()):
                candidate_exes.append(os.path.join(root_dir, f))
        # Ограничиваем глубину сканирования 2 уровнями
        if root_dir.count(os.sep) - folder_path.count(os.sep) >= 2:
            dirs.clear()

    if candidate_exes:
        candidate_exes.sort(key=lambda p: (
            0 if "12.0" in p or "midnight" in p.lower() else
            1 if "11.2" in p or "war within" in p.lower() else
            2
        ))
        result["exe_path"] = candidate_exes[0]

    # 2. Поиск Interface\\AddOns
    candidate_addons = [
        os.path.join(folder_path, "Interface", "AddOns"),
        os.path.join(folder_path, "_midnight_", "Interface", "AddOns"),
        os.path.join(folder_path, "_retail_", "Interface", "AddOns")
    ]
    for ad in candidate_addons:
        if os.path.exists(ad):
            result["addons_dir"] = ad
            break
    if not result["addons_dir"]:
        result["addons_dir"] = os.path.join(folder_path, "Interface", "AddOns")

    # 3. Поиск Logs\\WoWChatLog.txt
    candidate_logs = [
        os.path.join(folder_path, "Logs", "WoWChatLog.txt"),
        os.path.join(folder_path, "_midnight_", "Logs", "WoWChatLog.txt"),
        os.path.join(folder_path, "_retail_", "Logs", "WoWChatLog.txt")
    ]
    for cl in candidate_logs:
        if os.path.exists(os.path.dirname(cl)):
            result["log_path"] = cl
            break
    if not result["log_path"]:
        result["log_path"] = os.path.join(folder_path, "Logs", "WoWChatLog.txt")

    # 4. Поиск WTF\\Config.wtf
    candidate_wtfs = [
        os.path.join(folder_path, "WTF", "Config.wtf"),
        os.path.join(folder_path, "_midnight_", "WTF", "Config.wtf"),
        os.path.join(folder_path, "_retail_", "WTF", "Config.wtf")
    ]
    for cw in candidate_wtfs:
        if os.path.exists(cw):
            result["config_wtf"] = cw
            break

    return result

def _detect_wow_log_path():
    p_mid = r"C:\Firestorm\The War Within\_midnight_\Logs\WoWChatLog.txt"
    p_tww = r"C:\Firestorm\The War Within\Logs\WoWChatLog.txt"
    if os.path.exists(p_mid) and os.path.exists(p_tww):
        try:
            return p_mid if os.path.getmtime(p_mid) >= os.path.getmtime(p_tww) else p_tww
        except Exception:
            return p_mid
    return p_mid if os.path.exists(p_mid) else p_tww

def get_wow_executable_path():
    p_mid = r"C:\Firestorm\The War Within\_midnight_\WoW 12.0.7 - Firestorm.exe"
    p_tww = r"C:\Firestorm\The War Within\WoW 11.2.5 - Firestorm.exe"
    if os.path.exists(p_mid): return p_mid
    if os.path.exists(p_tww): return p_tww
    for d in [r"C:\Firestorm\The War Within\_midnight_", r"C:\Firestorm\The War Within"]:
        if os.path.exists(d):
            for f in os.listdir(d):
                if f.lower().endswith(".exe") and ("wow" in f.lower() or "firestorm" in f.lower()):
                    return os.path.join(d, f)
    return None

WOW_LOG_PATH = _detect_wow_log_path()
PYTHONW_EXE = r"C:\Users\root\AppData\Local\Python\pythoncore-3.14-64\pythonw.exe"
REG_RUN_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"
REG_RUN_NAME = "WoWSmartRecruiterService"
RVC_AUDIO_CACHE = r"C:\soft\rvc\audio_cache"

# -------------------------------------------------------------
# Высоконадежный синтез речи SAPI с очередью и звуковыми чимами
# -------------------------------------------------------------
tts_queue = queue.Queue()
last_speech_time = {}

def tts_worker_loop():
    """Фоновый воркер речи: стабильное воспроизведение без конфликтов COM-потоков"""
    try:
        import pythoncom
        import win32com.client
        pythoncom.CoInitialize()
        sp = win32com.client.Dispatch("SAPI.SpVoice")
        
        # Настройка русского голоса (Microsoft Irina Desktop)
        try:
            for v in sp.GetVoices():
                desc = v.GetDescription()
                if "Russian" in desc or "Irina" in desc or "Рус" in desc:
                    sp.Voice = v
                    break
        except Exception:
            pass
            
        sp.Volume = 100
        sp.Rate = 1
        
        while True:
            text = tts_queue.get()
            if text is None:
                break
            try:
                # 1. Мгновенный приятный Windows-чиме в наушники
                try:
                    winsound.MessageBeep(winsound.MB_ICONASTERISK)
                except Exception:
                    pass
                # 2. Четкое произношение оповещения на русском
                sp.Speak(text)
            except Exception as e:
                print(f"[TTS Ошибка] {e}")
            finally:
                tts_queue.task_done()
                
        pythoncom.CoUninitialize()
    except Exception as e:
        print(f"[TTS Worker FATAL] {e}")

threading.Thread(target=tts_worker_loop, daemon=True).start()

def speak(text, min_interval=1.5):
    """Оповещение в наушники с умной защитой от повторов (дебаунс)"""
    cur_t = time.time()
    if cur_t - last_speech_time.get(text, 0) < min_interval:
        return
    last_speech_time[text] = cur_t
    tts_queue.put(text)

def speak_async(text):
    """Совместимость со старыми вызовами"""
    speak(text)

def classify_pixel_trigger(r, g, b):
    """
    Классифицирует оптический пиксельный триггер аддона:
    - ("FULL", "GROUP")    -> Пурпурный RGB(255, 0, 255)
    - ("INVITE", "TANK")   -> Яркий голубой RGB(0, 180, 255)
    - ("INVITE", "HEAL")   -> Неоновый зеленый RGB(0, 255, 0)
    - ("INVITE", "DPS")    -> Яркий оранжевый RGB(255, 130, 0)
    - ("ACTION", "DECLINE")-> Желтый RGB(255, 255, 0)
    - ("TEST", "CALIB")    -> Чистый белый RGB(255, 255, 255)
    - (None, None)         -> Темный фон / нейтральный режим ожидания (IDLE)
    """
    # 0. Игнорируем нейтральный темный фон ожидания (IDLE)
    if r <= 38 and g <= 38 and b <= 38:
        return (None, None)

    # 1. Белый: калибровка F11 (/kar pixel)
    if r >= 220 and g >= 220 and b >= 220:
        return ("TEST", "CALIB")

    # 2. Пурпурный: Группа полностью собрана 5/5
    if r >= 160 and b >= 160 and g <= 90:
        return ("FULL", "GROUP")

    # 3. Чистый Желтый: Отклонение не подошедшего кандидата RGB(255, 255, 0)
    # Защита от ложного срабатывания на песочные / бежевые текстуры дороги (RGB 216, 179, 83)
    if r >= 200 and g >= 200 and b <= 50 and abs(int(r) - int(g)) <= 40:
        return ("ACTION", "DECLINE")

    # 4. Яркий Голубой / Cyan: Найден Танк RGB(0, 180, 255)
    if b >= 170 and g >= 100 and r <= 60:
        return ("INVITE", "TANK")

    # 5. Сочный Неоновый зеленый: Найден Хил RGB(0, 255, 0)
    if g >= 170 and r <= 60 and b <= 60:
        return ("INVITE", "HEAL")

    # 6. Сочный Оранжевый: Найден ДД RGB(255, 130, 0)
    if r >= 180 and 80 <= g <= 160 and b <= 50:
        return ("INVITE", "DPS")

    return (None, None)

def find_wow_hwnd():
    attach_to_desktop()
    hwnd = win32gui.FindWindow('waApplication Window', None)
    if hwnd and win32gui.IsWindow(hwnd): return hwnd
    hwnd = win32gui.FindWindow(None, 'World of Warcraft')
    if hwnd and win32gui.IsWindow(hwnd): return hwnd
    hwnd = win32gui.FindWindow('GxWindowClass', None)
    if hwnd and win32gui.IsWindow(hwnd): return hwnd
    return None

def force_focus_window(hwnd):
    """Принудительно переносит фокус ввода и окно на передний план с обходом ограничений Windows"""
    if not hwnd or not win32gui.IsWindow(hwnd):
        return False
    try:
        user32 = ctypes.windll.user32
        kernel32 = ctypes.windll.kernel32
        user32.AllowSetForegroundWindow(-1) # ASFW_ANY

        fg = user32.GetForegroundWindow()
        cur_thread = kernel32.GetCurrentThreadId()
        fg_thread = user32.GetWindowThreadProcessId(fg, None) if fg else 0
        target_thread = user32.GetWindowThreadProcessId(hwnd, None)

        attached_fg = False
        attached_target = False

        if fg_thread and fg_thread != cur_thread:
            attached_fg = bool(user32.AttachThreadInput(cur_thread, fg_thread, True))
        if target_thread and target_thread != cur_thread:
            attached_target = bool(user32.AttachThreadInput(cur_thread, target_thread, True))

        try:
            if user32.IsIconic(hwnd):
                user32.ShowWindow(hwnd, 9) # SW_RESTORE
            else:
                user32.ShowWindow(hwnd, 5) # SW_SHOW
            user32.BringWindowToTop(hwnd)
            user32.SetForegroundWindow(hwnd)
            user32.SetActiveWindow(hwnd)
        finally:
            if attached_fg:
                user32.AttachThreadInput(cur_thread, fg_thread, False)
            if attached_target:
                user32.AttachThreadInput(cur_thread, target_thread, False)
        return True
    except Exception as e:
        print(f"[Focus] Ошибка force_focus_window: {e}")
        return False

# -------------------------------------------------------------
# Менеджер виртуальных рабочих столов (VirtualDesktopManager)
# -------------------------------------------------------------
class VirtualDesktopManager:
    """Менеджер виртуальных рабочих столов для гарантированной изоляции World of Warcraft"""
    def __init__(self, auto_move=True):
        self.enabled = (pyvda is not None)
        self.wow_desktop_id = None
        self.wow_desktop_num = 2
        self.return_desktop_num = 1
        self._init_desktops(auto_move=auto_move)

    def _init_desktops(self, auto_move=True):
        if not self.enabled:
            return
        try:
            attach_to_desktop()
            vds = pyvda.get_virtual_desktops()
            cur = pyvda.VirtualDesktop.current()
            if cur:
                self.return_desktop_num = cur.number
            
            # 1. Поиск стола с именем 'wow' (без учета регистра)
            found_wow_vd = None
            for v in vds:
                if (v.name or "").strip().lower() == "wow":
                    found_wow_vd = v
                    break

            if found_wow_vd:
                self.wow_desktop_id = found_wow_vd.id
                self.wow_desktop_num = found_wow_vd.number
                print(f"[VirtualDesktop] Найден существующий рабочий стол 'wow': #{self.wow_desktop_num} ({self.wow_desktop_id})")
            else:
                # Стола с именем 'wow' нет -> создаем или переименовываем
                if len(vds) < 2:
                    new_vd = pyvda.VirtualDesktop.create()
                    try:
                        new_vd.rename("wow")
                    except Exception as re_err:
                        print(f"[VirtualDesktop] Ошибка переименования: {re_err}")
                    self.wow_desktop_id = new_vd.id
                    self.wow_desktop_num = new_vd.number
                    print(f"[VirtualDesktop] Автоматически создан рабочий стол с именем 'wow': #{self.wow_desktop_num}")
                else:
                    # Есть столы: проверяем стол #2
                    second_vd = None
                    for v in vds:
                        if v.number == 2:
                            second_vd = v
                            break
                    if second_vd and (not second_vd.name or not second_vd.name.strip()):
                        try:
                            second_vd.rename("wow")
                            self.wow_desktop_id = second_vd.id
                            self.wow_desktop_num = second_vd.number
                            print(f"[VirtualDesktop] Стол #2 переименован в 'wow': #{self.wow_desktop_num}")
                        except Exception:
                            new_vd = pyvda.VirtualDesktop.create()
                            try:
                                new_vd.rename("wow")
                            except Exception:
                                pass
                            self.wow_desktop_id = new_vd.id
                            self.wow_desktop_num = new_vd.number
                            print(f"[VirtualDesktop] Создан рабочий стол 'wow': #{self.wow_desktop_num}")
                    else:
                        new_vd = pyvda.VirtualDesktop.create()
                        try:
                            new_vd.rename("wow")
                        except Exception:
                            pass
                        self.wow_desktop_id = new_vd.id
                        self.wow_desktop_num = new_vd.number
                        print(f"[VirtualDesktop] Создан рабочий стол 'wow': #{self.wow_desktop_num}")

            # Переносим окно WoW на стол 'wow', только если auto_move=True
            if auto_move:
                self.ensure_wow_moved()
        except Exception as e:
            print(f"[VirtualDesktop] Ошибка инициализации: {e}")

    def get_all_desktops(self):
        if not self.enabled:
            return []
        try:
            return pyvda.get_virtual_desktops()
        except Exception:
            return []

    def get_current_desktop(self):
        if not self.enabled:
            return None
        try:
            return pyvda.VirtualDesktop.current()
        except Exception:
            return None

    def get_wow_desktop(self):
        if not self.enabled:
            return None
        try:
            vds = self.get_all_desktops()
            # 1. Приоритет по имени 'wow'
            for v in vds:
                if (v.name or "").strip().lower() == "wow":
                    self.wow_desktop_id = v.id
                    self.wow_desktop_num = v.number
                    return v
            # 2. По сохраненному ID или номеру
            for v in vds:
                if (self.wow_desktop_id and v.id == self.wow_desktop_id) or (v.number == self.wow_desktop_num):
                    return v
            if vds:
                return vds[-1]
        except Exception:
            pass
        return None

    def ensure_wow_desktop_exists(self):
        if not self.enabled:
            return False
        try:
            vds = self.get_all_desktops()
            for v in vds:
                if (v.name or "").strip().lower() == "wow":
                    self.wow_desktop_id = v.id
                    self.wow_desktop_num = v.number
                    return True
            if len(vds) < 2:
                new_vd = pyvda.VirtualDesktop.create()
                try:
                    new_vd.rename("wow")
                except Exception:
                    pass
                self.wow_desktop_id = new_vd.id
                self.wow_desktop_num = new_vd.number
                return True
            else:
                for v in vds:
                    if v.number == 2 and (not v.name or not v.name.strip()):
                        try:
                            v.rename("wow")
                        except Exception:
                            pass
                        self.wow_desktop_id = v.id
                        self.wow_desktop_num = v.number
                        return True
                new_vd = pyvda.VirtualDesktop.create()
                try:
                    new_vd.rename("wow")
                except Exception:
                    pass
                self.wow_desktop_id = new_vd.id
                self.wow_desktop_num = new_vd.number
                return True
        except Exception as e:
            print(f"[VirtualDesktop] ensure_wow_desktop_exists: {e}")
            return False

    def ensure_wow_moved(self):
        """Находит окно World of Warcraft и переносит его на рабочий стол 'wow'."""
        if not self.enabled:
            return False
        try:
            hwnd = find_wow_hwnd()
            if hwnd and win32gui.IsWindow(hwnd):
                return self.move_window_to_wow_desktop(hwnd)
        except Exception as e:
            print(f"[VirtualDesktop] ensure_wow_moved: {e}")
        return False

    def is_wow_desktop_active(self):
        cur = self.get_current_desktop()
        if not cur:
            return True
        return cur.number == self.wow_desktop_num

    def is_window_on_wow_desktop(self, hwnd):
        if not self.enabled or not hwnd:
            return True
        try:
            attach_to_desktop()
            root_hwnd = win32gui.GetAncestor(hwnd, 2) or hwnd
            app = pyvda.AppView(hwnd=root_hwnd)
            return app.desktop.number == self.wow_desktop_num
        except Exception:
            return False

    def move_window_to_wow_desktop(self, hwnd):
        """Принудительно переносит окно на выделенный рабочий стол WoW"""
        if not self.enabled or not hwnd:
            return False
        try:
            attach_to_desktop()
            self.ensure_wow_desktop_exists()
            target_vd = self.get_wow_desktop()
            if not target_vd:
                return False
            root_hwnd = win32gui.GetAncestor(hwnd, 2) or hwnd
            app = pyvda.AppView(hwnd=root_hwnd)
            if app and app.desktop and app.desktop.number != target_vd.number:
                app.move(target_vd)
                print(f"[VirtualDesktop] Окно (HWND {root_hwnd}) перенесено на рабочий стол #{target_vd.number}")
                return True
        except Exception:
            pass
        return False

    def get_primary_desktop(self):
        """Возвращает основной рабочий стол Windows (#1)"""
        if not self.enabled:
            return None
        try:
            vds = self.get_all_desktops()
            for v in vds:
                if v.number == 1:
                    return v
            if vds:
                return vds[0]
        except Exception:
            pass
        return None

    def is_window_on_primary_desktop(self, hwnd):
        """Проверяет, находится ли окно на основном рабочем столе (#1)"""
        if not self.enabled or not hwnd:
            return True
        try:
            attach_to_desktop()
            root_hwnd = win32gui.GetAncestor(hwnd, 2) or hwnd
            app = pyvda.AppView(hwnd=root_hwnd)
            return app.desktop.number == 1
        except Exception:
            return False

    def move_window_to_primary_desktop(self, hwnd):
        """Принудительно переносит окно на основной рабочий стол (#1)"""
        if not self.enabled or not hwnd:
            return False
        try:
            attach_to_desktop()
            target_vd = self.get_primary_desktop()
            if not target_vd:
                return False
            root_hwnd = win32gui.GetAncestor(hwnd, 2) or hwnd
            app = pyvda.AppView(hwnd=root_hwnd)
            if app and app.desktop and app.desktop.number != target_vd.number:
                app.move(target_vd)
                print(f"[VirtualDesktop] Окно (HWND {root_hwnd}) перенесено на основной рабочий стол #{target_vd.number}")
                return True
        except Exception:
            pass
        return False

    def switch_to_wow(self, hwnd=None):
        """Переключает на рабочий стол WoW и активирует окно"""
        if not self.enabled:
            if hwnd and win32gui.IsWindow(hwnd):
                force_focus_window(hwnd)
            return
        try:
            cur = self.get_current_desktop()
            if cur and cur.number != self.wow_desktop_num:
                self.return_desktop_num = cur.number
            target_vd = self.get_wow_desktop()
            if target_vd:
                target_vd.go()
            time.sleep(0.12)
            if hwnd and win32gui.IsWindow(hwnd):
                force_focus_window(hwnd)
        except Exception as e:
            print(f"[VirtualDesktop] Ошибка switch_to_wow: {e}")

    def switch_to_return(self, hwnd=None):
        """Возвращает обратно на основной рабочий стол"""
        if not self.enabled:
            return
        try:
            vds = self.get_all_desktops()
            target_vd = None
            for v in vds:
                if v.number == self.return_desktop_num:
                    target_vd = v
                    break
            if not target_vd and vds:
                target_vd = vds[0] # Desktop 1
            if target_vd:
                target_vd.go()
            if hwnd and win32gui.IsWindow(hwnd):
                time.sleep(0.12)
                force_focus_window(hwnd)
        except Exception as e:
            print(f"[VirtualDesktop] Ошибка switch_to_return: {e}")

    def toggle_desktop(self, hwnd=None):
        """Мгновенно переключает туда-обратно между рабочим столом WoW и основным столом"""
        if not self.enabled:
            if hwnd and win32gui.IsWindow(hwnd):
                win32gui.ShowWindow(hwnd, 9)
                win32gui.SetForegroundWindow(hwnd)
            return
        try:
            cur = self.get_current_desktop()
            if not cur:
                return
            if cur.number == self.wow_desktop_num:
                self.switch_to_return()
            else:
                self.return_desktop_num = cur.number
                self.switch_to_wow(hwnd=hwnd)
        except Exception as e:
            print(f"[VirtualDesktop] Ошибка toggle_desktop: {e}")

# -------------------------------------------------------------
# Аппаратный ввод SendInput & Изолированный PostMessage
# -------------------------------------------------------------
PUL = ctypes.POINTER(ctypes.c_ulong)

class KeyBdInput(ctypes.Structure):
    _fields_ = [
        ("wVk", ctypes.c_ushort),
        ("wScan", ctypes.c_ushort),
        ("dwFlags", ctypes.c_ulong),
        ("time", ctypes.c_ulong),
        ("dwExtraInfo", PUL)
    ]

class HardwareInput(ctypes.Structure):
    _fields_ = [
        ("uMsg", ctypes.c_ulong),
        ("wParamL", ctypes.c_short),
        ("wParamH", ctypes.c_ushort)
    ]

class MouseInput(ctypes.Structure):
    _fields_ = [
        ("dx", ctypes.c_long),
        ("dy", ctypes.c_long),
        ("mouseData", ctypes.c_ulong),
        ("dwFlags", ctypes.c_ulong),
        ("time", ctypes.c_ulong),
        ("dwExtraInfo", PUL)
    ]

class Input_I(ctypes.Union):
    _fields_ = [
        ("ki", KeyBdInput),
        ("mi", MouseInput),
        ("hi", HardwareInput)
    ]

class Input(ctypes.Structure):
    _fields_ = [
        ("type", ctypes.c_ulong),
        ("ii", Input_I)
    ]

KEYEVENTF_SCANCODE = 0x0008
KEYEVENTF_KEYUP = 0x0002
SC_F12 = 0x58

def send_f12_key(hwnd, desktop_mgr=None, use_vdesk=True):
    """
    Мгновенный авто-перескок на рабочий стол WoW + тройной гарантированный клик (PostMessage Key + PostMessage Mouse + SendInput):
    1. Запоминает предыдущее активное окно и рабочий стол пользователя.
    2. Если пользователь на Столе #1 (или другом):
       - Мгновенно переключает экран на Стол #2 (WoW).
       - Фокусирует окно игры и физически нажимает клавишу F12 через аппаратный SendInput.
       - Сразу же возвращает пользователя обратно на исходный рабочий стол.
    3. Если пользователь УЖЕ на Столе #2:
       - Немедленно отправляет аппаратный клик и F12 без задержек.
    """
    if not hwnd or not win32gui.IsWindow(hwnd):
        return False

    attach_to_desktop()

    prev_fg_hwnd = None
    try:
        prev_fg_hwnd = win32gui.GetForegroundWindow()
    except Exception:
        pass

    need_return = False
    return_desk_num = 1

    if use_vdesk and desktop_mgr and desktop_mgr.enabled:
        try:
            cur_desk = desktop_mgr.get_current_desktop()
            if cur_desk and cur_desk.number != desktop_mgr.wow_desktop_num:
                need_return = True
                return_desk_num = cur_desk.number
                desktop_mgr.switch_to_wow(hwnd=hwnd)
                time.sleep(0.08)
        except Exception as e:
            print(f"[AutoHop] Ошибка переключения на стол WoW: {e}")

    try:
        if win32gui.IsIconic(hwnd):
            win32gui.ShowWindow(hwnd, 9) # SW_RESTORE
            time.sleep(0.05)
        cur_fore = win32gui.GetForegroundWindow()
        if cur_fore != hwnd:
            fore_tid, _ = win32process.GetWindowThreadProcessId(cur_fore)
            my_tid = win32api.GetCurrentThreadId()
            if fore_tid and fore_tid != my_tid:
                win32process.AttachThreadInput(my_tid, fore_tid, True)
                win32gui.SetForegroundWindow(hwnd)
                win32gui.BringWindowToTop(hwnd)
                win32process.AttachThreadInput(my_tid, fore_tid, False)
            else:
                win32gui.SetForegroundWindow(hwnd)
                win32gui.BringWindowToTop(hwnd)
        else:
            win32gui.SetForegroundWindow(hwnd)
    except Exception:
        pass

    if need_return:
        time.sleep(0.35)
    else:
        time.sleep(0.12)

    # 1. Прямой Win32 PostMessage (F12 KeyDown / KeyUp) прямо в очередь сообщений окна WoW
    WM_KEYDOWN = 0x0100
    WM_KEYUP = 0x0101
    VK_F12 = 0x7B
    SC_F12 = 0x58
    lparam_down = 1 | (SC_F12 << 16)
    lparam_up = 1 | (SC_F12 << 16) | (1 << 30) | (1 << 31)
    try:
        win32gui.PostMessage(hwnd, WM_KEYDOWN, VK_F12, lparam_down)
        win32gui.PostMessage(hwnd, WM_KEYUP, VK_F12, lparam_up)
    except Exception as e:
        print(f"[PostMessage Key Error] {e}")

    # 2. Клик мыши полностью отключен по требованию (только аппаратный F12)

    # 3. Аппаратный физический ввод SendInput с виртуальным кодом VK_F12 и ScanCode F12
    user32 = ctypes.windll.user32
    extra = ctypes.c_ulong(0)
    ii_down = Input_I()
    ii_down.ki = KeyBdInput(VK_F12, SC_F12, 0, 0, ctypes.pointer(extra))
    down_input = Input(ctypes.c_ulong(1), ii_down)
    user32.SendInput(1, ctypes.pointer(down_input), ctypes.sizeof(down_input))

    time.sleep(random.uniform(0.040, 0.055))

    ii_up = Input_I()
    ii_up.ki = KeyBdInput(VK_F12, SC_F12, KEYEVENTF_KEYUP, 0, ctypes.pointer(extra))
    up_input = Input(ctypes.c_ulong(1), ii_up)
    user32.SendInput(1, ctypes.pointer(up_input), ctypes.sizeof(up_input))

    if need_return and use_vdesk and desktop_mgr and desktop_mgr.enabled:
        time.sleep(0.18)
        try:
            vds = desktop_mgr.get_all_desktops()
            target_vd = None
            for v in vds:
                if v.number == return_desk_num:
                    target_vd = v
                    break
            if not target_vd and vds:
                target_vd = vds[0]
            if target_vd:
                target_vd.go()
            time.sleep(0.05)
            if prev_fg_hwnd and win32gui.IsWindow(prev_fg_hwnd):
                win32gui.SetForegroundWindow(prev_fg_hwnd)
        except Exception as e:
            print(f"[AutoHop] Ошибка возврата на исходный стол: {e}")

    return True

# -------------------------------------------------------------
# Чтение цвета через PrintWindow (Фоновый замер на другом столе)
# -------------------------------------------------------------
def sample_pixel_from_printwindow(hwnd, client_x, client_y):
    """Считывает точный цвет пикселя из DirectX-буфера окна WoW (PW_RENDERFULLCONTENT)"""
    try:
        if not hwnd or not win32gui.IsWindow(hwnd):
            return None
        crect = win32gui.GetClientRect(hwnd)
        w = crect[2] - crect[0]
        h = crect[3] - crect[1]
        if w <= 0 or h <= 0:
            return None

        # Преобразуем координаты клиента в буфер окна PrintWindow (учитываем неклиентские рамки и заголовок)
        wrect = win32gui.GetWindowRect(hwnd)
        c0 = win32gui.ClientToScreen(hwnd, (0, 0))
        off_x = max(0, c0[0] - wrect[0])
        off_y = max(0, c0[1] - wrect[1])

        buf_x = client_x + off_x
        buf_y = client_y + off_y

        import win32ui
        user32 = ctypes.windll.user32
        hwndDC = win32gui.GetWindowDC(hwnd)
        if not hwndDC:
            return None
        mfcDC = win32ui.CreateDCFromHandle(hwndDC)
        saveDC = mfcDC.CreateCompatibleDC()
        saveBitMap = win32ui.CreateBitmap()
        saveBitMap.CreateCompatibleBitmap(mfcDC, w, h)
        saveDC.SelectObject(saveBitMap)

        PW_RENDERFULLCONTENT = 2
        res = user32.PrintWindow(hwnd, saveDC.GetSafeHdc(), PW_RENDERFULLCONTENT)
        if not res:
            win32gui.DeleteObject(saveBitMap.GetHandle())
            saveDC.DeleteDC()
            mfcDC.DeleteDC()
            win32gui.ReleaseDC(hwnd, hwndDC)
            return None

        bmpstr = saveBitMap.GetBitmapBits(True)
        win32gui.DeleteObject(saveBitMap.GetHandle())
        saveDC.DeleteDC()
        mfcDC.DeleteDC()
        win32gui.ReleaseDC(hwnd, hwndDC)

        offset = (buf_y * w + buf_x) * 4
        if offset + 2 >= len(bmpstr):
            return None
        b = bmpstr[offset]
        g = bmpstr[offset + 1]
        r = bmpstr[offset + 2]
        return (r, g, b)
    except Exception:
        return None

# -------------------------------------------------------------
# OpenCV: Сканирование всего экрана и поиск оптического контейнера (100% точность)
# -------------------------------------------------------------
def capture_full_window_bgr(hwnd):
    """Захватывает полное изображение клиентской области окна WoW в формате OpenCV BGR"""
    try:
        if not hwnd or not win32gui.IsWindow(hwnd):
            return None
        rect = win32gui.GetClientRect(hwnd)
        w = rect[2] - rect[0]
        h = rect[3] - rect[1]
        if w <= 100 or h <= 100:
            return None

        import win32ui
        user32 = ctypes.windll.user32
        hwndDC = win32gui.GetWindowDC(hwnd)
        if not hwndDC:
            return None
        mfcDC = win32ui.CreateDCFromHandle(hwndDC)
        saveDC = mfcDC.CreateCompatibleDC()
        saveBitMap = win32ui.CreateBitmap()
        saveBitMap.CreateCompatibleBitmap(mfcDC, w, h)
        saveDC.SelectObject(saveBitMap)

        PW_RENDERFULLCONTENT = 2
        res = user32.PrintWindow(hwnd, saveDC.GetSafeHdc(), PW_RENDERFULLCONTENT)
        if not res:
            win32gui.DeleteObject(saveBitMap.GetHandle())
            saveDC.DeleteDC()
            mfcDC.DeleteDC()
            win32gui.ReleaseDC(hwnd, hwndDC)
            return None

        bmpinfo = saveBitMap.GetInfo()
        bmpstr = saveBitMap.GetBitmapBits(True)
        win32gui.DeleteObject(saveBitMap.GetHandle())
        saveDC.DeleteDC()
        mfcDC.DeleteDC()
        win32gui.ReleaseDC(hwnd, hwndDC)

        full_bgr = np.frombuffer(bmpstr, dtype=np.uint8).reshape((bmpinfo['bmHeight'], bmpinfo['bmWidth'], 4))[:, :, :3]
        return full_bgr
    except Exception as e:
        print(f"[OpenCV Capture] Ошибка захвата окна: {e}")
        return None

def scan_for_container_marker(full_img_bgr, texture_path=TEXTURE_CONTAINER_PATH):
    """
    Поиск оптического контейнера аддона на всем окне через OpenCV (100% точность):
    - Находит уникальный 32x32 контейнер (kar_container.png)
    - Возвращает координаты центра (X, Y) и уверенность (confidence)
    """
    if full_img_bgr is None:
        return None, "Пустое изображение окна"

    if not os.path.exists(texture_path):
        alt_paths = [
            os.path.join(BASE_DIR, "Textures", "kar_container.png"),
            os.path.join(SCRIPT_DIR, "kar_container.png"),
            r"C:\Firestorm\The War Within\_midnight_\Interface\AddOns\KeyAutoRecruit\Textures\kar_container.png",
            r"c:\soft\6\Textures\kar_container.png",
            r"C:\Users\root\Desktop\WoW_AutoRecruit\Textures\kar_container.png"
        ]
        for ap in alt_paths:
            if os.path.exists(ap):
                texture_path = ap
                break

    if not os.path.exists(texture_path):
        return None, "Файл текстуры kar_container.png не найден"

    tmpl_rgba = cv2.imread(texture_path, cv2.IMREAD_UNCHANGED)
    if tmpl_rgba is None or len(tmpl_rgba.shape) < 3 or tmpl_rgba.shape[2] != 4:
        return None, "Некорректный формат текстуры (требуется RGBA)"

    tmpl_bgr = tmpl_rgba[:, :, :3]
    alpha_mask = tmpl_rgba[:, :, 3]

    t0 = time.perf_counter()
    # 1. Основной проход: сопоставление по маске ободка (100% точность при любых цветах центра)
    res = cv2.matchTemplate(full_img_bgr, tmpl_bgr, cv2.TM_CCORR_NORMED, mask=alpha_mask)
    np.nan_to_num(res, copy=False)
    min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(res)

    # 2. Если уверенность < 0.95, выполняем контрольный проход полного сопоставления
    if max_val < 0.95:
        res2 = cv2.matchTemplate(full_img_bgr, tmpl_bgr, cv2.TM_CCOEFF_NORMED)
        np.nan_to_num(res2, copy=False)
        _, max_val2, _, max_loc2 = cv2.minMaxLoc(res2)
        if max_val2 > max_val:
            max_val = max_val2
            max_loc = max_loc2

    elapsed_ms = (time.perf_counter() - t0) * 1000

    found_x, found_y = max_loc
    conf = float(max_val)
    center_x = found_x + tmpl_bgr.shape[1] // 2
    center_y = found_y + tmpl_bgr.shape[0] // 2

    return {
        "found": conf >= 0.85,
        "x": center_x,
        "y": center_y,
        "box_x": found_x,
        "box_y": found_y,
        "box_w": tmpl_bgr.shape[1],
        "box_h": tmpl_bgr.shape[0],
        "confidence": conf,
        "elapsed_ms": elapsed_ms
    }, None

def is_autorun_enabled():
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_RUN_KEY, 0, winreg.KEY_READ) as key:
            winreg.QueryValueEx(key, REG_RUN_NAME)
            return True
    except FileNotFoundError:
        return False
    except Exception:
        return False

def set_autorun(enable=True):
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, REG_RUN_KEY, 0, winreg.KEY_SET_VALUE) as key:
            if enable:
                target_exe = os.path.join(SCRIPT_DIR, "WoWSmartRecruiter.exe")
                if os.path.exists(target_exe):
                    cmd = f'"{target_exe}" --silent'
                else:
                    target_script = os.path.join(SCRIPT_DIR, "wow_voice_clicker.py")
                    cmd = f'"{PYTHONW_EXE}" "{target_script}" --silent'
                winreg.SetValueEx(key, REG_RUN_NAME, 0, winreg.REG_SZ, cmd)
            else:
                try:
                    winreg.DeleteValue(key, REG_RUN_NAME)
                except FileNotFoundError:
                    pass
        return True
    except Exception as e:
        print(f"[Автозагрузка] Ошибка реестра: {e}")
        return False

# -------------------------------------------------------------
# Всплывающее меню переключения рабочих столов (NumPad 4)
# -------------------------------------------------------------

# -------------------------------------------------------------
# HELLSING HTML/CSS UI & HTTP SERVER
# -------------------------------------------------------------
HTTP_PORT = 49286
HELLSING_HTML_PATH = os.path.join(SCRIPT_DIR, "hellsing_ui.html")

def get_hellsing_html_bytes():
    candidates = [
        HELLSING_HTML_PATH,
        os.path.join(getattr(sys, '_MEIPASS', ''), 'hellsing_ui.html'),
        os.path.join(BASE_DIR, 'hellsing_ui.html'),
        os.path.join(SCRIPT_DIR, 'hellsing_ui.html'),
        os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "WoWSmartRecruiter", "hellsing_ui.html"),
        os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "WoWSmartRecruiter", "hellsing_ui.html"),
        r"c:\soft\6\hellsing_ui.html"
    ]
    for c in candidates:
        if c and os.path.isfile(c):
            try:
                with open(c, "r", encoding="utf-8") as f:
                    content = f.read()
                    if len(content) > 100:
                        return content.encode("utf-8")
            except Exception:
                pass
    # Fallback to embedded minimal if file not found
    return b'''<!DOCTYPE html><html><head><title>HELLSING</title></head><body style="background:#060508;color:#d4af37;"><h1>HELLSING RECRUITER</h1></body></html>'''

class HellsingThreadingServer(ThreadingHTTPServer):
    daemon_threads = True

class HellsingHttpHandler(BaseHTTPRequestHandler):
    app_instance = None # Set by RecruiterServiceApp

    def log_message(self, format, *args):
        pass # Silent

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            html_data = get_hellsing_html_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html_data)))
            self.end_headers()
            self.wfile.write(html_data)
        elif self.path == "/api/status":
            app = HellsingHttpHandler.app_instance
            data = app.get_api_status() if app else {}
            body = json.dumps(data).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/api/action":
            content_len = int(self.headers.get("Content-Length", 0))
            raw_body = self.rfile.read(content_len).decode("utf-8")
            try:
                data = json.loads(raw_body)
            except Exception:
                data = {}
            act = data.get("action")
            app = HellsingHttpHandler.app_instance
            if app:
                app.handle_api_action(act, data)
                res_data = app.get_api_status()
            else:
                res_data = {}

            body = json.dumps({"ok": True, "state": res_data}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404)
            self.end_headers()

class DesktopSwitcherMenu:
    """Всплывающее меню переключения рабочих столов (NumPad 4)"""
    def __init__(self, parent_app):
        self.app = parent_app

    def toggle(self):
        self.app.toggle_gui()

    def show(self):
        self.app.show_gui()

    def hide(self):
        self.app.hide_gui()

    def action_go_wow(self):
        hwnd = find_wow_hwnd()
        if not getattr(self.app, 'use_virtual_desktop', True):
            if hwnd and win32gui.IsWindow(hwnd):
                force_focus_window(hwnd)
            return
        self.app.desktop_mgr.switch_to_wow(hwnd)

    def action_go_back(self):
        self.app.desktop_mgr.switch_to_return()

    def action_launch_wow(self):
        self.app.launch_or_restart_wow()

    def action_force_move(self):
        hwnd = find_wow_hwnd()
        if not hwnd:
            return
        if not getattr(self.app, 'use_virtual_desktop', True):
            self.app.desktop_mgr.move_window_to_primary_desktop(hwnd)
            return
        self.app.desktop_mgr.move_window_to_wow_desktop(hwnd)

# -------------------------------------------------------------# -------------------------------------------------------------
# Главное приложение сервиса (RecruiterServiceApp)
# -------------------------------------------------------------
class RecruiterServiceApp:
    def __init__(self):
        self.is_active = True
        self.calibrating = False
        self.running = True
        self.last_press_time = 0
        self.last_toggle_time = 0
        self.last_f11_time = 0
        self.last_num5_time = 0
        self.last_num4_time = 0
        self.press_count = 0
        self.last_event_text = "Ожидание событий..."
        self.current_event_type = None
        self.current_role = None
        self.last_full_time = 0

        # Координаты центра контейнера относительно клиента WoW (по умолчанию центр 32x32 контейнера)
        self.client_x = 20
        self.client_y = 20
        self.target_r = 0
        self.target_g = 255
        self.target_b = 0

        self.current_screen_xy = (0, 0)
        self.current_sampled_rgb = (0, 0, 0)

        # Менеджер виртуальных столов и настройка изоляции
        self.use_virtual_desktop = True
        self.desktop_mgr = VirtualDesktopManager(auto_move=False)

        # Пути к WoW
        self.wow_root_dir = ""
        self.wow_exe_path = ""
        self.wow_log_path = WOW_LOG_PATH

        self.load_config()

        attach_to_desktop()

        # Применяем режим рабочего стола сразу при старте (с авто-переносом игры)
        hwnd = find_wow_hwnd()
        if hwnd and win32gui.IsWindow(hwnd):
            if not self.use_virtual_desktop:
                self.desktop_mgr.move_window_to_primary_desktop(hwnd)
            else:
                self.desktop_mgr.ensure_wow_moved()

        # Инициализация графических меню
        # Инициализация Hellsing HTML/CSS HTTP Сервера и Edge App UI
        self.edge_hwnd = None
        self.init_gui()
        self.switcher_menu = None
        self.last_auto_scan_time = 0

        # Глобальные горячие клавиши через нативный Win32 API (RegisterHotKey, без хуков/keylogger)
        self.start_hotkeys_listener()

        # Фоновый поток: Чтение лога WoWChatLog.txt
        self.log_thread = threading.Thread(target=self.watch_chat_log, daemon=True)
        self.log_thread.start()

        # Фоновый поток: Основной цикл рекрутера и изоляции
        self.last_opencv_conf = 0.0
        self.last_opencv_ms = 0.0

        # Автоматический первичный поиск контейнера через OpenCV через 1.5 сек после старта
        def _initial_opencv_scan():
            time.sleep(1.5)
            self.run_opencv_full_scan()
        threading.Thread(target=_initial_opencv_scan, daemon=True).start()

        self.worker_thread = threading.Thread(target=self.recruiter_worker_loop, daemon=True)
        self.worker_thread.start()

    def load_config(self):
        if os.path.exists(CONFIG_PATH):
            try:
                with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    self.client_x = data.get("client_x", self.client_x)
                    self.client_y = data.get("client_y", self.client_y)
                    self.target_r = data.get("target_r", self.target_r)
                    self.target_g = data.get("target_g", self.target_g)
                    self.target_b = data.get("target_b", self.target_b)
                    self.wow_root_dir = data.get("wow_root_dir", self.wow_root_dir)
                    self.wow_exe_path = data.get("wow_exe_path", self.wow_exe_path)
                    self.wow_log_path = data.get("wow_log_path", self.wow_log_path)
                    self.use_virtual_desktop = data.get("use_virtual_desktop", self.use_virtual_desktop)
            except Exception as e:
                print(f"[Конфиг] Ошибка чтения config: {e}")

        if not self.wow_exe_path:
            self.wow_exe_path = get_wow_executable_path() or ""
        if not self.wow_log_path:
            self.wow_log_path = WOW_LOG_PATH

    def save_config(self):
        try:
            data = {
                "client_x": self.client_x,
                "client_y": self.client_y,
                "target_r": self.target_r,
                "target_g": self.target_g,
                "target_b": self.target_b,
                "wow_root_dir": self.wow_root_dir,
                "wow_exe_path": self.wow_exe_path,
                "wow_log_path": self.wow_log_path,
                "wow_desktop_num": self.desktop_mgr.wow_desktop_num,
                "use_virtual_desktop": self.use_virtual_desktop,
                "saved_at": time.strftime("%Y-%m-%d %H:%M:%S")
            }
            with open(CONFIG_PATH, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=4, ensure_ascii=False)
        except Exception as e:
            print(f"[Конфиг] Ошибка записи config: {e}")

    def is_window_cloaked(self, hwnd):
        """Проверяет через DWM, скрыто ли окно (DWMWA_CLOAKED)"""
        try:
            cloaked = ctypes.c_int(0)
            res = ctypes.windll.dwmapi.DwmGetWindowAttribute(hwnd, 14, ctypes.byref(cloaked), ctypes.sizeof(cloaked))
            return (res == 0 and cloaked.value != 0)
        except Exception:
            return False

    def check_wow_state(self):
        """
        Проверяет статус процесса WoW, геометрию и рабочий стол.
        Возвращает: is_running, state_code, desc, hwnd, rect
        """
        attach_to_desktop()
        hwnd = find_wow_hwnd()

        if not hwnd or not win32gui.IsWindow(hwnd):
            return False, "NOT_FOUND", "Игра не запущена (ожидание процесса WoW...)", 0, None

        # 1. Проверка классического сворачивания в панель задач (IsIconic)
        if win32gui.IsIconic(hwnd):
            return False, "MINIMIZED", "Окно WoW свернуто в панель задач (пауза)", hwnd, None

        # 2. Проверка геометрии окна
        rect = win32gui.GetWindowRect(hwnd)
        w = rect[2] - rect[0]
        h = rect[3] - rect[1]
        if w <= 150 or h <= 150:
            return False, "COLLAPSED", f"Окно свернуто до размера {w}x{h}", hwnd, rect

        # 3. Проверка виртуального рабочего стола
        if self.use_virtual_desktop:
            is_on_wow_desk = self.desktop_mgr.is_window_on_wow_desktop(hwnd)
            is_wow_desk_active = self.desktop_mgr.is_wow_desktop_active()

            # Если окно скрыто DWM потому что пользователь на другом рабочем столе:
            if self.is_window_cloaked(hwnd):
                if is_on_wow_desk and not is_wow_desk_active:
                    return True, "DEDICATED_BACKGROUND", f"Работает на столе #{self.desktop_mgr.wow_desktop_num} (Фон)", hwnd, rect
                return False, "MINIMIZED", "Окно WoW свернуто / скрыто", hwnd, None

            if not win32gui.IsWindowVisible(hwnd):
                return False, "HIDDEN", "Окно WoW скрыто", hwnd, None

            return True, "RESTORED", f"Развернут ({w}x{h} | Стол #{self.desktop_mgr.wow_desktop_num} | HWND: {hwnd})", hwnd, rect
        else:
            is_on_primary = self.desktop_mgr.is_window_on_primary_desktop(hwnd)
            desk_str = "Основной стол #1" if is_on_primary else f"Стол #{getattr(self.desktop_mgr.get_current_desktop(), 'number', 1)}"
            if self.is_window_cloaked(hwnd):
                return False, "MINIMIZED", "Окно WoW свернуто / скрыто", hwnd, None
            if not win32gui.IsWindowVisible(hwnd):
                return False, "HIDDEN", "Окно WoW скрыто", hwnd, None
            return True, "RESTORED", f"Развернут ({w}x{h} | {desk_str} | HWND: {hwnd})", hwnd, rect

    def start_hotkeys_listener(self):
        """Регистрирует глобальные системные горячие клавиши Windows (RegisterHotKey API) без хуков клавиатуры"""
        def _loop():
            import ctypes.wintypes
            user32 = ctypes.windll.user32
            MOD_NOREPEAT = 0x4000

            HK_NUMPAD4 = 1
            HK_NUMPAD5 = 2
            HK_NUMPAD1 = 3
            HK_F11 = 4

            VK_NUMPAD4 = 0x64
            VK_NUMPAD5 = 0x65
            VK_NUMPAD1 = 0x61
            VK_F11 = 0x7A

            user32.RegisterHotKey(None, HK_NUMPAD4, MOD_NOREPEAT, VK_NUMPAD4)
            user32.RegisterHotKey(None, HK_NUMPAD5, MOD_NOREPEAT, VK_NUMPAD5)
            user32.RegisterHotKey(None, HK_NUMPAD1, MOD_NOREPEAT, VK_NUMPAD1)
            user32.RegisterHotKey(None, HK_F11, MOD_NOREPEAT, VK_F11)

            msg = ctypes.wintypes.MSG()
            while self.running:
                if user32.GetMessageW(ctypes.byref(msg), None, 0, 0) != 0:
                    if msg.message == 0x0312: # WM_HOTKEY
                        hk_id = msg.wParam
                        cur_t = time.time()
                        if hk_id == HK_NUMPAD4:
                            if cur_t - self.last_num4_time > 0.35:
                                self.last_num4_time = cur_t
                                self.toggle_desktop()
                        elif hk_id == HK_NUMPAD5:
                            if cur_t - self.last_num5_time > 0.35:
                                self.last_num5_time = cur_t
                                self.toggle_gui()
                        elif hk_id == HK_NUMPAD1:
                            if cur_t - self.last_toggle_time > 0.35:
                                self.last_toggle_time = cur_t
                                self.toggle_active_state()
                        elif hk_id == HK_F11:
                            if cur_t - self.last_f11_time > 0.4:
                                self.last_f11_time = cur_t
                                self.handle_f11()
                    user32.TranslateMessage(ctypes.byref(msg))
                    user32.DispatchMessageW(ctypes.byref(msg))

            user32.UnregisterHotKey(None, HK_NUMPAD4)
            user32.UnregisterHotKey(None, HK_NUMPAD5)
            user32.UnregisterHotKey(None, HK_NUMPAD1)
            user32.UnregisterHotKey(None, HK_F11)

        threading.Thread(target=_loop, daemon=True).start()

    def on_global_key(self, event):
        cur_t = time.time()

        # NumPad 4: скан-код 75 (0x4B) -> Меню переключения рабочих столов WoW
        is_numpad_4 = (
            event.scan_code in (75, 0x4B) or 
            event.name in ('num 4', 'numpad 4', 'left') or
            (getattr(event, 'is_keypad', False) and str(event.name) in ('4', 'num 4', 'left'))
        )
        if is_numpad_4:
            if cur_t - self.last_num4_time > 0.35:
                self.last_num4_time = cur_t
                self.toggle_desktop()
            return

        # NumPad 5: скан-код 76 (0x4C) -> Открыть / скрыть главную панель
        is_numpad_5 = (
            event.scan_code in (76, 0x4C) or 
            event.name in ('num 5', 'numpad 5', 'clear') or
            (getattr(event, 'is_keypad', False) and str(event.name) in ('5', 'num 5', 'clear'))
        )
        if is_numpad_5:
            if cur_t - self.last_num5_time > 0.35:
                self.last_num5_time = cur_t
                self.toggle_gui()
            return

        # NumPad 1: скан-код 79 (0x4F) -> Пауза / включение
        is_numpad_1 = (
            event.scan_code in (79, 0x4F) or 
            event.name in ('num 1', 'numpad 1', 'end') or
            (getattr(event, 'is_keypad', False) and str(event.name) in ('1', 'num 1', 'end'))
        )
        if is_numpad_1:
            if cur_t - self.last_toggle_time > 0.35:
                self.last_toggle_time = cur_t
                self.toggle_active_state()
            return

        # F11: запуск / фиксация ручной калибровки пикселя курсором мыши
        if event.name == 'f11' or event.scan_code == 87:
            if cur_t - self.last_f11_time > 0.4:
                self.last_f11_time = cur_t
                self.handle_f11()

    def toggle_desktop(self):
        """Мгновенно переключает рабочий стол туда-обратно (WoW <-> Основной) или фокусирует WoW"""
        hwnd = find_wow_hwnd()
        if not self.use_virtual_desktop:
            if hwnd and win32gui.IsWindow(hwnd):
                try:
                    if win32gui.IsIconic(hwnd):
                        win32gui.ShowWindow(hwnd, 9)
                    win32gui.SetForegroundWindow(hwnd)
                except Exception:
                    pass
            return
        self.desktop_mgr.toggle_desktop(hwnd=hwnd)

    def toggle_switcher_menu(self):
        if self.switcher_menu:
            self.switcher_menu.toggle()

    def toggle_active_state(self):
        self.is_active = not self.is_active
        status_text = "ВКЛЮЧЕН" if self.is_active else "НА ПАУЗЕ"
        print(f"\n[{time.strftime('%H:%M:%S')}] >>> [NumPad 1] Авто-набор: {status_text}")
        self.update_gui_status()

    def get_root_hwnd(self):
        try:
            return self.find_edge_ui_hwnd()
        except Exception:
            return None

    def ensure_gui_on_wow_desktop(self):
        pass

    def launch_edge_ui(self):
        """Запускает отдельное окно интерфейса Hellsing с защитой от блокировки профиля и фоллбэком"""
        user_data = os.path.join(os.environ.get("LOCALAPPDATA", "."), "WoWSmartRecruiter", "HellsingProfile")
        try:
            os.makedirs(user_data, exist_ok=True)
            lock_f = os.path.join(user_data, "lockfile")
            if os.path.exists(lock_f):
                try: os.remove(lock_f)
                except Exception: pass
        except Exception:
            pass

        # Очистка зомби-процессов Edge, державших профиль без окон
        try:
            for p in psutil.process_iter(['pid', 'name', 'cmdline']):
                if p.info['name'] and 'msedge' in p.info['name'].lower():
                    cmdline = p.info.get('cmdline') or []
                    if any('HellsingProfile' in arg for arg in cmdline):
                        try: p.kill()
                        except Exception: pass
        except Exception:
            pass

        edge_paths = [
            r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"
        ]
        edge_exe = None
        for ep in edge_paths:
            if os.path.exists(ep):
                edge_exe = ep
                break

        launched = False
        if edge_exe:
            cmd = [
                edge_exe,
                f"--app=http://127.0.0.1:{HTTP_PORT}/",
                f"--user-data-dir={user_data}",
                "--window-size=550,880",
                "--no-first-run",
                "--no-default-browser-check"
            ]
            try:
                p = subprocess.Popen(cmd)
                time.sleep(0.6)
                if p.poll() is None or p.poll() == 0:
                    launched = True
            except Exception as e:
                print(f"[HellsingUI] Ошибка запуска Edge: {e}")

        # Фоллбэк 1: Google Chrome в режиме приложения
        if not launched:
            chrome_exe = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
            if not os.path.exists(chrome_exe):
                chrome_exe = r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
            if os.path.exists(chrome_exe):
                try:
                    c_user_data = os.path.join(os.environ.get("LOCALAPPDATA", "."), "WoWSmartRecruiter", "ChromeProfile")
                    cmd_c = [
                        chrome_exe,
                        f"--app=http://127.0.0.1:{HTTP_PORT}/",
                        f"--user-data-dir={c_user_data}",
                        "--window-size=550,880",
                        "--no-first-run"
                    ]
                    p = subprocess.Popen(cmd_c)
                    time.sleep(0.6)
                    launched = True
                except Exception as e:
                    print(f"[HellsingUI] Ошибка запуска Chrome: {e}")

        # Фоллбэк 2: Системный браузер по умолчанию
        if not launched:
            try:
                webbrowser.open(f"http://127.0.0.1:{HTTP_PORT}/")
                launched = True
            except Exception as e:
                print(f"[HellsingUI] Ошибка запуска системного браузера: {e}")

        time.sleep(0.5)
        self.find_edge_ui_hwnd()

    def find_edge_ui_hwnd(self):
        if self.edge_hwnd and win32gui.IsWindow(self.edge_hwnd):
            return self.edge_hwnd
        found_h = []
        def cb(h, extra):
            if win32gui.IsWindow(h):
                try:
                    t = win32gui.GetWindowText(h).lower()
                    c = win32gui.GetClassName(h).lower()
                    if ("hellsing" in t or "mythic+" in t or "49286" in t) and ("chrome_widgetwin" in c or "applicationframe" in c or "ieframe" in c):
                        found_h.append(h)
                except Exception:
                    pass
            return True
        try:
            win32gui.EnumWindows(cb, None)
        except Exception:
            pass
        if found_h:
            self.edge_hwnd = found_h[0]
            return self.edge_hwnd
        return None

    def show_gui(self):
        """Отображает окно интерфейса на текущем активном столе пользователя"""
        h = self.find_edge_ui_hwnd()
        if not h or not win32gui.IsWindow(h):
            self.launch_edge_ui()
            def _deferred_focus():
                time.sleep(0.8)
                nh = self.find_edge_ui_hwnd()
                if nh and win32gui.IsWindow(nh):
                    self._focus_window(nh)
            threading.Thread(target=_deferred_focus, daemon=True).start()
            return
        self._focus_window(h)

    def _focus_window(self, h):
        try:
            if self.desktop_mgr.enabled and pyvda:
                cur_vd = self.desktop_mgr.get_current_desktop()
                if cur_vd:
                    try:
                        app = pyvda.AppView(h)
                        if app.desktop.number != cur_vd.number:
                            app.move(cur_vd)
                    except Exception:
                        pass
            win32gui.ShowWindow(h, 9) # SW_RESTORE
            win32gui.BringWindowToTop(h)
            win32gui.SetForegroundWindow(h)
            force_focus_window(h)
        except Exception as e:
            print(f"[HellsingUI] Ошибка show_gui: {e}")

    def hide_gui(self):
        h = self.find_edge_ui_hwnd()
        if h and win32gui.IsWindow(h):
            win32gui.ShowWindow(h, 6) # SW_MINIMIZE

    def toggle_gui(self):
        h = self.find_edge_ui_hwnd()
        if h and win32gui.IsWindow(h):
            fg = win32gui.GetForegroundWindow()
            if fg == h:
                self.hide_gui()
            else:
                self.show_gui()
        else:
            self.show_gui()

    def toggle_desktop(self):
        hwnd = find_wow_hwnd()
        if not self.use_virtual_desktop:
            if hwnd and win32gui.IsWindow(hwnd):
                force_focus_window(hwnd)
            return
        self.desktop_mgr.toggle_desktop(hwnd=hwnd)

    def toggle_switcher_menu(self):
        self.toggle_gui()

    def toggle_active_state(self):
        self.is_active = not self.is_active
        status_text = "ВКЛЮЧЕН" if self.is_active else "НА ПАУЗЕ"
        print(f"\n[{time.strftime('%H:%M:%S')}] >>> [NumPad 1] Авто-набор: {status_text}")
        speak(f"Авто-набор {status_text.lower()}")

    def get_root_hwnd(self):
        return self.find_edge_ui_hwnd()

    def get_api_status(self):
        """Возвращает состояние для опроса через REST API веб-интерфейсом Hellsing"""
        is_running, state, desc, hwnd, rect = self.check_wow_state()
        cur_vd = self.desktop_mgr.get_current_desktop()
        cur_num = cur_vd.number if cur_vd else 1
        vds_count = len(self.desktop_mgr.get_all_desktops()) if self.desktop_mgr.enabled else 1
        r, g, b = self.current_sampled_rgb
        hex_c = f"#{r:02x}{g:02x}{b:02x}"
        return {
            "is_active": self.is_active,
            "running": self.running,
            "use_virtual_desktop": self.use_virtual_desktop,
            "current_desktop": cur_num,
            "wow_desktop": self.desktop_mgr.wow_desktop_num,
            "desktops_count": vds_count,
            "wow_running": is_running,
            "wow_state": state,
            "wow_desc": desc,
            "client_x": self.client_x,
            "client_y": self.client_y,
            "opencv_confidence": getattr(self, "last_opencv_conf", 0.0),
            "opencv_ms": getattr(self, "last_opencv_ms", 0.0),
            "current_rgb": [r, g, b],
            "current_hex": hex_c,
            "event_type": self.current_event_type,
            "role": self.current_role,
            "press_count": self.press_count,
            "last_event_text": self.last_event_text,
            "autorun": is_autorun_enabled()
        }

    def handle_api_action(self, action, data):
        """Обрабатывает действия от веб-кнопок Hellsing"""
        if action == "toggle_active":
            self.toggle_active_state()
        elif action == "toggle_single_desktop":
            self.toggle_single_desktop_mode()
        elif action == "switch_to_wow":
            self.desktop_mgr.switch_to_wow(find_wow_hwnd())
        elif action == "switch_to_return":
            self.desktop_mgr.switch_to_return()
        elif action == "toggle_desktop":
            self.toggle_desktop()
        elif action == "set_coords":
            self.client_x = int(data.get("x", self.client_x))
            self.client_y = int(data.get("y", self.client_y))
            self.save_config()
            print(f"[{time.strftime('%H:%M:%S')}] >>> Координаты сохранены: X={self.client_x}, Y={self.client_y}")
        elif action == "reset_coords":
            self.client_x = 20
            self.client_y = 20
            self.save_config()
            print(f"[{time.strftime('%H:%M:%S')}] >>> Координаты сброшены в эталон (20, 20)")
        elif action == "scan_opencv":
            self.run_opencv_full_scan()
        elif action == "start_f11":
            self.handle_f11()
        elif action == "test_audio":
            self.play_role_alert("FULL")
        elif action == "toggle_autorun":
            set_autorun(bool(data.get("enabled", True)))
        elif action == "minimize":
            self.hide_gui()
        elif action == "exit":
            self.stop_service()

    def run_opencv_full_scan(self):
        """Сканирование всего окна WoW через OpenCV и автоматическая фиксация координат контейнера (100% точность)"""
        is_running, state, desc, hwnd, rect = self.check_wow_state()
        if not is_running or not hwnd:
            msg = "WoW не запущен или свернут!"
            print(f"[OpenCV Scan] {msg}")
            return False, msg

        bgr = capture_full_window_bgr(hwnd)
        if bgr is None:
            msg = "Не удалось захватить буфер окна WoW"
            print(f"[OpenCV Scan] {msg}")
            return False, msg

        res, err = scan_for_container_marker(bgr)
        if err or not res or not res.get("found"):
            conf = res.get("confidence", 0) if res else 0
            msg = f"Контейнер не обнаружен на экране (уверенность: {conf*100:.1f}%)"
            print(f"[OpenCV Scan] {msg}")
            return False, msg

        # Преобразуем координаты окна в истинные клиентские координаты WoW
        wrect = win32gui.GetWindowRect(hwnd)
        c0 = win32gui.ClientToScreen(hwnd, (0, 0))
        off_x = max(0, c0[0] - wrect[0])
        off_y = max(0, c0[1] - wrect[1])

        window_cx = res["x"]
        window_cy = res["y"]
        client_cx = max(0, window_cx - off_x)
        client_cy = max(0, window_cy - off_y)

        conf = res["confidence"]
        ms = res["elapsed_ms"]
        self.client_x = client_cx
        self.client_y = client_cy
        self.last_opencv_conf = conf
        self.last_opencv_ms = ms
        self.save_config()

        msg = f"Оптический контейнер найден со 100% точностью: Клиент X={client_cx}, Y={client_cy} (Окно: {window_cx}, {window_cy} | {conf*100:.1f}%, {ms:.1f}мс)"
        print(f"[OpenCV Scan УСПЕХ] {msg}")
        self.sample_pixel_state(hwnd)
        try:
            winsound.MessageBeep(winsound.MB_ICONASTERISK)
        except Exception:
            pass
        return True, msg

    def set_calib_hint(self, text, fg='#ffbb00'):
        if hasattr(self, 'lbl_calib_hint') and self.lbl_calib_hint:
            try: self.set_calib_hint(text=text, fg=fg)
            except Exception: pass

    def set_pixel_coords_lbl(self, text):
        if hasattr(self, 'lbl_pixel_coords') and self.lbl_pixel_coords:
            try: self.set_pixel_coords_lbl(text=text)
            except Exception: pass

    def handle_f11(self):
        """Запуск авто-сканирования OpenCV по нажатию F11 или кнопке в интерфейсе"""
        print("\n" + "=" * 65)
        print("  >>> [OpenCV АВТО-СКАНИРОВАНИЕ F11] <<<")
        print("=" * 65)
        threading.Thread(target=self.run_opencv_full_scan, daemon=True).start()

    def finish_calibration(self):
        """Фиксация координат пикселя по текущему положению курсора мыши"""
        is_running, state, desc, hwnd, rect = self.check_wow_state()
        if not is_running or not hwnd:
            self.calibrating = False
            self.set_calib_hint(text="Ошибка: окно игры WoW не найдено или свернуто!", fg="#ff4444")
            if hasattr(self, 'btn_calib'):
                self.btn_calib.config(text="🎯 Курсором (F11)", bg="#007acc")
            return

        try:
            attach_to_desktop()
            screen_pos = win32api.GetCursorPos()
            client_pos = win32gui.ScreenToClient(hwnd, screen_pos)

            cx = int(client_pos[0])
            cy = int(client_pos[1])

            cl_rect = win32gui.GetClientRect(hwnd)
            if cx < 0 or cy < 0 or cx >= cl_rect[2] or cy >= cl_rect[3]:
                self.calibrating = False
                self.set_calib_hint(text=f"Курсор вне окна WoW ({cx}, {cy})! Наведите на окно игры.", fg="#ffbb00")
                if hasattr(self, 'btn_calib'):
                    self.btn_calib.config(text="🎯 Курсором (F11)", bg="#007acc")
                return

            self.client_x = cx
            self.client_y = cy

            # Считываем цвет пикселя в точке калибровки
            rgb = sample_pixel_from_printwindow(hwnd, self.client_x, self.client_y)
            if not rgb:
                try:
                    hdc = win32gui.GetDC(0)
                    color = win32gui.GetPixel(hdc, screen_pos[0], screen_pos[1])
                    win32gui.ReleaseDC(0, hdc)
                    if color != -1 and color != 0xFFFFFFFF:
                        rgb = (color & 0xFF, (color >> 8) & 0xFF, (color >> 16) & 0xFF)
                except Exception:
                    pass

            if rgb:
                self.target_r, self.target_g, self.target_b = rgb
                self.current_sampled_rgb = rgb

            self.save_config()
            self.calibrating = False

            if hasattr(self, 'entry_x'):
                self.entry_x.delete(0, tk.END)
                self.entry_x.insert(0, str(self.client_x))
            if hasattr(self, 'entry_y'):
                self.entry_y.delete(0, tk.END)
                self.entry_y.insert(0, str(self.client_y))

            if hasattr(self, 'btn_calib'):
                self.btn_calib.config(text="🎯 Курсором (F11)", bg="#007acc")

            success_msg = f"Калибровка успешна! Координаты WoW: X={self.client_x}, Y={self.client_y}"
            print(f"[Калибровка УСПЕХ] {success_msg}")
            self.set_calib_hint(text=f"Калибровка успешна! X={self.client_x}, Y={self.client_y}", fg="#00ff66")
            self.set_pixel_coords_lbl(text=f"Клиент WoW: X={self.client_x}, Y={self.client_y} | Экран: ({screen_pos[0]}, {screen_pos[1]})")
        except Exception as e:
            self.calibrating = False
            if hasattr(self, 'btn_calib'):
                self.btn_calib.config(text="🎯 Курсором (F11)", bg="#007acc")
            self.set_calib_hint(text=f"Ошибка калибровки: {e}", fg="#ff4444")

    def apply_manual_coords(self):
        """Применяет координаты X и Y, введенные вручную в поля GUI"""
        if not hasattr(self, 'entry_x') or not self.entry_x:
            return
        try:
            cx_str = self.entry_x.get().strip()
            cy_str = self.entry_y.get().strip()
            cx = int(cx_str)
            cy = int(cy_str)
            self.client_x = cx
            self.client_y = cy
            self.save_config()

            is_running, state, desc, hwnd, rect = self.check_wow_state()
            if hwnd:
                self.sample_pixel_state(hwnd)

            msg = f"Координаты сохранены: X={cx}, Y={cy}"
            print(f"[Ручная настройка] {msg}")
            self.set_calib_hint(text=msg, fg="#00ff66")
        except ValueError:
            self.set_calib_hint(text="Ошибка: координаты X и Y должны быть целыми числами!", fg="#ff4444")
        except Exception as e:
            self.set_calib_hint(text=f"Ошибка сохранения: {e}", fg="#ff4444")

    def reset_coords_default(self):
        """Сброс координат на стандартный центр индикатора (20, 20)"""
        self.client_x = 20
        self.client_y = 20
        if hasattr(self, 'entry_x'):
            self.entry_x.delete(0, tk.END)
            self.entry_x.insert(0, "20")
        if hasattr(self, 'entry_y'):
            self.entry_y.delete(0, tk.END)
            self.entry_y.insert(0, "20")
        self.save_config()
        is_running, state, desc, hwnd, rect = self.check_wow_state()
        if hwnd:
            self.sample_pixel_state(hwnd)
        self.set_calib_hint(text="Сброшено на по умолчанию: X=20, Y=20", fg="#00e5ff")

    def launch_or_restart_wow(self):
        """Запускает или перезапускает WoW на выделенном рабочем столе"""
        exe = self.wow_exe_path or get_wow_executable_path()
        if not exe or not os.path.exists(exe):
            return False, "Исполняемый файл WoW не найден! Укажите папку WoW."

        # Гарантируем наличие рабочего стола для WoW если включен режим изоляции
        if self.use_virtual_desktop:
            self.desktop_mgr.ensure_wow_desktop_exists()
            self.desktop_mgr.switch_to_wow()
            time.sleep(0.2)

        work_dir = os.path.dirname(exe)
        try:
            subprocess.Popen([exe], cwd=work_dir)
            return True, f"Запущен: {os.path.basename(exe)} на столе #{self.desktop_mgr.wow_desktop_num}"
        except Exception as e:
            return False, f"Ошибка запуска WoW: {e}"

    def select_wow_folder_dialog(self):
        """Диалог выбора папки WoW"""
        chosen = filedialog.askdirectory(title="Выберите корневую папку с игрой World of Warcraft")
        if not chosen:
            return
        info = analyze_wow_folder(chosen)
        if not info:
            messagebox.showerror("Ошибка", "В выбранной папке не найдены файлы WoW!")
            return

        self.wow_root_dir = info["root_dir"]
        if info["exe_path"]:
            self.wow_exe_path = info["exe_path"]
        if info["log_path"]:
            self.wow_log_path = info["log_path"]

        self.save_config()
        messagebox.showinfo(
            "Настройки обновлены",
            f"Папка WoW: {self.wow_root_dir}\nExe: {os.path.basename(self.wow_exe_path or 'Не найден')}\nЛог: {self.wow_log_path}"
        )

    def play_role_alert(self, role):
        if role != "FULL":
            return
        fname = "female_full.wav"
        fpath = os.path.join(RVC_AUDIO_CACHE, fname)
        if os.path.exists(fpath):
            def _play():
                try:
                    winsound.PlaySound(fpath, winsound.SND_FILENAME | winsound.SND_NODEFAULT)
                except Exception:
                    speak("Внимание! Группа полностью собрана. Авто набор завершен.")
            threading.Thread(target=_play, daemon=True).start()
            return

        speak("Внимание! Группа полностью собрана. Авто набор завершен.")

    def watch_chat_log(self):
        log_path = self.wow_log_path or WOW_LOG_PATH
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        if not os.path.exists(log_path):
            try:
                with open(log_path, "w", encoding="utf-8") as f:
                    f.write("=== WoWChatLog Initialized ===\n")
            except Exception:
                pass

        try:
            log_file = open(log_path, "r", encoding="utf-8", errors="ignore")
            log_file.seek(0, os.SEEK_END)
        except Exception:
            return

        last_events = {}

        while self.running:
            line = log_file.readline()
            if line:
                cur_t = time.time()
                t_str = time.strftime('%H:%M:%S')

                if "KAR_FOUND:ТАНК" in line or "KAR_FOUND:TANK" in line:
                    if cur_t - last_events.get("TANK", 0) > 2.0:
                        last_events["TANK"] = cur_t
                        self.last_event_text = f"[{t_str}] НАЙДЕН ТАНК!"
                        print(f"\n{self.last_event_text}")
                        self.play_role_alert("TANK")

                elif "KAR_FOUND:ХИЛ" in line or "KAR_FOUND:HEALER" in line:
                    if cur_t - last_events.get("HEALER", 0) > 2.0:
                        last_events["HEALER"] = cur_t
                        self.last_event_text = f"[{t_str}] НАЙДЕН ХИЛ!"
                        print(f"\n{self.last_event_text}")
                        self.play_role_alert("HEAL")

                elif "KAR_FOUND:ДД" in line or "KAR_FOUND:DPS" in line:
                    if cur_t - last_events.get("DPS", 0) > 2.0:
                        last_events["DPS"] = cur_t
                        self.last_event_text = f"[{t_str}] НАЙДЕН ДД!"
                        print(f"\n{self.last_event_text}")
                        self.play_role_alert("DPS")

                elif "KAR_GROUP_FULL" in line or "KAR_STOP_RECRUIT" in line:
                    if cur_t - last_events.get("FULL", 0) > 8.0:
                        last_events["FULL"] = cur_t
                        self.last_event_text = f"[{t_str}] ГРУППА ПОЛНОСТЬЮ СОБРАНА (5/5)!"
                        print(f"\n{self.last_event_text}")
                        self.play_role_alert("FULL")
                        self.is_active = False

                elif "KAR_TRIGGER_F12" in line:
                    hwnd = find_wow_hwnd()
                    if hwnd and self.is_active:
                        print(f"[{t_str}] >>> [ЧАТ-СИГНАЛ] Получен маркер KAR_TRIGGER_F12! Нажатие F12...")
                        send_f12_key(hwnd, self.desktop_mgr, use_vdesk=self.use_virtual_desktop)

                continue

            time.sleep(0.04)

    def sample_pixel_state(self, hwnd):
        """Считывает цвет в центре постоянного контейнера и классифицирует триггер"""
        try:
            screen_pos = win32gui.ClientToScreen(hwnd, (self.client_x, self.client_y))
            self.current_screen_xy = screen_pos

            # 1. Прямой замер из DirectX-буфера окна игры (наивысшая точность, 0% помех от других окон)
            rgb = sample_pixel_from_printwindow(hwnd, self.client_x, self.client_y)

            # 2. Резервный опрос через GDI GetPixel экрана при активном окне
            if not rgb and win32gui.IsWindowVisible(hwnd) and not self.is_window_cloaked(hwnd):
                try:
                    sx, sy = screen_pos
                    hdc = win32gui.GetDC(0)
                    color = win32gui.GetPixel(hdc, sx, sy)
                    win32gui.ReleaseDC(0, hdc)
                    if color != -1 and color != 0xFFFFFFFF:
                        rgb = (color & 0xFF, (color >> 8) & 0xFF, (color >> 16) & 0xFF)
                except Exception:
                    pass

            if not rgb:
                self.current_event_type = None
                self.current_role = None
                return None, None

            r, g, b = rgb
            self.current_sampled_rgb = (r, g, b)
            event_type, role = classify_pixel_trigger(r, g, b)
            self.current_event_type = event_type
            self.current_role = role
            return event_type, role
        except Exception:
            self.current_event_type = None
            self.current_role = None
            return None, None

    def recruiter_worker_loop(self):
        """Основной рабочий цикл сервиса авто-набора с поддержкой виртуальных столов и OpenCV"""
        last_auto_move_check = 0

        while self.running:
            is_running, state, desc, hwnd, rect = self.check_wow_state()

            if not is_running:
                time.sleep(1.0)
                continue

            # Автоматический перенос WoW на требуемый рабочий стол при обнаружении
            cur_t = time.time()
            if cur_t - last_auto_move_check > 5.0:
                last_auto_move_check = cur_t
                if self.desktop_mgr.enabled:
                    if self.use_virtual_desktop:
                        if not self.desktop_mgr.is_window_on_wow_desktop(hwnd):
                            self.desktop_mgr.move_window_to_wow_desktop(hwnd)
                    else:
                        if not self.desktop_mgr.is_window_on_primary_desktop(hwnd):
                            self.desktop_mgr.move_window_to_primary_desktop(hwnd)

            # Периодический опрос пикселя ведется напрямую без OpenCV

            if self.is_active and not self.calibrating:
                event_type, role = self.sample_pixel_state(hwnd)

                if event_type == "INVITE":
                    role_ru = {"TANK": "танк", "HEAL": "хил", "DPS": "ДД"}.get(role, "кандидат")
                    self.play_role_alert(role)
                    clicked = send_f12_key(hwnd, self.desktop_mgr, use_vdesk=self.use_virtual_desktop)
                    t_str = time.strftime('%H:%M:%S')
                    if clicked:
                        self.press_count += 1
                        self.last_event_text = f"[{t_str}] НАЙДЕН {role_ru.upper()}! Нажат F12 (#{self.press_count})"
                        print(f"[{t_str}] >>> [ОПТИКА] НАЙДЕН {role_ru.upper()}! Нажат F12 (#{self.press_count})")
                    else:
                        self.last_event_text = f"[{t_str}] НАЙДЕН {role_ru.upper()}! (Нажмите NumPad 4 для перехода в WoW)"
                        print(f"[{t_str}] >>> [ИЗОЛЯЦИЯ] НАЙДЕН {role_ru.upper()}! Ожидание перехода на рабочий стол WoW...")
                    time.sleep(0.40)

                elif event_type == "ACTION" and role == "DECLINE":
                    clicked = send_f12_key(hwnd, self.desktop_mgr, use_vdesk=self.use_virtual_desktop)
                    t_str = time.strftime('%H:%M:%S')
                    if clicked:
                        self.press_count += 1
                        self.last_event_text = f"[{t_str}] Отклонен кандидат (F12 #{self.press_count})"
                        print(f"[{t_str}] >>> [ОТКЛОНЕНИЕ] Отклонен неподходящий кандидат. Нажат F12 (#{self.press_count})")
                    else:
                        self.last_event_text = f"[{t_str}] Отклонение ожидает (Нажмите NumPad 4 для перехода в WoW)"
                    time.sleep(0.35)

                elif event_type == "FULL":
                    cur_t = time.time()
                    if cur_t - self.last_full_time > 8.0:
                        self.last_full_time = cur_t
                        t_str = time.strftime('%H:%M:%S')
                        self.last_event_text = f"[{t_str}] ГРУППА ПОЛНОСТЬЮ СОБРАНА (5/5)!"
                        print(f"[{t_str}] >>> [5/5 ПОЛНАЯ ГРУППА] Авто-набор успешно завершен!")
                        self.play_role_alert("FULL")
                        self.is_active = False
                    time.sleep(1.0)

                elif event_type == "TEST":
                    time.sleep(0.1)

                else:
                    time.sleep(0.040)

            else:
                time.sleep(0.12)

    def init_gui(self):
        """Запуск встроенного HTTP сервера Hellsing и Edge UI"""
        HellsingHttpHandler.app_instance = self
        try:
            self.http_server = HellsingThreadingServer(("127.0.0.1", HTTP_PORT), HellsingHttpHandler)
            threading.Thread(target=self.http_server.serve_forever, daemon=True).start()
            print(f"[{time.strftime('%H:%M:%S')}] >>> [HellsingUI] HTTP сервер запущен: http://127.0.0.1:{HTTP_PORT}/")
        except Exception as e:
            print(f"[HellsingUI] Ошибка старта HTTP сервера: {e}")

        if "--silent" not in sys.argv:
            threading.Thread(target=self.launch_edge_ui, daemon=True).start()

    def toggle_single_desktop_mode(self):
        """Переключение между изоляцией на доп. столе и 1 рабочим столом"""
        self.use_virtual_desktop = not self.use_virtual_desktop
        self.save_config()
        hwnd = find_wow_hwnd()

        if not self.use_virtual_desktop:
            print(f"[{time.strftime('%H:%M:%S')}] >>> [Режим 1 стола] Отключен доп. стол. Перенос WoW на основной рабочий стол (#1)...")
            if self.desktop_mgr.enabled:
                if hwnd and win32gui.IsWindow(hwnd):
                    self.desktop_mgr.move_window_to_primary_desktop(hwnd)
                self.desktop_mgr.switch_to_return(hwnd=hwnd)
                if hwnd and win32gui.IsWindow(hwnd):
                    force_focus_window(hwnd)
            speak("Режим одного стола. Игра перенесена на основной рабочий стол.")
        else:
            print(f"[{time.strftime('%H:%M:%S')}] >>> [Режим доп. стола] Включена изоляция WoW на рабочем столе #2 ('wow')...")
            if self.desktop_mgr.enabled:
                self.desktop_mgr.ensure_wow_desktop_exists()
                if hwnd and win32gui.IsWindow(hwnd):
                    self.desktop_mgr.move_window_to_wow_desktop(hwnd)
                self.desktop_mgr.switch_to_wow(hwnd=hwnd)
            speak("Игра перенесена на рабочий стол два. Для возврата на этот стол нажмите NumPad 4.")

    def stop_service(self):
        self.running = False
        h = self.find_edge_ui_hwnd()
        if h:
            try:
                win32gui.PostMessage(h, 0x0010, 0, 0)
            except Exception:
                pass
        sys.exit(0)

    def run(self):
        print("=" * 75)
        print("      HELLSING M+ TACTICAL RECRUITER (HTML/CSS & Win32 Internals)")
        print("  - NumPad 4: Столы (WoW <-> Основной)")
        print("  - NumPad 5: Меню Hellsing UI")
        print("  - NumPad 1: Пауза / Авто-набор")
        print("  - F11: Прицел сенсора")
        print(f"  - Web UI: http://127.0.0.1:{HTTP_PORT}/")
        print("=" * 75)
        while self.running:
            time.sleep(0.5)

if __name__ == "__main__":
    is_main_instance = True
    # Гарантированный синглтон Windows через Named Mutex (исключает войну дубликатов демона)
    MUTEX_NAME = "Global\\WoWSmartRecruiter_SingleInstance_Mutex_v2"
    mutex_handle = ctypes.windll.kernel32.CreateMutexW(None, True, MUTEX_NAME)
    if ctypes.windll.kernel32.GetLastError() == 183: # ERROR_ALREADY_EXISTS
        try:
            client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            client.settimeout(1.5)
            client.connect(('127.0.0.1', IPC_PORT))
            client.sendall(b"SHOW\n")
            client.close()
            print("[IPC] Отправлен сигнал SHOW работающему экземпляру демона.")
        except Exception as e:
            print(f"[IPC] Служба уже активна, резервный вызов браузера: {e}")
            try:
                webbrowser.open(f"http://127.0.0.1:{HTTP_PORT}/")
            except Exception:
                pass
        sys.exit(0)

    try:
        ipc_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ipc_server.bind(('127.0.0.1', IPC_PORT))
        ipc_server.listen(5)
    except Exception:
        pass

    try:
        app = RecruiterServiceApp()

        def listen_ipc_requests():
            ipc_server.settimeout(1.0)
            while app.running:
                try:
                    conn, _ = ipc_server.accept()
                    data = conn.recv(1024)
                    conn.close()
                    if b"SHOW" in data:
                        app.show_gui()
                    elif b"TOGGLE" in data:
                        app.toggle_gui()
                    elif b"NUMPAD4" in data or b"SWITCHER" in data:
                        app.toggle_desktop()
                    elif b"STOP" in data:
                        app.stop_service()
                        break
                except socket.timeout:
                    continue
                except Exception:
                    break

        threading.Thread(target=listen_ipc_requests, daemon=True).start()
        app.run()
    except Exception as e:
        import traceback
        err_msg = f"\n[{time.strftime('%Y-%m-%d %H:%M:%S')}] FATAL ERROR:\n{traceback.format_exc()}\n"
        print(err_msg)
        try:
            with open(SERVICE_LOG_PATH, "a", encoding="utf-8") as f:
                f.write(err_msg)
        except Exception:
            pass
