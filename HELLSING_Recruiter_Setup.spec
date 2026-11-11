# -*- mode: python ; coding: utf-8 -*-

import os
import sys

block_cipher = None
work_dir = os.path.abspath(os.path.dirname(os.path.abspath(SPEC)) if 'SPEC' in locals() else os.getcwd())

datas = [
    (os.path.join(work_dir, 'installer_ui.html'), '.'),
    (os.path.join(work_dir, 'hellsing_ui.html'), '.'),
    (os.path.join(work_dir, 'alucard_animated_seal.gif'), '.'),
    (os.path.join(work_dir, 'installer_icon.ico'), '.'),
    (os.path.join(work_dir, 'installer_icon.png'), '.'),
    (os.path.join(work_dir, 'daemon_icon.ico'), '.'),
    (os.path.join(work_dir, 'daemon_icon.png'), '.'),
    (os.path.join(work_dir, 'README_HOTKEYS.txt'), '.'),
    (os.path.join(work_dir, 'WoWSmartRecruiter.exe'), '.'),
    (os.path.join(work_dir, 'Textures'), 'Textures'),
    (os.path.join(work_dir, 'AddOns', 'KeyAutoRecruit'), 'KeyAutoRecruit'),
    (os.path.join(work_dir, 'AddOns', 'KAR_P2P_Tester'), 'KAR_P2P_Tester'),
    (os.path.join(work_dir, 'AddOns', 'KeyGroupDumper'), 'KeyGroupDumper'),
]

hiddenimports = [
    'webview',
    'webview.platforms.winforms',
    'webview.platforms.edgechromium',
    'win32gui',
    'win32api',
    'win32process',
    'win32service',
    'win32com.client',
    'winreg',
    'pyvda',
    'psutil',
    'PIL',
    'ctypes'
]

a = Analysis(
    [os.path.join(work_dir, 'html_installer.py')],
    pathex=[work_dir],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['KeyHeuristics', 'KeyAutoSeeker', 'matplotlib', 'scipy', 'torch', 'PyQt5', 'PyQt6', 'PySide2', 'PySide6', 'tkinter', '_tkinter', 'tcl', 'tk'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='HELLSING_Recruiter_Setup',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=[os.path.join(work_dir, 'installer_icon.ico')],
)
