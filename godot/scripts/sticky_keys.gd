class_name StickyKeys
extends RefCounted
## Windows の固定キーのショートカット(Shift を5回押すと出る確認の窓)を、ゲームが前面にある間だけ止める(ken 10/16)。
## 転がりを Shift に割り当てているので、連打すると窓が出て、ゲームから前面が奪われる。
## SystemParametersInfo(SPI_SETSTICKYKEYS)で SKF_HOTKEYACTIVE と SKF_CONFIRMHOTKEY を外し、前面から離れたときと終わったときに戻す。
## 設定には保存しない(SPIF_UPDATEINIFILE を付けない)。落ちても、サインインし直せば元に戻る。
##
## 起動のときに PowerShell を一つだけ裏で動かし、ゲームが終わるまで見張らせる(ken 10/18「でますね」の直し)。
## 前は前面の出入りのたびに PowerShell を起こしていたが、Add-Type に数秒かかるうえ、外す・戻すの順が入れ違うことがあった。
## 見張りは 0.2秒ごとに前面の窓の持ち主を見て、ゲームなら外し、ほかなら戻す。ゲームが終われば(落ちても)戻して抜ける。
## 元の値は印(user://sticky_keys_off)に書く。見張りが途中で殺されても、次の起動で印から元の値を戻せる。
## 外した・戻した・失敗したは user://sticky_keys.log に書く(Windows で効かないとき、これを見る)。

const MARK := "user://sticky_keys_off"
const LOG := "user://sticky_keys.log"
const FLAGS := 12   # SKF_HOTKEYACTIVE(4) | SKF_CONFIRMHOTKEY(8)

static var _started := false

static func enabled() -> bool:
	return OS.get_name() == "Windows" and DisplayServer.get_name() != "headless"

static func _q(s: String) -> String:
	return "'" + s.replace("'", "''") + "'"

## ゲーム(pid)が終わるまで見張る PowerShell
static func script(pid: int, mark_path: String, log_path: String) -> String:
	var cs := "using System;using System.Runtime.InteropServices;public class SK{[StructLayout(LayoutKind.Sequential)]public struct S{public uint cb;public uint f;}" + \
		"[DllImport(\"user32.dll\")]static extern bool SystemParametersInfo(uint a,uint b,ref S c,uint d);" + \
		"[DllImport(\"user32.dll\")]static extern IntPtr GetForegroundWindow();" + \
		"[DllImport(\"user32.dll\")]static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);" + \
		"public static uint Get(){S v=new S();v.cb=8;SystemParametersInfo(0x3A,8,ref v,0);return v.f;}" + \
		"static bool Put(uint f){S v=new S();v.cb=8;v.f=f;return SystemParametersInfo(0x3B,8,ref v,0);}" + \
		"public static bool Off(){return Put(Get()&~%du);}" % FLAGS + \
		"public static bool On(uint o){return Put(Get()|o);}" + \
		"public static uint Fg(){uint p;GetWindowThreadProcessId(GetForegroundWindow(),out p);return p;}}"
	var lines := [
		"$ErrorActionPreference='Stop';$mark=%s;$log=%s;$gp=%d;$off=$false;$orig=0" % [_q(mark_path), _q(log_path), pid],
		"function L($t){try{Add-Content -LiteralPath $log -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss')+' '+$t)}catch{}}",
		"try{",
		"Add-Type -TypeDefinition %s" % _q(cs),
		"$f=[SK]::Get();$orig=$f -band %d" % FLAGS,
		"if(Test-Path -LiteralPath $mark){$orig=[uint32](Get-Content -LiteralPath $mark -TotalCount 1)}",
		"L ('start pid='+$gp+' flags='+$f+' orig='+$orig)",
		"if(($orig -band 4) -eq 0){L 'shortcut already off';Remove-Item -LiteralPath $mark -ErrorAction SilentlyContinue;exit}",
		"Set-Content -LiteralPath $mark -Value $orig",
		"$p=Get-Process -Id $gp",
		"while(-not $p.HasExited){",
		"$fg=([SK]::Fg() -eq $gp)",
		"if($fg -and -not $off){$off=$true;L ('off '+[SK]::Off())}",
		"elseif(-not $fg -and $off){$off=$false;L ('on '+[SK]::On($orig))}",
		"Start-Sleep -Milliseconds 200}",
		"}catch{L ('error: '+$_)}",
		"finally{if($off){try{L ('on(end) '+[SK]::On($orig))}catch{L ('error: '+$_)}};if($orig -ne 0){Remove-Item -LiteralPath $mark -ErrorAction SilentlyContinue};L 'end'}",
	]
	return "\n".join(lines)

## 起動のときに一度だけ呼ぶ。Windows 以外では何もしない
static func start() -> void:
	if _started or not enabled():
		return
	_started = true
	var ps := script(OS.get_process_id(), _win(MARK), _win(LOG))
	var enc := Marshalls.raw_to_base64(ps.to_utf16_buffer())
	var id := OS.create_process("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-EncodedCommand", enc])
	print("[urbs] 固定キー: 見張りを起動 (pid %d)" % id)

static func _win(p: String) -> String:
	return ProjectSettings.globalize_path(p).replace("/", "\\")
