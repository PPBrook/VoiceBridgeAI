; Inno Setup script — built by build-app.ps1 with /D defines:
;   AppName, AppDisplayName, SourceDir, OutputDir, OutputBaseFilename

#ifndef AppName
  #define AppName "VoiceBridgeAI"
#endif
#if AppName == "VoiceBridgeAI-Local"
  #define AppIdValue "{{B8C4D0F2-9E3E-5B7C-0D1F-2E3F4A5B6C7D}}"
#else
  #define AppIdValue "{{A7B3C9E1-8F2D-4A6B-9C0E-1D2E3F4A5B6C}}"
#endif
#ifndef AppDisplayName
  #define AppDisplayName "VoiceBridgeAI"
#endif
#ifndef SourceDir
  #define SourceDir "..\dist\VoiceBridgeAI-Cloud"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename "VoiceBridgeAI-Cloud-Setup"
#endif

[Setup]
AppId={#AppIdValue}
AppName={#AppDisplayName}
AppVersion=0.1.0
AppPublisher=VoiceBridgeAI
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppDisplayName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\VoiceBridgeAI.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppDisplayName}"; Filename: "{app}\VoiceBridgeAI.exe"
Name: "{autodesktop}\{#AppDisplayName}"; Filename: "{app}\VoiceBridgeAI.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\VoiceBridgeAI.exe"; Description: "启动 {#AppDisplayName}"; Flags: postinstall nowait skipifsilent

[Code]
function InitializeSetup: Boolean;
begin
  Result := True;
end;
