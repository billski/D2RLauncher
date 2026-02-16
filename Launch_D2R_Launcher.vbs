' VBScript launcher that properly sets the taskbar icon and handles admin elevation
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

' Get script directory
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psScript = scriptDir & "\D2R_MultiClient_Launcher.ps1"
iconFile = scriptDir & "\D2R_Launcher.ico"
batFile = scriptDir & "\Launch_D2R_Launcher.bat"

' Check for admin rights using a simple method
On Error Resume Next
Set wshShell = CreateObject("WScript.Shell")
Set wshEnv = wshShell.Environment("PROCESS")
adminCheck = wshShell.Run("net session", 0, True)
On Error Goto 0

' If not admin, request elevation
If adminCheck <> 0 Then
    ' Request admin elevation
    Set objShell = CreateObject("Shell.Application")
    objShell.ShellExecute "wscript.exe", """" & WScript.ScriptFullName & """", "", "runas", 1
    WScript.Quit
End If

' Create a shortcut in the app folder to launch with icon
shortcutPath = scriptDir & "\D2R_Launcher_Shortcut.lnk"
Set shortcut = shell.CreateShortcut(shortcutPath)
shortcut.TargetPath = "powershell.exe"
shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -File """ & psScript & """"
shortcut.WorkingDirectory = scriptDir
shortcut.WindowStyle = 1 ' Normal window
If fso.FileExists(iconFile) Then
    shortcut.IconLocation = iconFile & ",0"
End If
shortcut.Description = "D2R Multi-Client Launcher"
shortcut.Save

' Launch via the shortcut (this ensures the icon shows in taskbar)
shell.Run """" & shortcutPath & """", 1, False
