; Noitamap Mod — Windows installer
; Build:  ISCC installer\noitamap-mod.iss /DAppVer=4.3
; CI:     .github/workflows/release-installer.yml (which also signs via SignPath)
;
; What it does: locates the Noita installation (Steam registry -> Steam library
; folders -> GOG defaults -> manual browse) and copies the `noitamap` mod folder
; into <Noita>\mods\noitamap. The uninstaller removes exactly that folder.

#ifndef AppVer
  #define AppVer "0.0.0-dev"
#endif

#define AppName "Noitamap Mod"
#define Publisher "Acidflow"
#define RepoURL "https://github.com/acidflow-noita/noitamap-mod"

[Setup]
; Stable AppId: winget upgrades and re-installs key off this GUID. Never change it.
AppId={{7E1FBF3E-9C21-4E7B-A2D0-5B6A44C0FBAF}
AppName={#AppName}
AppVersion={#AppVer}
AppPublisher={#Publisher}
AppPublisherURL={#RepoURL}
AppSupportURL={#RepoURL}/issues
AppUpdatesURL={#RepoURL}/releases
DefaultDirName={code:GetDefaultInstallDir}
; The dir IS the mod folder; don't append "Noitamap Mod" to it.
AppendDefaultDirName=no
; Re-installing over an existing mod folder is the normal upgrade path.
DirExistsWarning=no
DisableProgramGroupPage=yes
DisableWelcomePage=no
LicenseFile=..\LICENSE
OutputDir=out
OutputBaseFilename=noitamap-mod-installer-{#AppVer}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Steam sets user-writable ACLs on its install tree, so the default location
; needs no elevation. `PrivilegesRequiredOverridesAllowed` lets a user whose
; Noita lives somewhere admin-only re-run elevated, and lets winget pass
; either scope without the installer fighting it.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
UninstallDisplayName={#AppName} (Noita companion mod)
UninstallDisplayIcon={uninstallexe}
; No ArchitecturesAllowed line: the payload is plain data files, runs anywhere
; (Noita itself is 32-bit; the identifier set for this directive also changed
; across Inno 6.x, so leaving it unset is both correct and portable).

[Files]
Source: "..\noitamap\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Messages]
; The default "Select Destination Location" copy talks about "the program";
; make it say what actually matters here.
WelcomeLabel2=This will install the [name] into your Noita mods folder.%n%nThe installer looks for Noita in your Steam libraries and GOG folders automatically — you only need to pick a folder manually if detection fails.%n%nAfter installing: launch Noita, open Mods, enable "Unsafe mods", and tick "Noita Map". Press M in a run to open the map.

[Code]
// ---------------------------------------------------------------------------
// Noita detection.
// Order: HKCU Steam registry -> that Steam's libraryfolders.vdf (all library
// drives) -> default Steam path -> common GOG paths -> fallback (user browses).
// ---------------------------------------------------------------------------

function NoitaAt(const Root: String): Boolean;
begin
  Result := DirExists(Root + '\steamapps\common\Noita');
end;

// Extract the value of a `"path"  "D:\\SteamLibrary"` line from libraryfolders.vdf.
function VdfPathValue(const Line: String): String;
var
  S: String;
  P: Integer;
begin
  Result := '';
  S := Line;
  P := Pos('"path"', S);
  if P = 0 then Exit;
  Delete(S, 1, P + 5);              // drop through `"path"`
  P := Pos('"', S);                 // opening quote of the value
  if P = 0 then Exit;
  Delete(S, 1, P);
  P := Pos('"', S);                 // closing quote
  if P = 0 then Exit;
  Result := Copy(S, 1, P - 1);
  StringChangeEx(Result, '\\', '\', True);
end;

function FindNoitaDir(): String;
var
  SteamPath, Vdf, Lib: String;
  Lines: TArrayOfString;
  I: Integer;
  Candidates: TArrayOfString;
begin
  Result := '';

  // 1. The running user's Steam install (most reliable; HKCU needs no elevation).
  if RegQueryStringValue(HKEY_CURRENT_USER, 'Software\Valve\Steam', 'SteamPath', SteamPath) then
  begin
    StringChangeEx(SteamPath, '/', '\', True);
    if NoitaAt(SteamPath) then
    begin
      Result := SteamPath + '\steamapps\common\Noita';
      Exit;
    end;
    // 2. Other Steam library drives.
    Vdf := SteamPath + '\steamapps\libraryfolders.vdf';
    if LoadStringsFromFile(Vdf, Lines) then
      for I := 0 to GetArrayLength(Lines) - 1 do
      begin
        Lib := VdfPathValue(Lines[I]);
        if (Lib <> '') and NoitaAt(Lib) then
        begin
          Result := Lib + '\steamapps\common\Noita';
          Exit;
        end;
      end;
  end;

  // 3. Steam's default location without registry help.
  if NoitaAt(ExpandConstant('{autopf32}\Steam')) then
  begin
    Result := ExpandConstant('{autopf32}\Steam\steamapps\common\Noita');
    Exit;
  end;

  // 4. Common GOG locations (GOG installs have no steamapps structure).
  SetArrayLength(Candidates, 3);
  Candidates[0] := ExpandConstant('{autopf32}\GOG Galaxy\Games\Noita');
  Candidates[1] := 'C:\GOG Games\Noita';
  Candidates[2] := ExpandConstant('{autopf}\GOG Galaxy\Games\Noita');
  for I := 0 to GetArrayLength(Candidates) - 1 do
    if FileExists(Candidates[I] + '\noita.exe') then
    begin
      Result := Candidates[I];
      Exit;
    end;
end;

function GetDefaultInstallDir(Param: String): String;
var
  Noita: String;
begin
  Noita := FindNoitaDir();
  if Noita <> '' then
    Result := Noita + '\mods\noitamap'
  else
    // Detection failed: land the wizard on Steam's default so the user only
    // has to correct the drive, not type the whole path.
    Result := ExpandConstant('{autopf32}\Steam\steamapps\common\Noita\mods\noitamap');
end;

// Refuse obviously-wrong manual selections: the chosen folder must be named
// `noitamap` and sit inside a `mods` folder next to noita.exe — otherwise the
// mod silently won't load and the user blames the mod.
function NextButtonClick(CurPageID: Integer): Boolean;
var
  Dir, ModsParent, NoitaDir: String;
begin
  Result := True;
  if CurPageID = wpSelectDir then
  begin
    Dir := WizardForm.DirEdit.Text;
    if ExtractFileName(Dir) <> 'noitamap' then
    begin
      // Be forgiving: if they picked ...\mods, append \noitamap for them.
      if ExtractFileName(Dir) = 'mods' then
        WizardForm.DirEdit.Text := AddBackslash(Dir) + 'noitamap'
      else if MsgBox('The install folder should be Noita''s "mods\noitamap" folder.' + #13#10 +
                     'Currently selected:' + #13#10 + Dir + #13#10#13#10 +
                     'Install anyway?', mbConfirmation, MB_YESNO) = IDNO then
        Result := False;
      Exit;
    end;
    ModsParent := ExtractFileDir(Dir);          // ...\mods
    NoitaDir := ExtractFileDir(ModsParent);     // ...\Noita
    if (ExtractFileName(ModsParent) <> 'mods') or
       (not FileExists(NoitaDir + '\noita.exe')) then
      if MsgBox('No noita.exe found next to this mods folder:' + #13#10 + Dir + #13#10#13#10 +
                'The mod will only load if this is really Noita''s mods folder. Install anyway?',
                mbConfirmation, MB_YESNO) = IDNO then
        Result := False;
  end;
end;