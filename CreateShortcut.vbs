' VBScript to create a desktop shortcut with icon
Set oWS = WScript.CreateObject("WScript.Shell")
sLinkFile = oWS.SpecialFolders("Desktop") & "\D2R Multi-Client Launcher.lnk"
Set oLink = oWS.CreateShortcut(sLinkFile)

' Get the script directory
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
batFile = scriptDir & "\Launch_D2R_Launcher.bat"
iconFile = scriptDir & "\D2R_Launcher.ico"

oLink.TargetPath = batFile
oLink.WorkingDirectory = scriptDir
oLink.Description = "Diablo II Resurrected Multi-Client Launcher"
If CreateObject("Scripting.FileSystemObject").FileExists(iconFile) Then
    oLink.IconLocation = iconFile
End If
oLink.Save

WScript.Echo "Shortcut created on desktop: D2R Multi-Client Launcher"
