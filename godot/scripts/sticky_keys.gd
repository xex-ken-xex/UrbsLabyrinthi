class_name StickyKeys
extends RefCounted
## Windows の固定キーのショートカット(Shift を5回押すと出る確認の窓)を、ゲームが前面にある間だけ止める(ken 10/16)。
## 転がりを Shift に割り当てているので、連打すると窓が出て、ゲームから前面が奪われる。
## 前面になったら SystemParametersInfo(SPI_SETSTICKYKEYS)で SKF_HOTKEYACTIVE を外し、前面から離れるときと終わるときに戻す。
## 設定には保存しない(SPIF_UPDATEINIFILE を付けない)。落ちても、サインインし直せば元に戻る。
## 外したときだけ印(user://sticky_keys_off)を置き、戻すときは印があるときだけ戻す(元から切っている人の設定を変えない)。
## PowerShell は裏で動かす(待たない)。Windows 以外では何もしない。

const MARK := "user://sticky_keys_off"
const SKF_HOTKEYACTIVE := 4

static var _off := false

static func enabled() -> bool:
	return OS.get_name() == "Windows" and DisplayServer.get_name() != "headless"

## SystemParametersInfo を呼ぶ PowerShell。suppress: true で外す、false で戻す
static func script(suppress: bool, mark_path: String) -> String:
	var m := mark_path.replace("'", "''")
	var head := "$s='using System;using System.Runtime.InteropServices;public class SK{[StructLayout(LayoutKind.Sequential)]public struct S{public uint cb;public uint f;}" + \
		"[DllImport(\"user32.dll\")]public static extern bool SystemParametersInfo(uint a,uint b,ref S c,uint d);}';Add-Type $s;" + \
		"$v=New-Object SK+S;$v.cb=8;[void][SK]::SystemParametersInfo(0x3A,8,[ref]$v,0);"
	if suppress:
		return head + "if(($v.f -band %d) -ne 0){$v.f=$v.f -band (-bnot %d);[void][SK]::SystemParametersInfo(0x3B,8,[ref]$v,0);Set-Content -LiteralPath '%s' -Value 1}" % [SKF_HOTKEYACTIVE, SKF_HOTKEYACTIVE, m]
	return head + "if(Test-Path -LiteralPath '%s'){$v.f=$v.f -bor %d;[void][SK]::SystemParametersInfo(0x3B,8,[ref]$v,0);Remove-Item -LiteralPath '%s'}" % [m, SKF_HOTKEYACTIVE, m]

static func _run(suppress: bool) -> void:
	if not enabled():
		return
	var ps := script(suppress, ProjectSettings.globalize_path(MARK).replace("/", "\\"))
	var enc := Marshalls.raw_to_base64(ps.to_utf16_buffer())
	OS.create_process("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-EncodedCommand", enc])

## ゲームが前面になった
static func suppress() -> void:
	if _off:
		return
	_off = true
	_run(true)

## 前面から離れた、または終わる
static func restore() -> void:
	if not _off:
		return
	_off = false
	_run(false)
