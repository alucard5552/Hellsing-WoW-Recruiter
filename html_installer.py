# -*- coding: utf-8 -*-
"""
HELLSING • WoW Mythic+ Smart Recruiter HTML5/CSS3 Ultra-Installer
- Движок: Microsoft Edge Chromium WebView2 (pywebview)
- Интерфейс: Cyber-Gothic Hellsing Alucard (60 FPS Canvas particles, Cromwell Pentagram seal, Audio API)
- Установка аддонов:
  * Базовый пакет аддонов Midnight 12.0.7 (Details!, DBM, Plater, RaiderIO, Clique, AngryKeystones, TomTom, Bagnon)
  * Комплекс набора Alucard (KeyAutoRecruit, KAR_P2P_Tester, KeyGroupDumper)
  * Исключены по требованию: KeyHeuristics и KeyAutoSeeker
- Фоновая служба демона WoWSmartRecruiter:
  * Развертывание в Program Files / LocalAppData
  * Иконка демона (Alucard Demonic Slit Eye / Crosshairs)
  * Иконка установщика (Cromwell Pentagram Seal)
  * Автоматическая активация SET chatLog "1" в Config.wtf
  * Регистрация в автозагрузке Windows (тихий фоновый режим)
  * Перенос WoW на выделенный виртуальный рабочий стол #2
  * Запуск демона без зависаний основного потока UI (Smooth background extraction)
"""

import sys
import os
import shutil
import json
import subprocess
import time
import zipfile
import threading
import winreg
import win32gui
import win32api
import win32service
import ctypes

try:
    import pyvda
except ImportError:
    pyvda = None

try:
    import psutil
except ImportError:
    psutil = None

import multiprocessing
import webview

# DPI Awareness
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(1)
except Exception:
    try:
        ctypes.windll.user32.SetProcessDPIAware()
    except Exception:
        pass

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = getattr(sys, '_MEIPASS', SCRIPT_DIR)

def find_wow_hwnd():
    """Безопасный поиск окна игры Firestorm WoW без зависаний psutil"""
    for cls, title in [
        ('GxWindowClass', None),
        (None, 'World of Warcraft'),
        ('waApplication Window', None)
    ]:
        try:
            hwnd = win32gui.FindWindow(cls, title)
            if hwnd and win32gui.IsWindow(hwnd):
                return hwnd
        except Exception:
            pass
    return None

