# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['wow_voice_clicker.py'],
    pathex=[],
    binaries=[],
    datas=[('Textures', 'Textures'), ('hellsing_ui.html', '.'), ('alucard_animated_seal.gif', '.'), ('kar_container.png', '.'), ('daemon_icon.ico', '.')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', '_tkinter', 'tcl', 'tk'],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='WoWSmartRecruiter',
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
    icon=['daemon_icon.ico'],
)
