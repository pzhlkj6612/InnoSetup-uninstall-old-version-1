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

#define MyAppName " WaitForItWithWmi'" + ThisAppId + "'wanna`uninstall'" + ThatAppId

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


function LaunchUninstallerAndWaitForItToBeDeleted(const UninstallString: String; RemainingRetryTimes: Integer): Integer;
begin
    Log(Format('Executing "%s" with "%s"', [UninstallString, UninstallParameter]));

    if Exec(UninstallString, UninstallParameter, '', SW_SHOWNORMAL, ewWaitUntilTerminated, Result) then
        Log(Format('Exit code: 0x%x', [Result]))
    else
        Log(Format('System error occurred: 0x%x, %s', [Result, SysErrorMessage(Result)]));

    if 0 <> Result then
        exit;


    Log('Waiting for the uninstaller to be deleted...');

    // https://stackoverflow.com/questions/18902060/disk-caching-issue-with-inno-setup/18988488#18988488
    while (FileExists(UninstallString)) AND (0 < RemainingRetryTimes) do begin
        Dec(RemainingRetryTimes);
        Log(Format('The uninstaller "%s" still exists, waiting... %d', [UninstallString, RemainingRetryTimes]));
        Sleep(250);
    end;


    Log('Uninstallation complete');
end;