def get_firestorm_wow_path():
    """
    Получает путь установки WoW строго для сервера Firestorm:
    1. Конфигурация Firestorm Launcher (%APPDATA%\\com.firestorm.launcher\\installs.json)
    2. Реестр Windows (HKCU\\Software\\firestorm, HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\TypedPaths)
    3. Фиксированный целевой путь C:\\Firestorm\\The War Within\\_midnight_
    Никаких зависающих сканирований дисков и поиска окон.
    """
    # 1. Firestorm Launcher installs.json
    appdata = os.environ.get("APPDATA", "")
    if appdata:
        installs_json = os.path.join(appdata, "com.firestorm.launcher", "installs.json")
        if os.path.isfile(installs_json):
            try:
                with open(installs_json, "r", encoding="utf-8", errors="ignore") as f:
                    data = json.load(f)
                # Приоритет Midnight 12.0.7 (ключ "10")
                if "10" in data and isinstance(data["10"], dict):
                    ipath = data["10"].get("install_path")
                    if ipath and os.path.isdir(ipath):
                        return os.path.abspath(ipath)
                # Fallback к ключу "9" (The War Within 11.2.5) с проверкой _midnight_
                if "9" in data and isinstance(data["9"], dict):
                    ipath = data["9"].get("install_path")
                    if ipath:
                        midnight_sub = os.path.join(ipath, "_midnight_")
                        if os.path.isdir(midnight_sub):
                            return os.path.abspath(midnight_sub)
                        if os.path.isdir(ipath):
                            return os.path.abspath(ipath)
            except Exception:
                pass

    # 2. Реестр Windows
    registry_targets = [
        (winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths", "url1"),
        (winreg.HKEY_CURRENT_USER, r"Software\firestorm\Firestorm Launcher", ""),
        (winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Uninstall\Firestorm Launcher", "InstallLocation"),
    ]
    for hkey, subkey, val_name in registry_targets:
        try:
            with winreg.OpenKey(hkey, subkey) as k:
                val, _ = winreg.QueryValueEx(k, val_name)
                if val:
                    val_str = str(val).strip('"').strip()
                    if os.path.isdir(val_str):
                        midnight_sub = os.path.join(val_str, "_midnight_")
                        if os.path.isdir(midnight_sub):
                            return os.path.abspath(midnight_sub)
                        return os.path.abspath(val_str)
        except Exception:
            pass

    # 3. Фиксированный целевой каталог Firestorm Midnight 12.0.7
    firestorm_midnight = r"C:\Firestorm\The War Within\_midnight_"
    if os.path.isdir(firestorm_midnight):
        return firestorm_midnight

    firestorm_root = r"C:\Firestorm\The War Within"
    if os.path.isdir(firestorm_root):
        return firestorm_root

    return firestorm_midnight

def analyze_wow_folder(folder_path):
    """Мгновенный анализ каталога Firestorm WoW (sub-millisecond, без os.walk)"""
    if not folder_path or not os.path.exists(folder_path):
        folder_path = r"C:\Firestorm\The War Within\_midnight_"

    folder_path = os.path.abspath(folder_path)
    result = {
        "root_dir": folder_path,
        "exe_path": None,
        "exe_name": None,
        "addons_dir": None,
        "log_path": None,
        "config_wtf": None
    }

    # 1. Поиск исполняемого файла Firestorm WoW
    candidate_exes = [
        os.path.join(folder_path, "WoW 12.0.7 - Firestorm.exe"),
        os.path.join(folder_path, "WoW 11.2.5 - Firestorm.exe"),
        os.path.join(folder_path, "Firestorm.exe"),
        os.path.join(folder_path, "WoW.exe"),
        os.path.join(folder_path, "_midnight_", "WoW 12.0.7 - Firestorm.exe"),
    ]
    for ec in candidate_exes:
        if os.path.isfile(ec):
            result["exe_path"] = ec
            result["exe_name"] = os.path.basename(ec)
            break

    # 2. AddOns папка Firestorm
    candidate_addons = [
        os.path.join(folder_path, "Interface", "AddOns"),
        os.path.join(folder_path, "_midnight_", "Interface", "AddOns")
    ]
    for ad in candidate_addons:
        if os.path.isdir(ad):
            result["addons_dir"] = ad
            break
    if not result["addons_dir"]:
        result["addons_dir"] = os.path.join(folder_path, "Interface", "AddOns")

    # 3. Чат-лог Firestorm
    candidate_logs = [
        os.path.join(folder_path, "Logs", "WoWChatLog.txt"),
        os.path.join(folder_path, "_midnight_", "Logs", "WoWChatLog.txt")
    ]
    for cl in candidate_logs:
        if os.path.isdir(os.path.dirname(cl)):
            result["log_path"] = cl
            break
    if not result["log_path"]:
        result["log_path"] = os.path.join(folder_path, "Logs", "WoWChatLog.txt")

    # 4. Config.wtf Firestorm
    candidate_wtfs = [
        os.path.join(folder_path, "WTF", "Config.wtf"),
        os.path.join(folder_path, "_midnight_", "WTF", "Config.wtf")
    ]
    for cw in candidate_wtfs:
        if os.path.isfile(cw):
            result["config_wtf"] = cw
            break
    if not result["config_wtf"]:
        result["config_wtf"] = os.path.join(folder_path, "WTF", "Config.wtf")

    return result

def enable_chatlog_in_wtf(wtf_path):
    if not wtf_path:
        return False
    try:
        os.makedirs(os.path.dirname(wtf_path), exist_ok=True)
        content = ""
        if os.path.exists(wtf_path):
            with open(wtf_path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()

        if 'SET chatLog "1"' not in content:
            with open(wtf_path, "a", encoding="utf-8") as f:
                f.write('\nSET chatLog "1"\n')
            return True
        return True
    except Exception as e:
        print(f"[WTF Config] Ошибка: {e}")
        return False

def setup_windows_autostart(exe_path):
    try:
        key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path, 0, winreg.KEY_SET_VALUE) as key:
            cmd = f'"{exe_path}" --silent'
            winreg.SetValueEx(key, "WoWSmartRecruiterService", 0, winreg.REG_SZ, cmd)
        return True
    except Exception as e:
        print(f"[Автозагрузка] Ошибка: {e}")
        return False

def create_desktop_shortcut(target_exe, shortcut_name="WoW Smart Recruiter.lnk", icon_path=None):
    try:
        desktop_dir = os.path.join(os.path.expanduser("~"), "Desktop")
        shortcut_path = os.path.join(desktop_dir, shortcut_name)
        
        import win32com.client
        shell = win32com.client.Dispatch("WScript.Shell")
        shortcut = shell.CreateShortCut(shortcut_path)
        shortcut.TargetPath = target_exe
        shortcut.WorkingDirectory = os.path.dirname(target_exe)
        shortcut.Description = "HELLSING • WoW Mythic+ Smart Recruiter Automation Suite"
        if icon_path and os.path.exists(icon_path):
            shortcut.IconLocation = f"{icon_path},0"
        else:
            shortcut.IconLocation = f"{target_exe},0"
        shortcut.save()
        return True
    except Exception as e:
        print(f"[Ярлык] Ошибка создания ярлыка: {e}")
        return False

# -------------------------------------------------------------------------
# Реестр Windows и Встроенная система удаления (БЕЗ BAT-файлов)
# -------------------------------------------------------------------------
def register_windows_installation(service_dir, wow_dir, addons_dir, installed_addons):
    r"""
    Создает официальную запись об установке в реестре Windows:
    1. HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\WoWSmartRecruiter
       (Windows Apps / 'Установка и удаление программ')
    2. HKCU\Software\WoWSmartRecruiter
       (Метаданные приложения и список аддонов)
    """
    try:
        # 1. Windows Uninstall entry
        uninst_key = r"Software\Microsoft\Windows\CurrentVersion\Uninstall\WoWSmartRecruiter"
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, uninst_key) as k:
            winreg.SetValueEx(k, "DisplayName", 0, winreg.REG_SZ, "HELLSING • WoW Mythic+ Smart Recruiter Suite")
            winreg.SetValueEx(k, "DisplayVersion", 0, winreg.REG_SZ, "12.0.7")
            winreg.SetValueEx(k, "Publisher", 0, winreg.REG_SZ, "Hellsing Alucard Automation")
            winreg.SetValueEx(k, "InstallDate", 0, winreg.REG_SZ, time.strftime("%Y%m%d"))
            winreg.SetValueEx(k, "InstallLocation", 0, winreg.REG_SZ, service_dir or "")
            
            ico = os.path.join(service_dir, "installer_icon.ico") if service_dir else ""
            if not os.path.exists(ico) and service_dir:
                ico = os.path.join(service_dir, "daemon_icon.ico")
            if not os.path.exists(ico):
                ico = os.path.join(SCRIPT_DIR, "installer_icon.ico")
            if os.path.exists(ico):
                winreg.SetValueEx(k, "DisplayIcon", 0, winreg.REG_SZ, ico)

            # Вызов установщика напрямую без bat-файлов
            if getattr(sys, 'frozen', False):
                exe_target = sys.executable
                if service_dir and os.path.exists(service_dir):
                    try:
                        dst_uninst = os.path.join(service_dir, "uninstall.exe")
                        shutil.copy2(exe_target, dst_uninst)
                        exe_target = dst_uninst
                    except Exception:
                        pass
                uninst_cmd = f'"{exe_target}" --uninstall'
                quiet_cmd = f'"{exe_target}" --silent-uninstall'
            else:
                installer_script = os.path.abspath(__file__)
                py_exec = sys.executable
                uninst_cmd = f'"{py_exec}" "{installer_script}" --uninstall'
                quiet_cmd = f'"{py_exec}" "{installer_script}" --silent-uninstall'

            winreg.SetValueEx(k, "UninstallString", 0, winreg.REG_SZ, uninst_cmd)
            winreg.SetValueEx(k, "QuietUninstallString", 0, winreg.REG_SZ, quiet_cmd)
            winreg.SetValueEx(k, "EstimatedSize", 0, winreg.REG_DWORD, 150000)
            winreg.SetValueEx(k, "NoModify", 0, winreg.REG_DWORD, 1)
            winreg.SetValueEx(k, "NoRepair", 0, winreg.REG_DWORD, 1)

        # 2. Application state key
        app_key = r"Software\WoWSmartRecruiter"
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, app_key) as k:
            winreg.SetValueEx(k, "Installed", 0, winreg.REG_DWORD, 1)
            winreg.SetValueEx(k, "Version", 0, winreg.REG_SZ, "12.0.7")
            winreg.SetValueEx(k, "InstallDir", 0, winreg.REG_SZ, service_dir or "")
            winreg.SetValueEx(k, "WoWRootDir", 0, winreg.REG_SZ, wow_dir or "")
            winreg.SetValueEx(k, "AddOnsDir", 0, winreg.REG_SZ, addons_dir or "")
            winreg.SetValueEx(k, "InstalledDate", 0, winreg.REG_SZ, time.strftime("%Y-%m-%d %H:%M:%S"))
            winreg.SetValueEx(k, "InstalledAddOns", 0, winreg.REG_SZ, json.dumps(installed_addons))

        return True
    except Exception as e:
        print(f"[Реестр] Ошибка регистрации установки: {e}")
        return False

