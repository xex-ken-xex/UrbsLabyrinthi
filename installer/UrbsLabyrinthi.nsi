; Windows 向けのインストーラー(NSIS 3)。tools/make-installer.sh から作る。
;   makensis /DSRC=<展開した UrbsLabyrinthi-windows フォルダ> /DVERSION=<版> /DOUTFILE=<出力> installer/UrbsLabyrinthi.nsi
; 管理者の権限が要らないよう、ユーザーごとに入れる(既定は %LOCALAPPDATA%\Programs\UrbsLabyrinthi)。
; 実行ファイルの隣の assets\ に差し替え画像を置けるよう、書き込める場所にしている。
; セーブは %APPDATA%\Godot\app_userdata\Urbs Labyrinthi\ にあり、アンインストールしても消えない。

; ゲームが x64 専用なので、インストーラーも 64bit にする
Target amd64-unicode
SetCompressor /SOLID lzma
RequestExecutionLevel user

!ifndef SRC
  !error "SRC(展開した UrbsLabyrinthi-windows フォルダ)を /DSRC= で渡す"
!endif
!ifndef VERSION
  !define VERSION "dev"
!endif
!ifndef OUTFILE
  !define OUTFILE "UrbsLabyrinthi-setup.exe"
!endif

!define APP "Urbs Labyrinthi"
!define APPKEY "UrbsLabyrinthi"
!define UNINST "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPKEY}"

Name "${APP}"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\${APPKEY}"
InstallDirRegKey HKCU "Software\${APPKEY}" "InstallDir"
BrandingText "${APP} ${VERSION}"

!include "MUI2.nsh"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\UrbsLabyrinthi.exe"
!define MUI_FINISHPAGE_RUN_TEXT "${APP} を起動する"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Japanese"

Section "ゲーム本体" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "${SRC}\UrbsLabyrinthi.exe"
  File "${SRC}\UrbsLabyrinthi.pck"
  File "${SRC}\UrbsLabyrinthi.console.exe"
  File "${SRC}\run-with-log.bat"
  File "${SRC}\README.md"
  File "${SRC}\VERSION"
  SetOutPath "$INSTDIR\assets"
  File "${SRC}\assets\README.txt"
  SetOutPath "$INSTDIR\assets-guide"
  File /r "${SRC}\assets-guide\*.*"
  SetOutPath "$INSTDIR"

  CreateDirectory "$SMPROGRAMS\${APP}"
  CreateShortcut "$SMPROGRAMS\${APP}\${APP}.lnk" "$INSTDIR\UrbsLabyrinthi.exe"
  CreateShortcut "$SMPROGRAMS\${APP}\ログを取って起動.lnk" "$INSTDIR\run-with-log.bat"
  CreateShortcut "$SMPROGRAMS\${APP}\差し替え画像のフォルダ.lnk" "$INSTDIR\assets"
  CreateShortcut "$SMPROGRAMS\${APP}\アンインストール.lnk" "$INSTDIR\uninstall.exe"

  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKCU "Software\${APPKEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINST}" "DisplayName" "${APP}"
  WriteRegStr HKCU "${UNINST}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINST}" "Publisher" "xex-ken-xex"
  WriteRegStr HKCU "${UNINST}" "DisplayIcon" "$INSTDIR\UrbsLabyrinthi.exe"
  WriteRegStr HKCU "${UNINST}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKCU "${UNINST}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST}" "NoRepair" 1
SectionEnd

Section "デスクトップにショートカット" SecDesktop
  CreateShortcut "$DESKTOP\${APP}.lnk" "$INSTDIR\UrbsLabyrinthi.exe"
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} "ゲームの実行ファイルと、差し替え画像の説明。"
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "デスクトップに起動用のショートカットを置く。"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
  Delete "$INSTDIR\UrbsLabyrinthi.exe"
  Delete "$INSTDIR\UrbsLabyrinthi.pck"
  Delete "$INSTDIR\UrbsLabyrinthi.pck.new"
  Delete "$INSTDIR\UrbsLabyrinthi.console.exe"
  Delete "$INSTDIR\run-with-log.bat"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\VERSION"
  Delete "$INSTDIR\urbs-log.txt"
  Delete "$INSTDIR\assets\README.txt"
  RMDir /r "$INSTDIR\assets-guide"
  Delete "$INSTDIR\uninstall.exe"
  ; assets\ に自分で置いた画像は残す(空なら消える)
  RMDir "$INSTDIR\assets"
  RMDir "$INSTDIR"
  Delete "$DESKTOP\${APP}.lnk"
  RMDir /r "$SMPROGRAMS\${APP}"
  DeleteRegKey HKCU "${UNINST}"
  DeleteRegKey HKCU "Software\${APPKEY}"
SectionEnd
