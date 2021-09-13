; UTF-8 with BOM

#ifndef ThisAppId
    #error 'Undefined variable: ThisAppId'
#else
    #pragma message "ThisAppId = " + ThisAppId
#endif

#ifndef ThatAppId
    #error 'Undefined variable: ThatAppId'
#else
    #pragma message "ThatAppId = " + ThatAppId
#endif

#if SameText(ThisAppId, ThatAppId)
    #error 'ThisAppId and ThatAppId are identical'
#endif

#define MyAppName " WaitForItToEnd'" + ThisAppId + "'wanna`uninstall'" + ThatAppId

#ifdef Enable64BitMode
    #define MyAppName MyAppName + " - x64"
#else
    #define MyAppName MyAppName + " - x86"
#endif


[Setup]
AppId={#ThisAppId}
AppName={#MyAppName}
AppVerName={#MyAppName}
DefaultDirName={autopf}\{#MyAppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline dialog
SetupLogging=yes

#ifdef Enable64BitMode
ArchitecturesInstallIn64BitMode=x64
#endif


[Files]
Source: "compiler:*"; DestDir: "{app}"; Excludes: "\unins*.*"; Flags: ignoreversion recursesubdirs createallsubdirs


[Code]

const
    UninstallParameter = '/SILENT /SUPPRESSMSGBOXES /NORESTART /LOG';


function LaunchUninstallerAndWaitForItToEnd(const UninstallString: String): Integer;
begin
    Log(Format('Executing "%s" with "%s"', [UninstallString, UninstallParameter]));

    if Exec(UninstallString, UninstallParameter, '', SW_SHOWNORMAL, ewWaitUntilTerminated, Result) then
        Log(Format('Exit code: 0x%x', [Result]))
    else
        Log(Format('System error occurred: 0x%x, %s', [Result, SysErrorMessage(Result)]));

    if 0 <> Result then
        exit;

    Log('Uninstallation complete');
end;


function TryToUninstall(const RegRootKey: Integer; const RegSubKeyName: String): Boolean;
var
    UninstallString: String;
begin
    Result := True;

    Log('RegSubKeyName: ' + RegSubKeyName);

    if not (RegQueryStringValue(RegRootKey, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + RegSubKeyName, 'UninstallString', UninstallString)) then
        exit;

    UninstallString := RemoveQuotes(UninstallString);

    if 0 <> LaunchUninstallerAndWaitForItToEnd(UninstallString) then
        Result := False;
end;


// https://stackoverflow.com/questions/21737462/how-to-properly-close-out-of-inno-setup-wizard-without-prompt
// https://stackoverflow.com/questions/5833200/inno-setup-exiting-when-clicking-on-cancel-without-confirmation
//
var
    ExitWithConfirmation: Boolean;  // Does bypass the prompt of exit installer.


procedure TerminateWizard();
begin
    ExitWithConfirmation := False;
    WizardForm.Close();
    Abort();  // The emergency exit in "/VERYSILENT" mode.
end;


procedure CurStepChanged(const CurStep: TSetupStep);
begin
    case (CurStep) of
        ssInstall: begin
            Log('TryToUninstall - Start');

            Log('TryToUninstall - HKLM32');
            if not (TryToUninstall(HKLM32, '{#ThatAppId}_is1')) then begin
                SuppressibleMsgBox('Something goes wrong, exit.', mbError, MB_OK or MB_SETFOREGROUND, IDOK);
                TerminateWizard();
            end;

            Log('TryToUninstall - HKLM64');
            if not (TryToUninstall(HKLM64, '{#ThatAppId}_is1')) then begin
                SuppressibleMsgBox('Something goes wrong, exit.', mbError, MB_OK or MB_SETFOREGROUND, IDOK);
                TerminateWizard();
            end;

            Log('TryToUninstall - HKCU');
            if not (TryToUninstall(HKCU,   '{#ThatAppId}_is1')) then begin
                SuppressibleMsgBox('Something goes wrong, exit.', mbError, MB_OK or MB_SETFOREGROUND, IDOK);
                TerminateWizard();
            end;

            Log('TryToUninstall - End');
        end;
    end;
end;


procedure CancelButtonClick(const CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
    Cancel  := True;
    Confirm := ExitWithConfirmation;
end;


function InitializeSetup(): Boolean;
begin
    ExitWithConfirmation := True;
    Result := True;
end;