def check_installation_in_registry():
    """Проверяет наличие записи об установке в реестре Windows"""
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\WoWSmartRecruiter") as k:
            installed = winreg.QueryValueEx(k, "Installed")[0]
            version = winreg.QueryValueEx(k, "Version")[0]
            install_dir = winreg.QueryValueEx(k, "InstallDir")[0]
            addons_dir = winreg.QueryValueEx(k, "AddOnsDir")[0]
            installed_date = winreg.QueryValueEx(k, "InstalledDate")[0]
            return {
                "is_installed": bool(installed),
                "version": version,
                "install_dir": install_dir,
                "addons_dir": addons_dir,
                "installed_date": installed_date
            }
    except Exception:
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Uninstall\WoWSmartRecruiter") as k:
                return {
                    "is_installed": True,
                    "version": winreg.QueryValueEx(k, "DisplayVersion")[0],
                    "install_dir": winreg.QueryValueEx(k, "InstallLocation")[0],
                    "addons_dir": "",
                    "installed_date": winreg.QueryValueEx(k, "InstallDate")[0]
                }
        except Exception:
            return {"is_installed": False}

def kill_daemon_processes():
    """Завершает любые запущенные процессы службы демона (чистый Python, без bat)"""
    killed = 0
    if psutil:
        for p in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                name = (p.info['name'] or '').lower()
                cmdline = ' '.join(p.info['cmdline'] or []).lower()
                if 'wowsmartrecruiter' in name or ('python' in name and 'wow_voice_clicker' in cmdline):
                    p.terminate()
                    try:
                        p.wait(timeout=2)
                    except psutil.TimeoutExpired:
                        p.kill()
                    killed += 1
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
    if killed == 0:
        subprocess.run('taskkill /F /IM WoWSmartRecruiter.exe /T', shell=True, capture_output=True)
    return killed