// https://docs.microsoft.com/en-us/windows/win32/wmisdk/where-clause
function EscapeBackslashAndSingleQuote(const S: String): String;
begin
    Result := S;
    StringChangeEx(Result, '\', '\\', True);
    // StringChangeEx(Result, '"', '\"', True);  // Exempted in single-quoted strings.
    StringChangeEx(Result, '''', '\''', True);
end;


// https://stackoverflow.com/questions/21390130/inno-setup-pascal-script-to-search-for-running-process/21408578#21408578
function GetFilteredPIDByWMIQuery(
    const
        Filter: String;
    const
        ProcessCreatedDateNotEarlierThan (* yyyymmddhhnnss *): Int64;
    out
        PidList: array of String
): Integer;
var
    WmiQueryString: string;

    WbemLocator,
    WbemServices,
    WbemObject,
    WbemObjectSet: Variant;

    I: Integer;
begin
    Log('ProcessCreatedDateNotEarlierThan: ' + IntToStr(ProcessCreatedDateNotEarlierThan));

    SetArrayLength(PidList, 0);  // Initialize anyway

    WbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
    WbemServices := WbemLocator.ConnectServer();  // Connect to local computer and log on default namespace by default.

    WmiQueryString := 'SELECT * FROM Win32_Process WHERE ' + Filter;

    Log('WmiQueryString: ' + WmiQueryString);

    WbemObjectSet := WbemServices.ExecQuery(WmiQueryString);

    // ?
    if not VarIsNull(WbemObjectSet) and (WbemObjectSet.Count >= 0) then begin
        Log('WbemObjectSet.Count: ' + IntToStr(WbemObjectSet.Count));

        for I := 0 to WbemObjectSet.Count - 1 do begin
            WbemObject := WbemObjectSet.ItemIndex(I);

            // ?
            if not VarIsNull(WbemObject) then begin
                Log(Format('ProcessId: %s, Name: "%s", CreationDate: %s, Commandline: %s', [
                    WbemObject.ProcessId,
                    WbemObject.Name,
                    WbemObject.CreationDate,  // CIM_DATETIME: yyyymmddHHMMSS.mmmmmmsUUU
                    WbemObject.Commandline    // Empty if lack of privilege
                ]));

                if ProcessCreatedDateNotEarlierThan <= StrToInt64(Copy(WbemObject.CreationDate, 1, 14)) then begin
                    Log('Newly created process found');

                    SetArrayLength(PidList, GetArrayLength(PidList) + 1);
                    PidList[GetArrayLength(PidList) - 1] := WbemObject.ProcessId;
                end;
            end;
        end;

        Result := GetArrayLength(PidList);
    end;
end;


function LaunchUninstallerAndWaitForTempUninstallerWithWmi(const UninstallString: String; RemainingRetryTimes: Integer): Integer;
var
    NamePattern,
    NameFilter,
    CommandlinePattern,
    CommandlineFilter,
    PidFilter: String;

    StartDateTime: Int64;

    FilteredPidList: array of String;

    I: Integer;
begin
    // Name: _iu14D2N.tmp
    NamePattern := '[_]iu[0-9A-V][0-9A-V][0-9A-V][0-9A-V][0-9A-V].tmp';

    NameFilter := 'Name LIKE ''' + NamePattern + '''';

    // Commandline: "GetTempDir()_iu14D2N.tmp" /SECONDPHASE="absolute\path\to\uninsNNN.exe" /FIRSTPHASEWND=$(hex)... arguments passed by user
    CommandlinePattern := Format('"%s%s" /SECONDPHASE="%s" /FIRSTPHASEWND=$[0-9A-F]%% %s', [
        EscapeBackslashAndSingleQuote(GetTempDir()),
        NamePattern,
        EscapeBackslashAndSingleQuote(UninstallString),
        EscapeBackslashAndSingleQuote(UninstallParameter)  // uninstaller /LOG="path\to\ l o g' file"
    ]);

    CommandlineFilter := 'Commandline LIKE ''' + CommandlinePattern + '''';


    StartDateTime := StrToInt64(GetDateTimeString('yyyymmddhhnnss', #0, #0));

    Sleep(2000);  // Much greater than 1 second, the smallest granularity.


    Log(Format('"%s" with "%s" will be executed no earlier than "%d"', [UninstallString, UninstallParameter, StartDateTime]));

    if Exec(UninstallString, UninstallParameter, '', SW_SHOWNORMAL, ewWaitUntilTerminated, Result) then
        Log(Format('Exit code: 0x%x', [Result]))
    else
        Log(Format('System error occurred: 0x%x, %s', [Result, SysErrorMessage(Result)]));

    if 0 <> Result then
        exit;


    Log('Waiting for the temporary uninstaller to end...');

    // Filter by Commandline (the most accurate way).
    if 0 < GetFilteredPIDByWMIQuery(CommandlineFilter, StartDateTime, FilteredPidList) then
        Log('PID Filtered by Commandline: ' + FilteredPidList[I])
    else
        // Fallback. Filter by Image Name (not accurate, but works fine).
        if 0 < GetFilteredPIDByWMIQuery(NameFilter, StartDateTime, FilteredPidList) then
            for I := Low(FilteredPidList) to High(FilteredPidList) do
                Log('PID Filtered by Name: ' + FilteredPidList[I]);

    if 0 < GetArrayLength(FilteredPidList) then begin
        PidFilter := '';
        for I := Low(FilteredPidList) to High(FilteredPidList) do begin
            PidFilter := PidFilter + 'ProcessId = ' + FilteredPidList[I];
            if I <> High(FilteredPidList) then
                PidFilter := PidFilter + ' OR ';
        end;

        // Filter by PID.
        while (0 < GetFilteredPIDByWMIQuery(PidFilter, StartDateTime, FilteredPidList)) AND (0 < RemainingRetryTimes) do begin
            Dec(RemainingRetryTimes);
            Log('Waiting... ' + IntToStr(RemainingRetryTimes));
            Sleep(250);
        end;
    end;


    Log('Uninstallation complete');
end;


function TryToUninstall(const RegRootKey: Integer; const RegSubKeyName: String): Boolean;
var
    UninstallString: String;
begin
    Result := True;

    Log('RegSubKeyName: ' + RegSubKeyName);

    if not (RegQueryStringValue(
        RegRootKey,
        'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + RegSubKeyName,
        'UninstallString',
        UninstallString
    )) then
        exit;

    UninstallString := RemoveQuotes(UninstallString);

    if 0 <> LaunchUninstallerAndWaitForTempUninstallerWithWmi(UninstallString, 20) then
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
