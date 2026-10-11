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
;
; ── Wizard pages ────────────────────────────────────────────────────────────
; This installer copies ~140 KB of mod files into one auto-detected folder.
; Every page that is not "where did it go" or "what do I do now" is noise, so
; all of them are off:
;   Welcome  - says nothing the title bar doesn't
;   License  - GPL-3.0 grants use without acceptance, so a click-through accept
;              dialog is legally meaningless here. The license text is still
;              CONVEYED with the binary (see LICENSE in [Files]), which is what
;              GPLv3 actually requires.
;   Ready    - "click Install to continue" after we already know everything
;   Group    - no program group to choose; [Icons] places a fixed one
;   Dir      - skipped by ShouldSkipPage when Noita was auto-detected, and
;              shown only when detection failed and we genuinely need input
; What remains: (destination, only if needed) -> progress -> finished.
DisableWelcomePage=yes
DisableReadyPage=yes
DisableProgramGroupPage=yes
DisableFinishedPage=no
OutputDir=out
OutputBaseFilename=noitamap-mod-installer-{#AppVer}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Icon of the installer EXE itself, and of the uninstaller Inno generates from
; it. Without this you get Inno's generic setup icon, which is what makes an
; installer look like anonymous downloaded software. Built from the site's own
; favicon assets: 16/32/48 DIB entries plus a 256x256 PNG-compressed entry so
; Windows has a crisp source at high DPI and in large-icon Explorer views.
; Path is relative to this .iss file.
SetupIconFile=noitamap.ico
; Steam sets user-writable ACLs on its install tree, so the default location
; needs no elevation and there is nothing for the user to decide.
;
; NOTE: do NOT add `dialog` to PrivilegesRequiredOverridesAllowed. That flag is
; exactly what produces the "Install for all users / Install for me only"
; chooser -- a meaningless question here, since the destination is Noita's own
; mods folder either way, not a per-user vs per-machine program location.
; `commandline` alone keeps /ALLUSERS working for `winget --scope machine` and
; for the rare admin-only Noita install, without ever showing a page.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline
UninstallDisplayName={#AppName} (Noita companion mod)
; Point Add/Remove Programs at the icon rather than at {uninstallexe}: the
; uninstaller does carry SetupIconFile's icon, but naming the .ico explicitly
; keeps the entry correct even if the uninstaller is mid-replacement, and gives
; Windows the 256px variant to scale from.
UninstallDisplayIcon={app}\noitamap.ico
; Keep the uninstaller OUT of {app}. {app} is Noita's mods\noitamap folder, and
; putting unins000.exe there costs three things: Noita's mod loader sees a stray
; exe inside a mod folder; a running uninstaller cannot delete itself before the
; directory-removal pass, so mods\noitamap survives an uninstall; and if the user
; deletes the mod folder by hand (the common way to remove a Noita mod) the
; uninstaller dies with it while its Add/Remove Programs entry lives on, pointing
; at a missing exe -- a zombie entry that needs regedit to clear.
;
; Out here, that same hand-deletion leaves a WORKING uninstaller: it finds nothing
; to remove, deregisters itself, and disappears. {localappdata}\Programs is the
; conventional per-user install location, and DisableProgramGroupPage plus the
; [Icons] entry below keep it reachable from the Start menu.
UninstallFilesDir={localappdata}\Programs\Noitamap Mod
; No ArchitecturesAllowed line: the payload is plain data files, runs anywhere
; (Noita itself is 32-bit; the identifier set for this directive also changed
; across Inno 6.x, so leaving it unset is both correct and portable).

[Files]
Source: "..\noitamap\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
; GPLv3 requires the license to travel WITH the binary distribution. The wizard
; no longer shows a license page (acceptance isn't required to use GPL software),
; so conveying it as a file is what keeps us compliant. Noita ignores non-mod
; files in a mod folder.
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
; Installed so UninstallDisplayIcon has a stable file to point at, and so the
; Start-menu folder shortcut has an icon. Noita ignores non-mod files.
Source: "noitamap.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Discoverability for the relocated uninstaller. Settings -> Apps and
; `winget uninstall Acidflow.NoitamapMod` both work regardless; this is for
; users who go looking for an uninstaller by hand. Also gives them a shortcut
; straight to the mod folder, which is where they'd otherwise be hunting.
Name: "{autoprograms}\Noitamap Mod\Uninstall Noitamap Mod"; Filename: "{uninstallexe}"
Name: "{autoprograms}\Noitamap Mod\Noitamap Mod folder"; Filename: "{app}"; IconFilename: "{app}\noitamap.ico"

[Messages]
; The finished page is mandatory here (DisableFinishedPage=no) and is the only
; place the user is told the mod still has to be switched on inside Noita.
FinishedHeadingLabel=Installation complete
; Default is "Click Finish to exit Setup." -- the button already says Finish.
FinishedLabelNoIcons=
ClickFinish=
; The destination page only appears when auto-detection failed, so its wording
; should say what we actually need from the user rather than the stock
; "Setup will install [name] into the following folder".
WizardSelectDir=Where is Noita installed?
SelectDirDesc=Noita could not be found automatically.
SelectDirLabel3=Choose Noita's mods folder. The mod must end up in a folder named "noitamap" inside it — for example D:\SteamLibrary\steamapps\common\Noita\mods\noitamap
SelectDirBrowseLabel=Click Next to continue, or Browse to pick a different folder.

[Code]
// ---------------------------------------------------------------------------
// Noita detection.
// Order: HKCU Steam registry -> that Steam's libraryfolders.vdf (all library
// drives) -> default Steam path -> common GOG paths -> fallback (user browses).
// ---------------------------------------------------------------------------

var
  NoitaCached: String;
  NoitaResolved: Boolean;
  UpgradeTarget: String;
  UpgradeBackup: String;
  UpgradeInstalled: Boolean;

function IsModInstallDir(const Dir: String): Boolean;
var
  App, Mods: String;
begin
  App := RemoveBackslashUnlessRoot(ExpandFileName(Dir));
  Mods := ExtractFileDir(App);
  Result := (CompareText(ExtractFileName(App), 'noitamap') = 0) and
    (CompareText(ExtractFileName(Mods), 'mods') = 0) and
    FileExists(ExtractFileDir(Mods) + '\noita.exe');
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  App: String;
begin
  Result := '';
  App := RemoveBackslashUnlessRoot(ExpandFileName(ExpandConstant('{app}')));
  // This also validates remembered destinations and silent /DIR installs.
  // Never replace an arbitrary folder accepted by an older installer.
  if not IsModInstallDir(App) then
    Result := 'Choose <Noita>\mods\noitamap, where <Noita> contains noita.exe.'
  else if DirExists(App + '.previous') or FileExists(App + '.previous') then
    Result := 'A previous upgrade backup already exists:' + #13#10 +
      App + '.previous' + #13#10 +
      'Recover or move that backup before installing again.';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Backup: String;
begin
  if CurStep = ssInstall then
  begin
    UpgradeTarget := RemoveBackslashUnlessRoot(ExpandFileName(ExpandConstant('{app}')));
    if not IsModInstallDir(UpgradeTarget) then
      RaiseException('Refusing to replace a folder outside Noita''s mods\noitamap.');
    if DirExists(UpgradeTarget) then
    begin
      // Rename on the same volume, keeping the complete old version available
      // until installation succeeds. Inno now copies into a clean directory.
      Backup := UpgradeTarget + '.previous';
      if not RenameFile(UpgradeTarget, Backup) then
        RaiseException('Could not back up the existing mod. Close Noita and try again.');
      UpgradeBackup := Backup;
      Log('Backed up the existing mod to ' + UpgradeBackup);
    end;
  end
  else if CurStep = ssPostInstall then
  begin
    UpgradeInstalled := True;
    if UpgradeBackup <> '' then
    begin
      // DelTree removes junctions themselves, without following their targets.
      if DelTree(UpgradeBackup, True, True, True) then
        UpgradeBackup := ''
      else
      begin
        Log('Could not remove the old mod backup: ' + UpgradeBackup);
        SuppressibleMsgBox('The new mod is installed, but the old backup could not be removed.' + #13#10 +
          'Close Noita and remove:' + #13#10 + UpgradeBackup, mbInformation, MB_OK, IDOK);
      end;
    end;
  end;
end;

procedure DeinitializeSetup;
begin
  // Inno rolls back its own partial installation first. Restore the old folder
  // on cancellation/error, including files no longer shipped by this version.
  if (UpgradeBackup <> '') and (not UpgradeInstalled) then
  begin
    if DirExists(UpgradeTarget) then
      DelTree(UpgradeTarget, True, True, True);
    if RenameFile(UpgradeBackup, UpgradeTarget) then
      Log('Restored the previous mod after an incomplete installation.')
    else
    begin
      Log('Previous mod preserved at ' + UpgradeBackup);
      SuppressibleMsgBox('Installation did not complete. Your previous mod is preserved at:' + #13#10 +
        UpgradeBackup + #13#10 + 'Restore it to:' + #13#10 + UpgradeTarget,
        mbError, MB_OK, IDOK);
    end;
  end;
end;

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
  if NoitaAt(ExpandConstant('{commonpf32}\Steam')) then
  begin
    Result := ExpandConstant('{commonpf32}\Steam\steamapps\common\Noita');
    Exit;
  end;

  // 4. Common GOG locations (GOG installs have no steamapps structure).
  SetArrayLength(Candidates, 3);
  Candidates[0] := ExpandConstant('{commonpf32}\GOG Galaxy\Games\Noita');
  Candidates[1] := 'C:\GOG Games\Noita';
  Candidates[2] := ExpandConstant('{commonpf}\GOG Galaxy\Games\Noita');
  for I := 0 to GetArrayLength(Candidates) - 1 do
    if FileExists(Candidates[I] + '\noita.exe') then
    begin
      Result := Candidates[I];
      Exit;
    end;
end;

// Detection runs once and is reused: DefaultDirName and ShouldSkipPage both
// need the answer, and re-walking the registry and every library VDF per call
// would be wasteful (and could disagree with itself mid-wizard).
function ResolveNoita(): String;
begin
  if not NoitaResolved then
  begin
    NoitaCached := FindNoitaDir();
    NoitaResolved := True;
  end;
  Result := NoitaCached;
end;

function GetDefaultInstallDir(Param: String): String;
var
  Noita: String;
begin
  Noita := ResolveNoita();
  if Noita <> '' then
    Result := Noita + '\mods\noitamap'
  else
    // Detection failed: land the wizard on Steam's default so the user only
    // has to correct the drive, not type the whole path.
    Result := ExpandConstant('{commonpf32}\Steam\steamapps\common\Noita\mods\noitamap');
end;

// Only ask where to install when we could not work it out. When Noita was
// detected, the destination page is a rhetorical question -- the answer is
// always "that folder" -- so skip straight to installing. The finished page
// reports where the files landed, so nothing is hidden from the user.
function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := (PageID = wpSelectDir) and (ResolveNoita() <> '') and IsModInstallDir(WizardDirValue());
end;

// With Welcome and Ready gone, the finished page is the only place left to say
// what happened and what the user has to do in-game -- so it has to carry both.
// It is NOT optional: an installer that copies files and vanishes leaves the
// user with a mod that silently does nothing, because Noita ships it disabled
// and refuses to load it at all until unsafe mods are allowed.
procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpFinished then
    WizardForm.FinishedLabel.Caption :=
      'Don''t forget to enable the Noitamap Mod in the Noita Mods list.' + #13#10 +
      '"Unsafe mods: Allowed" is required for it to work.' + #13#10#13#10 +
      'In Noita:' + #13#10 +
      '  1.  Open "Mods" from the main menu' + #13#10 +
      '  2.  Click "Unsafe mods: Disabled" and confirm with "Yes"' + #13#10 +
      '       (the mod needs this to read your position in the world)' + #13#10 +
      '  3.  Tick "Noita Map" in the mod list so it shows [x]' + #13#10 +
      '  4.  Press M during a run to open the map at your location' + #13#10#13#10 +
      'Installed to:' + #13#10 +
      ExpandConstant('{app}');
end;

// Refuse obviously-wrong manual selections: the chosen folder must be named
// `noitamap` and sit inside a `mods` folder next to noita.exe — otherwise the
// mod silently won't load and the user blames the mod.
function NextButtonClick(CurPageID: Integer): Boolean;
var
  Dir: String;
begin
  Result := True;
  if CurPageID = wpSelectDir then
  begin
    Dir := RemoveBackslashUnlessRoot(ExpandFileName(WizardForm.DirEdit.Text));
    // Be forgiving: if they picked ...\mods, append \noitamap for them.
    if CompareText(ExtractFileName(Dir), 'mods') = 0 then
      Dir := AddBackslash(Dir) + 'noitamap';
    WizardForm.DirEdit.Text := Dir;
    Result := IsModInstallDir(Dir);
    if not Result then
      SuppressibleMsgBox('Choose Noita''s mods folder or its noitamap subfolder.' + #13#10 +
        'The destination must be <Noita>\mods\noitamap, where <Noita> contains noita.exe.' + #13#10 +
        'Selected: ' + Dir,
        mbError, MB_OK, IDOK);
  end;
end;

// Remove the mod folder itself, not just the files in it.
//
// Inno deletes the files it logged and then removes directories only if they
// are empty. Even with the uninstaller relocated out of {app}, anything Noita
// or the user dropped into the folder would keep it (and files\, files\audio\)
// alive as empty-looking leftovers in the mods list. usPostUninstall runs after
// the logged files are gone, so a DelTree here finishes the job.
//
// The guard remains necessary for destinations accepted by older installers,
// which allowed users to override the validation. Never recursively delete an
// arbitrary folder: only remove a folder that is literally named
// "noitamap" and sits directly inside a folder named "mods".
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  App: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    App := RemoveBackslashUnlessRoot(ExpandConstant('{app}'));
    if (CompareText(ExtractFileName(App), 'noitamap') = 0) and
       (CompareText(ExtractFileName(ExtractFileDir(App)), 'mods') = 0) then
      DelTree(App, True, True, True);
  end;
end;