def remove_addons(addons_dir=None, addons_list=None):
    """Удаляет только аддоны комплекса рекрутера из Interface/AddOns"""
    if not addons_list:
        addons_list = ["KeyAutoRecruit", "KAR_P2P_Tester", "KeyGroupDumper"]

    if not addons_dir:
        reg_info = check_installation_in_registry()
        addons_dir = reg_info.get("addons_dir")

    candidates = [
        addons_dir,
        r"C:\Firestorm\The War Within\_midnight_\Interface\AddOns",
        r"C:\Firestorm\The War Within\Interface\AddOns",
        r"C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
    ]

    found_dir = None
    for c in candidates:
        if c and os.path.exists(c):
            found_dir = c
            break

    if not found_dir:
        return 0

    removed_count = 0
    for addon in addons_list:
        if addon.lower() in ("details", "dbm-core", "plater", "clique", "elvui", "raiderio"):
            continue
        addon_path = os.path.join(found_dir, addon)
        if os.path.exists(addon_path):
            try:
                shutil.rmtree(addon_path, ignore_errors=True)
                removed_count += 1
            except Exception:
                pass

    return removed_count

def remove_registry_records():
    """Удаляет все созданные записи реестра (Run, Uninstall, App state) без bat"""
    # 1. Run
    try:
        run_key = r"Software\Microsoft\Windows\CurrentVersion\Run"
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, run_key, 0, winreg.KEY_SET_VALUE) as k:
            try:
                winreg.DeleteValue(k, "WoWSmartRecruiterService")
            except FileNotFoundError:
                pass
    except Exception:
        pass

    # 2. Uninstall
    try:
        uninst_key = r"Software\Microsoft\Windows\CurrentVersion\Uninstall"
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, uninst_key, 0, winreg.KEY_ALL_ACCESS) as k:
            try:
                winreg.DeleteKey(k, "WoWSmartRecruiter")
            except FileNotFoundError:
                pass
    except Exception:
        pass

    # 3. State
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software", 0, winreg.KEY_ALL_ACCESS) as k:
            try:
                winreg.DeleteKey(k, "WoWSmartRecruiter")
            except FileNotFoundError:
                pass
    except Exception:
        pass

def remove_desktop_shortcuts():
    """Удаляет ярлыки службы с Рабочего стола"""
    desktop_dir = os.path.join(os.path.expanduser("~"), "Desktop")
    for s in ["HELLSING WoW Recruiter.lnk", "WoW Smart Recruiter.lnk"]:
        p = os.path.join(desktop_dir, s)
        if os.path.exists(p):
            try:
                os.remove(p)
            except Exception:
                pass

def remove_service_folder(service_dir=None):
    """Удаляет каталог службы демона"""
    if not service_dir:
        candidates = [
            os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "WoWSmartRecruiter"),
            os.path.join(os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Programs", "WoWSmartRecruiter")
        ]
        for c in candidates:
            if os.path.exists(c):
                service_dir = c
                break

    if service_dir and os.path.exists(service_dir):
        try:
            shutil.rmtree(service_dir, ignore_errors=True)
        except Exception:
            pass

def run_embedded_uninstall(addons_dir=None, progress_callback=None):
    """
    Полный автономный процесс деинсталляции комплекса аддонов и службы (0 bat-файлов)
    """
    def cb(pct, msg):
        if progress_callback:
            progress_callback(pct, msg)

    cb(10, "Остановка фоновых процессов службы демона...")
    kill_daemon_processes()
    time.sleep(0.5)

    cb(35, "Удаление аддонов комплекса (KeyAutoRecruit, KAR_P2P_Tester, KeyGroupDumper)...")
    removed = remove_addons(addons_dir=addons_dir)

    cb(60, "Очистка записей реестра Windows (Uninstall, Autostart, Config)...")
    remove_registry_records()

    cb(80, "Удаление ярлыков HELLSING с Рабочего стола...")
    remove_desktop_shortcuts()

    cb(90, "Очистка каталога службы демона в Program Files...")
    remove_service_folder()

    cb(100, f"Деинсталляция успешно завершена! (Удалено аддонов комплекса: {removed})")
    return True

class HellsingInstallerAPI:
    """JS-Python bridge API for pywebview"""
    def __init__(self):
        self._window = None
        self._current_wow_dir = get_firestorm_wow_path()
        self._analyzed_info = analyze_wow_folder(self._current_wow_dir)
        self._is_installing = False

    def set_window(self, win):
        self._window = win

    def get_initial_data(self):
        if not self._analyzed_info:
            self._analyzed_info = analyze_wow_folder(self._current_wow_dir)
        data = dict(self._analyzed_info) if self._analyzed_info else {}
        data["installed_status"] = check_installation_in_registry()
        return data

    def uninstall_suite(self):
        if self._is_installing:
            return {"status": "busy"}
        self._is_installing = True
        t = threading.Thread(target=self._run_uninstall, daemon=True)
        t.start()
        return {"status": "started"}

    def _run_uninstall(self):
        try:
            self._log("=========================================", "info")
            self._log("[СТАРТ] Запуск процесса деинсталляции комплекса HELLSING...", "info")
            self._progress(5, "Инициализация деинсталлятора...")

            def on_prog(pct, msg):
                self._progress(pct, msg)
                self._log(msg, "ok" if "✓" in msg else "info")

            reg_info = check_installation_in_registry()
            addons_dir = reg_info.get("addons_dir") or (self._analyzed_info.get("addons_dir") if self._analyzed_info else None)
            
            run_embedded_uninstall(addons_dir=addons_dir, progress_callback=on_prog)
            
            self._progress(100, "Удаление завершено!")
            self._log("✓ Комплекс аддонов и служба HELLSING успешно удалены!", "ok")
            self._is_installing = False
            self._safe_eval("window.onUninstallComplete(true, 'Удаление успешно завершено');")
        except Exception as e:
            self._log(f"💥 Ошибка удаления: {e}", "error")
            self._is_installing = False
            self._safe_eval(f"window.onUninstallComplete(false, '{str(e)}');")

    def browse_folder(self):
        chosen = None
        try:
            res = self._window.create_file_dialog(
                webview.FOLDER_DIALOG,
                directory=self._current_wow_dir if os.path.exists(self._current_wow_dir) else "C:\\"
            )
            if res and len(res) > 0:
                chosen = res[0]
        except Exception:
            pass

        if not chosen:
            # Fallback to tkinter folder dialog
            try:
                import tkinter as tk
                from tkinter import filedialog
                root = tk.Tk()
                root.withdraw()
                root.attributes('-topmost', True)
                chosen = filedialog.askdirectory(
                    title="Выберите корневую папку World of Warcraft",
                    initialdir=self._current_wow_dir
                )
                root.destroy()
            except Exception:
                pass

        if chosen and os.path.exists(chosen):
            self._current_wow_dir = chosen
            self._analyzed_info = analyze_wow_folder(chosen)
            return self._analyzed_info
        return None

    def close(self):
        if self._window:
            self._window.destroy()

    def minimize(self):
        if self._window:
            self._window.minimize()

    def start_installation(self, options):
        if self._is_installing:
            return {"status": "busy"}
        self._is_installing = True
        t = threading.Thread(target=self._run_installation, args=(options,), daemon=True)
        t.start()
        return {"status": "started"}

    def _safe_eval(self, script):
        if self._window:
            try:
                self._window.evaluate_js(script)
            except Exception:
                pass

    def _log(self, text, log_type="normal"):
        clean = text.replace('\\', '\\\\').replace("'", "\\'").replace('\n', ' ')
        self._safe_eval(f"window.onLogMessage('{clean}', '{log_type}');")

    def _progress(self, pct, status_text="", current_file=""):
        clean_status = status_text.replace('\\', '\\\\').replace("'", "\\'")
        clean_file = os.path.basename(current_file).replace('\\', '\\\\').replace("'", "\\'")
        self._safe_eval(f"window.onProgressUpdate({float(pct):.1f}, '{clean_status}', '{clean_file}');")

    def _complete(self, success, message):
        self._is_installing = False
        succ_str = "true" if success else "false"
        clean_msg = message.replace('\\', '\\\\').replace("'", "\\'")
        self._safe_eval(f"window.onInstallComplete({succ_str}, '{clean_msg}');")

    def _run_installation(self, options):
        try:
            self._log("[ИНИЦИАЛИЗАЦИЯ] Старт фонового процесса развертывания Hellsing Recruiter Suite...", "info")
            self._progress(3, "Проверка путей назначения...")

            # Остановка процессов службы, чтобы избежать блокировки файлов
            kill_daemon_processes()

            wow_dir = options.get("wow_dir") or self._current_wow_dir
            analyzed = analyze_wow_folder(wow_dir)
            if not analyzed or not analyzed["root_dir"]:
                self._complete(False, "Выбранный каталог World of Warcraft недоступен!")
                return

            target_addons_dir = analyzed["addons_dir"]
            os.makedirs(target_addons_dir, exist_ok=True)
            self._log(f"[КЛИЕНТ] Целевая папка AddOns: {target_addons_dir}", "info")

            self._progress(15, "Подготовка комплекса набора Hellsing Recruiter Suite...")

            # -------------------------------------------------------------
            # ЭТАП 1: Комплекс набора Alucard (KeyAutoRecruit, KAR_P2P_Tester, KeyGroupDumper)
            # -------------------------------------------------------------
            install_recruiter = options.get("install_recruiter", True)
            if install_recruiter:
                # Поиск исходников аддонов
                source_bases = [
                    BASE_DIR,
                    r"C:\Firestorm\The War Within\_midnight_\Interface\AddOns",
                    r"C:\Firestorm\The War Within\Interface\AddOns",
                    os.path.join(SCRIPT_DIR, "backup_removed_addons"),
                    SCRIPT_DIR
                ]

                addons_to_install = ["KeyAutoRecruit", "KAR_P2P_Tester", "KeyGroupDumper"]
                addon_step_pct = 45.0 / len(addons_to_install)

                for idx, addon_name in enumerate(addons_to_install):
                    src_dir = None
                    for sb in source_bases:
                        cand = os.path.join(sb, addon_name)
                        if os.path.exists(cand) and os.path.isdir(cand):
                            src_dir = cand
                            break

                    target_dir = os.path.join(target_addons_dir, addon_name)
                    if src_dir and os.path.exists(src_dir):
                        # Защита от WinError 32: если источник и приемник совпадают, не перезаписываем файл сам в себя
                        if os.path.abspath(src_dir).lower() == os.path.abspath(target_dir).lower():
                            self._log(f"✓ Аддон {addon_name} уже актуален в целевой папке AddOns.", "ok")
                            pct = 15.0 + (idx + 1) * addon_step_pct
                            self._progress(pct, f"Проверка {addon_name}...", addon_name)
                            continue

                        os.makedirs(target_dir, exist_ok=True)
                        all_addon_files = []
                        for root, _, files in os.walk(src_dir):
                            for f in files:
                                all_addon_files.append(os.path.join(root, f))

                        copied = 0
                        for fpath in all_addon_files:
                            rel = os.path.relpath(fpath, src_dir)
                            dst_file = os.path.join(target_dir, rel)
                            os.makedirs(os.path.dirname(dst_file), exist_ok=True)
                            try:
                                if not (os.path.exists(dst_file) and os.path.samefile(fpath, dst_file)):
                                    shutil.copy2(fpath, dst_file)
                                    copied += 1
                            except Exception:
                                pass

                        pct = 15.0 + (idx + 1) * addon_step_pct
                        self._progress(pct, f"Интеграция {addon_name}...", addon_name)
                        self._log(f"✓ Аддон {addon_name} установлен: {copied} файлов перенесено.", "ok")
                    else:
                        self._log(f"⚠️ Каталог аддона {addon_name} не найден среди источников.", "warning")

            # -------------------------------------------------------------
            # ЭТАП 3: WTF Конфигурация (SET chatLog "1")
            # -------------------------------------------------------------
            if options.get("enable_wtf", True):
                self._progress(74, "Настройка WTF/Config.wtf...")
                wtf_path = analyzed.get("config_wtf")
                if not wtf_path:
                    # Создаем стандартный путь
                    wtf_path = os.path.join(analyzed["root_dir"], "WTF", "Config.wtf")
                
                if enable_chatlog_in_wtf(wtf_path):
                    self._log("✓ Активирована запись чата (SET chatLog \"1\") в WTF/Config.wtf", "ok")
                else:
                    self._log("⚠️ Не удалось обновить Config.wtf (проверьте права доступа)", "warning")

            # -------------------------------------------------------------
            # ЭТАП 4: Фоновый демон службы WoWSmartRecruiter
            # -------------------------------------------------------------
            install_service = options.get("install_service", True)
            target_service_exe = None
            dst_daemon_ico = None
            dst_inst_ico = None
            if install_service:
                kill_daemon_processes()

                # Гарантированный выбор доступного для записи каталога службы без UAC-ошибок
                local_appdata = os.environ.get("LOCALAPPDATA", os.path.expanduser("~"))
                user_service_dir = os.path.join(local_appdata, "Programs", "WoWSmartRecruiter")
                target_service_dir = user_service_dir

                # Проверка: если у процесса есть права администратора, проверяем C:\Program Files
                prog_files = os.environ.get("ProgramFiles", r"C:\Program Files")
                cand_pf = os.path.join(prog_files, "WoWSmartRecruiter")
                try:
                    os.makedirs(cand_pf, exist_ok=True)
                    test_probe = os.path.join(cand_pf, ".write_test")
                    with open(test_probe, "w") as f:
                        f.write("ok")
                    os.remove(test_probe)
                    target_service_dir = cand_pf
                except Exception:
                    target_service_dir = user_service_dir

                os.makedirs(target_service_dir, exist_ok=True)

                self._progress(80, "Развертывание службы демона...")
                self._log(f"[СЛУЖБА ДЕМОНА] Целевой каталог: {target_service_dir}", "info")

                # Копирование exe демона с безопасной защитой от [Errno 13]
                target_service_exe = os.path.join(target_service_dir, "WoWSmartRecruiter.exe")
                src_exe_cands = [
                    os.path.join(BASE_DIR, "WoWSmartRecruiter.exe"),
                    os.path.join(SCRIPT_DIR, "WoWSmartRecruiter.exe"),
                    os.path.join(r"c:\soft\6", "WoWSmartRecruiter.exe"),
                    r"C:\Users\root\Desktop\WoW_AutoRecruit\WoWSmartRecruiter.exe"
                ]
                daemon_exe_copied = False
                for sec in src_exe_cands:
                    if os.path.exists(sec):
                        try:
                            if not (os.path.exists(target_service_exe) and os.path.samefile(sec, target_service_exe)):
                                shutil.copy2(sec, target_service_exe)
                            daemon_exe_copied = True
                            self._log("✓ Демон WoWSmartRecruiter.exe успешно скопирован в каталог службы.", "ok")
                            break
                        except Exception as e:
                            self._log(f"⚠️ Копирование WoWSmartRecruiter.exe: {e}", "warning")

                # Демон работает строго как скомпилированный автономный EXE (без лишних файлов .py)
                dst_clicker = os.path.join(target_service_dir, "wow_voice_clicker.py")
                if os.path.exists(dst_clicker):
                    try:
                        os.remove(dst_clicker)
                    except Exception:
                        pass

                # Копирование иконок Hellsing
                src_daemon_ico = os.path.join(SCRIPT_DIR, "daemon_icon.ico")
                dst_daemon_ico = os.path.join(target_service_dir, "daemon_icon.ico")
                if os.path.exists(src_daemon_ico):
                    try:
                        if not (os.path.exists(dst_daemon_ico) and os.path.samefile(src_daemon_ico, dst_daemon_ico)):
                            shutil.copy2(src_daemon_ico, dst_daemon_ico)
                    except Exception:
                        pass

                src_inst_ico = os.path.join(SCRIPT_DIR, "installer_icon.ico")
                dst_inst_ico = os.path.join(target_service_dir, "installer_icon.ico")
                if os.path.exists(src_inst_ico):
                    try:
                        if not (os.path.exists(dst_inst_ico) and os.path.samefile(src_inst_ico, dst_inst_ico)):
                            shutil.copy2(src_inst_ico, dst_inst_ico)
                    except Exception:
                        pass

                # Копирование UI-ресурсов Hellsing (hellsing_ui.html, alucard_animated_seal.gif)
                for ui_res in ["hellsing_ui.html", "alucard_animated_seal.gif"]:
                    src_res_cands = [
                        os.path.join(SCRIPT_DIR, ui_res),
                        os.path.join(BASE_DIR, ui_res),
                        os.path.join(getattr(sys, '_MEIPASS', ''), ui_res),
                        os.path.join(r"c:\soft\6", ui_res)
                    ]
                    dst_res = os.path.join(target_service_dir, ui_res)
                    for s_c in src_res_cands:
                        if s_c and os.path.exists(s_c):
                            try:
                                if not (os.path.exists(dst_res) and os.path.samefile(s_c, dst_res)):
                                    shutil.copy2(s_c, dst_res)
                                self._log(f"✓ Ресурс {ui_res} скопирован в службу.", "ok")
                                break
                            except Exception:
                                pass

                # Копирование README_HOTKEYS.txt
                src_hotkeys = os.path.join(SCRIPT_DIR, "README_HOTKEYS.txt")
                if os.path.exists(src_hotkeys):
                    try:
                        dst_hotkeys = os.path.join(target_service_dir, "README_HOTKEYS.txt")
                        if not (os.path.exists(dst_hotkeys) and os.path.samefile(src_hotkeys, dst_hotkeys)):
                            shutil.copy2(src_hotkeys, dst_hotkeys)
                    except Exception:
                        pass

                # Копирование текстур оптического маркера
                local_tex_dir = os.path.join(target_service_dir, "Textures")
                os.makedirs(local_tex_dir, exist_ok=True)
                src_tex_cands = [
                    os.path.join(SCRIPT_DIR, "Textures"),
                    r"C:\Users\root\Desktop\WoW_AutoRecruit\Textures",
                    os.path.join(target_addons_dir, "KeyAutoRecruit", "Textures")
                ]
                for tc in src_tex_cands:
                    if os.path.exists(tc):
                        for tf in os.listdir(tc):
                            try:
                                shutil.copy2(os.path.join(tc, tf), os.path.join(local_tex_dir, tf))
                            except Exception:
                                pass
                        break

                # Создание pixel_config.json
                config_data = {
                    "client_x": 20,
                    "client_y": 20,
                    "target_r": 0,
                    "target_g": 255,
                    "target_b": 0,
                    "wow_root_dir": analyzed["root_dir"],
                    "wow_exe_path": analyzed["exe_path"] or "",
                    "wow_log_path": analyzed["log_path"] or "",
                    "wow_desktop_num": 2,
                    "installed_at": time.strftime("%Y-%m-%d %H:%M:%S")
                }
                cfg_path = os.path.join(target_service_dir, "pixel_config.json")
                with open(cfg_path, "w", encoding="utf-8") as f:
                    json.dump(config_data, f, indent=4, ensure_ascii=False)
                self._log(f"✓ Конфигурация оптического кликера сохранена: {cfg_path}", "ok")

                # -------------------------------------------------------------
                # ЭТАП 5: Автозагрузка Windows
                # -------------------------------------------------------------
                if options.get("enable_autostart", True):
                    self._progress(86, "Регистрация службы в автозагрузке Windows...")
                    target_exec = target_service_exe if os.path.exists(target_service_exe) else os.path.join(target_service_dir, "wow_voice_clicker.py")
                    if setup_windows_autostart(target_exec):
                        self._log("✓ Служба добавлена в автозагрузку Windows (запуск в скрытом фоне).", "ok")

                # -------------------------------------------------------------
                # ЭТАП 6: Ярлык на Рабочем столе
                # -------------------------------------------------------------
                self._progress(90, "Создание ярлыка Hellsing на Рабочем столе...")
                target_exec = target_service_exe if os.path.exists(target_service_exe) else os.path.join(target_service_dir, "wow_voice_clicker.py")
                ico_for_shortcut = dst_daemon_ico if os.path.exists(dst_daemon_ico) else dst_inst_ico
                if create_desktop_shortcut(target_exec, "HELLSING WoW Recruiter.lnk", icon_path=ico_for_shortcut):
                    self._log("✓ Создан ярлык на Рабочем столе с Hellsing-иконкой.", "ok")

            # -------------------------------------------------------------
            # ЭТАП 7: Виртуальный рабочий стол и перемещение WoW
            # -------------------------------------------------------------
            if options.get("install_service", True):
                self._progress(94, "Настройка изоляции Virtual Desktop #2...")
                if pyvda:
                    try:
                        vds = pyvda.get_virtual_desktops()
                        if len(vds) < 2:
                            pyvda.VirtualDesktop.create()
                            vds = pyvda.get_virtual_desktops()
                        
                        wow_vd = vds[-1]
                        hwnd = find_wow_hwnd()
                        if hwnd:
                            app = pyvda.AppView(hwnd=hwnd)
                            if app.desktop.number != wow_vd.number:
                                app.move(wow_vd)
                                self._log(f"✓ Окно World of Warcraft изолировано на Virtual Desktop #{wow_vd.number}!", "ok")
                        self._log(f"✓ Виртуальный рабочий стол #{wow_vd.number} сконфигурирован.", "ok")
                    except Exception as e:
                        self._log(f"⚠️ Виртуальный рабочий стол: {e}", "warning")

            # -------------------------------------------------------------
            # ЭТАП 8: Запуск службы в скрытом фоне
            # -------------------------------------------------------------
            if install_service and target_service_exe:
                self._progress(97, "Запуск фонового демона...")
                CREATE_NO_WINDOW = 0x08000000
                DETACHED_PROCESS = 0x00000008
                try:
                    if os.path.exists(target_service_exe):
                        subprocess.Popen(
                            [target_service_exe, "--silent"],
                            cwd=target_service_dir,
                            creationflags=CREATE_NO_WINDOW | DETACHED_PROCESS,
                            close_fds=True
                        )
                    else:
                        pyw = r"C:\Users\root\AppData\Local\Python\pythoncore-3.14-64\pythonw.exe"
                        subprocess.Popen(
                            [pyw, os.path.join(target_service_dir, "wow_voice_clicker.py"), "--silent"],
                            cwd=target_service_dir,
                            creationflags=CREATE_NO_WINDOW | DETACHED_PROCESS,
                            close_fds=True
                        )
                    self._log("✓ Демон успешно запущен в невидимом фоне!", "ok")
                except Exception as e:
                    self._log(f"⚠️ Ошибка запуска демона: {e}", "warning")

            # -------------------------------------------------------------
            # ЭТАП 9: Запись в реестр Windows (Установка и удаление программ)
            # -------------------------------------------------------------
            installed_addons_list = ["KeyAutoRecruit", "KAR_P2P_Tester", "KeyGroupDumper"] if install_recruiter else []
            register_windows_installation(
                service_dir=target_service_dir if options.get("install_service", True) else "",
                wow_dir=analyzed["root_dir"],
                addons_dir=analyzed["addons_dir"],
                installed_addons=installed_addons_list
            )
            self._log("✓ Запись об установке внесена в реестр Windows ('Установка и удаление программ')", "ok")

            self._progress(100, "Установка полностью завершена!")
            self._complete(True, "Все компоненты Hellsing Recruiter успешно установлены!")
            self._log("=========================================", "ok")
            self._log("[ГОТОВО] Нажмите NumPad 4 для быстрого переключения столов или F11 для OpenCV сканера.", "ok")

        except Exception as e:
            self._log(f"💥 Критическая ошибка установки: {e}", "error")
            self._complete(False, str(e))

def main():
    multiprocessing.freeze_support()

    # Автономный режим деинсталляции без bat-файлов
    if "--uninstall" in sys.argv or "--silent-uninstall" in sys.argv:
        is_silent = "--silent-uninstall" in sys.argv
        if not is_silent:
            try:
                import tkinter as tk
                from tkinter import messagebox
                root = tk.Tk()
                root.withdraw()
                root.attributes('-topmost', True)
                ans = messagebox.askyesno(
                    "Удаление HELLSING WoW Recruiter",
                    "Вы действительно хотите удалить комплекс аддонов HELLSING (KeyAutoRecruit, KAR_P2P_Tester, KeyGroupDumper) и остановить фоновую службу?",
                    icon="warning"
                )
                root.destroy()
                if not ans:
                    sys.exit(0)
            except Exception:
                pass

        print("[HELLSING] Запуск автономного процесса деинсталляции (без bat-файлов)...")
        run_embedded_uninstall()
        print("[HELLSING] Деинсталляция успешно завершена.")

        if not is_silent:
            try:
                import tkinter as tk
                from tkinter import messagebox
                root = tk.Tk()
                root.withdraw()
                root.attributes('-topmost', True)
                messagebox.showinfo("Удаление завершено", "Комплекс аддонов и служба HELLSING успешно удалены из системы.")
                root.destroy()
            except Exception:
                pass
        sys.exit(0)

    api = HellsingInstallerAPI()
    html_file = os.path.join(BASE_DIR, "installer_ui.html")
    if not os.path.exists(html_file):
        html_file = os.path.join(SCRIPT_DIR, "installer_ui.html")

    html_content = None
    if os.path.exists(html_file):
        try:
            with open(html_file, "r", encoding="utf-8") as f:
                html_content = f.read()
        except Exception:
            pass

    if html_content:
        window = webview.create_window(
            title="HELLSING • WoW Mythic+ Smart Recruiter Installer",
            html=html_content,
            js_api=api,
            width=960,
            height=720,
            resizable=False,
            frameless=True,
            background_color='#060509'
        )
    else:
        window = webview.create_window(
            title="HELLSING • WoW Mythic+ Smart Recruiter Installer",
            url=html_file,
            js_api=api,
            width=960,
            height=720,
            resizable=False,
            frameless=True,
            background_color='#060509'
        )
    api.set_window(window)

    # Прямой запуск Edge Chromium (WebView2) без WinForms прослойки
    webview.start(gui='edgechromium', debug=False)

if __name__ == "__main__":
    main()
