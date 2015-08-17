unit ATOMScannerConsoleApplicationUnit;

interface

type
  TAtomCategory = (acUnknown, acUnused, acSpecial, acWindowAtom, acControlAtom, acWndProcAtom, acDlgInstancePtr);

  IAtomLikeInformation = interface(IInterface)
    ['{74ACBC77-2D2E-4173-AA2A-CB3F2F959BA0}']
    function Description: string;
    function GetCategory: TAtomCategory;
    function GetHasProcessId: Boolean;
    function GetIndex: Integer;
    function GetName: string;
    function GetProcessId: Cardinal;
    property Category: TAtomCategory read GetCategory;
    property HasProcessId: Boolean read GetHasProcessId;
    property Index: Integer read GetIndex;
    property Name: string read GetName;
    property ProcessId: Cardinal read GetProcessId;
  end;

  ILogger = interface(IInterface)
    ['{940D682F-A976-4D6E-92BB-D65002DC4308}']
    procedure Log(const ALine: string); overload;
    procedure Log(const AFormat: string; const AArgs: array of const); overload;
  end;

  TAtomLikeInformation = class(TInterfacedObject, IAtomLikeInformation)
  private
    FCategory: TAtomCategory;
    FHaveDeterminedProcessId: Boolean;
    FHaveProcessId: Boolean;
    FIndex: Integer;
    FName: string;
    FProcessId: Cardinal;
    function Description: string;
    procedure DetermineProcessId;
    function GetCategory: TAtomCategory;
    function GetHasProcessId: Boolean;
    function GetIndex: Integer;
    function GetName: string;
    function GetProcessId: Cardinal;
    function GetProcessIdInternal: Cardinal;
  protected
    function GetCategoryFromName(const AName: string): TAtomCategory; overload; virtual; abstract;
  public
    constructor Create(const AIndex: Integer; const AName: string);
    class function ClassDescription: string; virtual; abstract;
    property Category: TAtomCategory read GetCategory;
    property Index: Integer read GetIndex;
    property Name: string read GetName;
    property ProcessId: Cardinal read GetProcessId;
  end;

  TAtomLikeInformationClass = class of TAtomLikeInformation;

  TAtomInformation = class(TAtomLikeInformation, IAtomLikeInformation)
  protected
    function GetCategoryFromName(const AName: string): TAtomCategory; overload; override;
  public
    constructor Create(const AIndex: Integer);
  end;

  TGlobalAtomInformation = class(TAtomInformation)
  public
    class function ClassDescription: string; override;
  end;

  TProcessState = (psUnknown, psInactive, psActive);
  TProcessInformation = record
  private
    FProcessId: Integer;
    FFilename: string;
    FFullPath: Boolean;
    FProcessState: TProcessState;
    // gets program's name from process' AHandle
    function GetProcessFileName(const LProcessId: THandle): string;
  public
    constructor Create(const AProcessId: Integer; const AFullPath: Boolean);
    procedure StrResetLength(var S: AnsiString);
    property Filename: string read FFilename;
    property FullPath: Boolean read FFullPath;
    property ProcessId: Integer read FProcessId;
    property ProcessState: TProcessState read FProcessState;
  end;

  TApplicationOption = (aoShow, aoRemoveUnused, aoFull, aoRemoveSpecial);
  TApplicationOptions = set of TApplicationOption;

  TApplicationStatistics = record
  public
    AtomCount: Integer;
    DelphiAtomCount: Integer;
    SpecialAtomCount: Integer;
    DelphiAtomProcessStillActiveAtomCount: Integer;
    DelphiAtomRemovedAtomCount: Integer;
    DelphiAtomRemovalErrorCount: Integer;
    SpecialAtomRemovedAtomCount: Integer;
    SpecialAtomRemovalErrorCount: Integer;
    ProcessOfAtomErrorCount: Integer;
    constructor Create(const ADummy);
  end;

  Application = class
  private
    FApplicationOptions: TApplicationOptions;
    FLogger: ILogger;
    procedure Log(const AAtomLikeInformation: IAtomLikeInformation); overload;
    procedure Log(const AProcessInformation: TProcessInformation; const AAtomLikeInformation: IAtomLikeInformation); overload;
    procedure Log(const AAtomLikeInformationClass: TAtomLikeInformationClass; const ACount, AMaximumCount: Integer); overload;
    function RemoveGlobalAtom(const LAtomIndex: Integer): Cardinal;
    procedure RemoveUnusedAtom(var AApplicationStatistics: TApplicationStatistics; const AAtomInformation: IAtomLikeInformation; const AProcessInformation:
      TProcessInformation);
  public
    constructor Create(const ALogger: ILogger);
    procedure Logic; overload;
    procedure Logic(const AArguments: array of string); overload;
    class procedure Run;
    property ApplicationOptions: TApplicationOptions read FApplicationOptions;
    property Logger: ILogger read FLogger;
  end;

  TRegisteredWindowsMessageInformation = class(TAtomLikeInformation, IAtomLikeInformation)
  protected
    function GetCategoryFromName(const AName: string): TAtomCategory; overload; override;
  public
    constructor Create(const AIndex: Integer);
    class function ClassDescription: string; override;
  end;

  TLogger = class(TInterfacedObject, ILogger)
  private
    procedure Log(const ALine: string); overload;
    procedure Log(const AFormat: string; const AArgs: array of const); overload;
  end;


// if in the .dpr, you call Application.Run and add {$R *.res} then you can change the icon
// in the project options: http://stackoverflow.com/questions/1627526/change-icon-for-a-delphi-console-application

// ICON from http://icongal.com/gallery/icon/1914/128/nuclear_atom_atomic

implementation

uses
  SysUtils,
  Windows,
  PsAPI,
  DBXPlatformUtil,
  StrUtils,
  TypInfo;

constructor Application.Create(const ALogger: ILogger);
begin
  inherited Create();
  FLogger := ALogger;
end;

procedure Application.Log(const AAtomLikeInformation: IAtomLikeInformation);
var
  lCategoryString: string;
begin
  if aoShow in ApplicationOptions then
  begin
    lCategoryString := GetEnumName(TypeInfo(TAtomCategory), Ord(AAtomLikeInformation.Category));
    Delete(lCategoryString, 1, 2); // remove prefix
    Logger.Log('%s 0x%x with category %s and name "%s"', [AAtomLikeInformation.Description, AAtomLikeInformation.Index, lCategoryString, AAtomLikeInformation.Name]);
  end;
end;

procedure Application.Log(const AProcessInformation: TProcessInformation; const AAtomLikeInformation: IAtomLikeInformation);
var
  LProcessName: string;
begin
  if AAtomLikeInformation.Name <> '' then
  begin
    if aoShow in ApplicationOptions then
    begin
      case AProcessInformation.FProcessState of
        psUnknown:
          LProcessName := '--unknown--';
        psInactive:
          LProcessName := '--inactive--';
        else
          LProcessName := AProcessInformation.Filename;
      end;
      Logger.Log('%s 0x%x with process ID 0x%x(%d), name "%s" and process "%s"', [AAtomLikeInformation.Description, AAtomLikeInformation.Index, AProcessInformation.ProcessId, AProcessInformation.ProcessId, AAtomLikeInformation.Name, LProcessName]);
    end;
  end;
end;

procedure Application.Log(const AAtomLikeInformationClass: TAtomLikeInformationClass; const ACount, AMaximumCount: Integer);
begin
  if aoShow in ApplicationOptions then
  begin
    Logger.Log('Total %ss: %d', [AAtomLikeInformationClass.ClassDescription, ACount]);
    Logger.Log('Total is %d percent of maximum %d %ss.', [(100 * ACount) div AMaximumCount, AMaximumCount, AAtomLikeInformationClass.ClassDescription]);
  end;
end;

procedure Application.Logic;
const
  LMinStringTableIndex = $C000;
  LMaxStringTableIndex = $FFFF;
  LStringTableIndexCount = 1 + LMaxStringTableIndex - LMinStringTableIndex;
var
  LApplicationStatistics: TApplicationStatistics;
  LAtomIndex: Integer;
  LAtomInformation: IAtomLikeInformation;
  LMessageIndex: Integer;
  LProcessInformation: TProcessInformation;
  LRegisterWindowsMessageCount: Integer;
  LWindowsMessageInformation: IAtomLikeInformation;
begin
  LApplicationStatistics := TApplicationStatistics.Create(Self);

  if aoShow in ApplicationOptions then
  begin
    Logger.Log('');
    Logger.Log('');
    Logger.Log('Searching Global Atom Table...');
  end;

  // String based Atoms and RegisterWindowsMessage entries go from 0xC000 to 0xFFFF, see https://msdn.microsoft.com/en-us/library/windows/desktop/ms649060
  for LAtomIndex := LMinStringTableIndex to LMaxStringTableIndex do
  begin
    LAtomInformation := TGlobalAtomInformation.Create(LAtomIndex);
    if LAtomInformation.Name <> '' then
    begin
      Inc(LApplicationStatistics.AtomCount);
      case LAtomInformation.Category of
        acUnknown:
          Log(LAtomInformation);
        acUnused: ;
        acSpecial:
        begin
          Log(LAtomInformation);
          RemoveUnusedAtom(LApplicationStatistics, LAtomInformation, LProcessInformation);
        end
        else
        begin
          if LAtomInformation.HasProcessId then
          begin
            LProcessInformation := TProcessInformation.Create(LAtomInformation.ProcessId, aoFull in ApplicationOptions);
            Log(LProcessInformation, LAtomInformation);
            Inc(LApplicationStatistics.DelphiAtomCount);
            RemoveUnusedAtom(LApplicationStatistics, LAtomInformation, LProcessInformation);
          end
          else
            Log(LAtomInformation);
        end;
      end;
    end;
  end;
  if [] <> ([aoRemoveUnused, aoRemoveSpecial] * ApplicationOptions) then
  begin
    Logger.Log('');
    Logger.Log('Atom Scan complete:');
    Logger.Log('- Delphi related atoms:     %d', [LApplicationStatistics.DelphiAtomCount]);
    Logger.Log('  - OK; still active atoms: %d', [LApplicationStatistics.DelphiAtomProcessStillActiveAtomCount]);
    Logger.Log('  - OK; removed atoms:      %d', [LApplicationStatistics.DelphiAtomRemovedAtomCount]);
    Logger.Log('  - LEAK; removal errors:   %d', [LApplicationStatistics.DelphiAtomRemovalErrorCount]);
    Logger.Log('  - LEAK; no process infos: %d', [LApplicationStatistics.ProcessOfAtomErrorCount]);
    Logger.Log('- Special atoms:            %d', [LApplicationStatistics.SpecialAtomCount]);
    Logger.Log('  - OK; removed atoms:      %d', [LApplicationStatistics.SpecialAtomRemovedAtomCount]);
    Logger.Log('  - LEAK; removal errors:   %d', [LApplicationStatistics.SpecialAtomRemovalErrorCount]);
  end;
  if aoShow in ApplicationOptions then
    Log(TGlobalAtomInformation, LApplicationStatistics.AtomCount, LStringTableIndexCount);

  LRegisterWindowsMessageCount := 0;
  for LMessageIndex := LMinStringTableIndex to LMaxStringTableIndex do
  begin
    LWindowsMessageInformation := TRegisteredWindowsMessageInformation.Create(LMessageIndex);
    if LWindowsMessageInformation.Name <> '' then
    begin
      Inc(LRegisterWindowsMessageCount);
      case LWindowsMessageInformation.Category of
        acUnknown:
          Log(LWindowsMessageInformation);
        acUnused: ;
        else
        begin
          if LWindowsMessageInformation.HasProcessId then
          begin
            LProcessInformation := TProcessInformation.Create(LWindowsMessageInformation.ProcessId, aoFull in ApplicationOptions);
            Log(LProcessInformation, LWindowsMessageInformation);
          end
          else
            if LAtomInformation.Name <> '' then
              Log(LAtomInformation);
        end;
      end;
    end;
  end;
  if aoShow in ApplicationOptions then
    Log(TRegisteredWindowsMessageInformation, LRegisterWindowsMessageCount, LStringTableIndexCount);
end;

procedure Application.Logic(const AArguments: array of string);
var
  LArgument: string;
begin
  for LArgument in AArguments do
  begin
    if SameText(LArgument, 'Show') then
      Include(FApplicationOptions, aoShow);
    if SameText(LArgument, 'RemoveUnused') then
      Include(FApplicationOptions, aoRemoveUnused);
    if SameText(LArgument, 'RemoveSpecial') then
      Include(FApplicationOptions, aoRemoveSpecial);
    if SameText(LArgument, 'Full') then
      Include(FApplicationOptions, aoFull);
  end;
  if FApplicationOptions = [] then
  begin
    Logger.Log('Syntax: %s [Show|RemoveUsed|Full]...', [ParamStr(0)]);
    Logger.Log('Show          will show all Atoms and RegisteredWindows messages.');
    Logger.Log('RemoveUnused  will remove Atoms that have no associated process ID or thread ID any more.');
    Logger.Log('RemoveSpecial will remove Atoms marked special (probably created by Microsoft Test Manager 2013).');
    Logger.Log('Full          will show full paths names to processes when available.');
  end
  else
    Logic();
end;

function Application.RemoveGlobalAtom(const LAtomIndex: Integer): Cardinal;
var
  LLastError: Cardinal;
begin
  SetLastError(ERROR_SUCCESS);
  GlobalDeleteAtom(LAtomIndex); // https://msdn.microsoft.com/en-us/library/windows/desktop/ms649061
  Result := GetLastError();
end;

procedure Application.RemoveUnusedAtom(var AApplicationStatistics: TApplicationStatistics; const AAtomInformation: IAtomLikeInformation; const
  AProcessInformation: TProcessInformation);
var
  LLastError: Cardinal;
begin
  if (acSpecial = AAtomInformation.Category)
    and ([] <> ([aoRemoveSpecial, aoRemoveUnused] * ApplicationOptions))
  then
  begin
    LLastError := RemoveGlobalAtom(AAtomInformation.Index);
    if LLastError = ERROR_SUCCESS then
    begin
      Inc(AApplicationStatistics.SpecialAtomRemovedAtomCount);
      Logger.Log('- fixed leak: removed Atom from Global Atom Table.');
    end
    else
    begin
      Inc(AApplicationStatistics.SpecialAtomRemovalErrorCount);
      Logger.Log('- LEAK: `GlobalDeleteAtom` failed with reason "%s".', [SysErrorMessage(LLastError)]);
    end;
  end
  else
    if aoRemoveUnused in ApplicationOptions then
    begin
      case AProcessInformation.ProcessState of
        psUnknown:
        begin
          Inc(AApplicationStatistics.ProcessOfAtomErrorCount);
          Logger.Log('- LEAK: Could not get process information; Atom has not been removed.');
        end;
        psInactive:
        begin
          LLastError := RemoveGlobalAtom(AAtomInformation.Index);
          if LLastError = ERROR_SUCCESS then
          begin
            Inc(AApplicationStatistics.DelphiAtomRemovedAtomCount);
            Logger.Log('- fixed leak: Not an active ProcID any more; removed Atom from Global Atom Table.');
          end
          else
          begin
            Inc(AApplicationStatistics.DelphiAtomRemovalErrorCount);
            Logger.Log('- LEAK: Not an active ProcID any more; but `GlobalDeleteAtom` failed with reason "%s".', [SysErrorMessage(LLastError)]);
          end;
        end;
        else
        begin
          Inc(AApplicationStatistics.DelphiAtomProcessStillActiveAtomCount);
          Logger.Log('- no leak: Process "%s" is still active.', [AProcessInformation.FFilename]);
        end;
      end;
    end;
end;

class procedure Application.Run;
var
  LArguments: array of string;
  LIndex: Integer;
begin
  with Application.Create(TLogger.Create()) do
    try
      SetLength(LArguments, ParamCount);
      for LIndex := 0 to ParamCount - 1 do
        LArguments[LIndex] := ParamStr(LIndex + 1);
      Logic(LArguments);
    finally
      Free();
    end;
end;

constructor TAtomInformation.Create(const AIndex: Integer);
var
  LLength: Integer;
  cstrAtomName: array [Byte] of Char;
begin
  FIndex := AIndex;
  LLength := GlobalGetAtomName(AIndex, cstrAtomName, High(Byte));
  if LLength = 0 then
    FName := ''
  else
  begin
    FName := StrPas(cstrAtomName);
    SetLength(FName, LLength);
    FCategory := GetCategoryFromName(FName);
  end;
end;

function TAtomInformation.GetCategoryFromName(const AName: string): TAtomCategory;
var
  LMiddleOfName: string;
begin
{ Format of special Atoms on Windows 7 x64 Professional
(#$2d, #$25, #$44, #$34, #$23, #$21, #$60, #$60, #$60, #$60, #$60, #$42, #$2a, #$60, #$60, #$60, #$60, #$60, #$60, #$60, #$60, #$30, #$27, #$21, #$60, #$60, #$60, #$60, #$60, #$60, #$60, #$60, #$00,
(#$2d, #$25, #$44, #$34, #$23, #$21, #$60, #$60, #$60, #$60, #$60, #$5e, #$5e, #$60, #$60, #$60, #$60, #$60, #$60, #$60, #$60, #$40, #$57, #$23, #$60, #$60, #$60, #$60, #$60, #$60, #$60, #$60,
(#$2d, #$25, #$44, #$34, #$23, #$21, #$60, #$60, #$60, #$60, #$60, #$25, #$57, #$21, #$60, #$60, #$60, #$60, #$60, #$60, #$60, #$40, #$57, #$23, #$60, #$60, #$60, #$60, #$60, #$60, #$60, #$60,
ix: 1     2     3     4     5     6     7     8     9     0     1     2     3     4     5     6     7     8     9     0     1     2     3     4     5     6     7     8     9     0     1     2
m:  X     X     X     X     X     X     X     X     X     X     X                       X     X     X     X     X     X     X                       X     X     X     X     X     X     X     X
C:                                      1     2     3     4     5                       1     2     3     4     5     6     7                       1     2     3     4     5     6     7     8
}
  if StringStartsWith(AName, 'Delphi') then
    Result := acWindowAtom
  else
    if StringStartsWith(AName, 'ControlOfs') then
      Result := acControlAtom
    else
      if StringStartsWith(AName, 'WndProcPtr') then
        Result := acWndProcAtom
      else
        if StringStartsWith(AName, 'WideWndProcPtr') then // observed in practice, not sure where it comes from yet.
          Result := acWndProcAtom
        else
          if StringStartsWith(AName, 'DlgInstancePtr') then
            Result := acDlgInstancePtr
          else
          begin
            Result := acUnknown;
            if (Length(AName) = 32) then
              if StringStartsWith(AName, #$2d#$25#$44#$34#$23#$21#$60#$60#$60#$60#$60) then
                if StringEndsWith(AName, #$60#$60#$60#$60#$60#$60#$60#$60) then
                begin
                  LMiddleOfName := Copy(AName, 15, 7);
                  if LMiddleOfName = #$60#$60#$60#$60#$60#$60#$60 then
                    Result := acSpecial; // special -- caused in part by Microsoft TestManager 2013.
                end;
          end;
end;

const
  kernel32 = 'kernel32.dll';
  PsapiLib = 'psapi.dll';
  {$IFDEF UNICODE}
  AWSuffix = 'W';
  {$ELSE}
  AWSuffix = 'A';

  {$ENDIF UNICODE}

function OpenThread(dwDesiredAccess: DWORD; bInheritHandle: BOOL; dwThreadId: DWORD): THANDLE; stdcall; external kernel32 name 'OpenThread';
{$EXTERNALSYM OpenThread}
function GetProcessIdOfThread(Thread: THANDLE): DWORD; stdcall; external kernel32 name 'GetProcessIdOfThread';
{$EXTERNALSYM GetProcessIdOfThread}
function GetProcessImageFileName(hProcess: THANDLE; lpImageFileName: LPTSTR; nSize: DWORD): DWORD; stdcall; external PsapiLib name 'GetProcessImageFileName' + AWSuffix;
{$EXTERNALSYM GetProcessImageFileName}
function QueryFullProcessImageName(AProcess: THANDLE; dwFlags: DWORD; lpExeName: PAnsiChar; var lpdwSize: DWORD): BOOL; stdcall; external kernel32 name 'QueryFullProcessImageName' + AWSuffix;
{$EXTERNALSYM QueryFullProcessImageName}

constructor TProcessInformation.Create(const AProcessId: Integer; const AFullPath: Boolean);
var
  LProcessHandle: THandle;
begin
  FFullPath := AFullPath;
  FProcessId := AProcessId;
  try
    LProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, AProcessId);
    if (LProcessHandle = 0) then
    begin
      FProcessState := psInactive;
      FFilename := '';
    end
    else
      try
        FProcessState := psActive;
        FFilename := GetProcessFileName(AProcessId);
      finally
        CloseHandle(LProcessHandle);
      end;
  except
    FProcessState := psUnknown;
    FFilename := '';
  end;
end;

function TProcessInformation.GetProcessFileName(const LProcessId: THandle): string;
var
  LProcessHandle: THandle;
  LSize: DWORD;
begin
  Result := '';
  LProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, LProcessId);
  if LProcessHandle <> 0 then
    try
      SetLength(Result, MAX_PATH);
      if FullPath then
      begin
        if GetModuleFileNameEx(LProcessHandle, 0, PChar(Result), MAX_PATH) > 0 then
          StrResetLength(Result)
        else
          RaiseLastOSError();
      end
      else
      begin
        // GetModuleBaseName can return zero with the below error; the else with QueryFullProcessImageName will circumvent that
        // error 299 : ERROR_PARTIAL_COPY : "Only part of a ReadProcessMemory or WriteProcessMemory request was completed."
        if GetModuleBaseName(LProcessHandle, 0, PChar(Result), MAX_PATH) > 0 then
          StrResetLength(Result)
        else
        begin
          // GetProcessImageFileName https://msdn.microsoft.com/en-us/library/windows/desktop/ms683217
          // GetProcessImageFileName reports in Device form, not Drive form,
          // \Device\Harddisk0\Partition1\Windows\System32\Ctype.nls versus C:\Windows\System32\Ctype.nls 
          // QueryFullProcessImageName https://msdn.microsoft.com/en-us/library/windows/desktop/ms684919
          LSize := MAX_PATH;
          if QueryFullProcessImageName(LProcessHandle, 0, PChar(Result), LSize) then
            StrResetLength(Result)
          else
            RaiseLastOSError();
        end;
      end;
    finally
      CloseHandle(LProcessHandle);
    end;
end;

procedure TProcessInformation.StrResetLength(var S: AnsiString);
begin
  SetLength(S, StrLen(PChar(S)));
end;

constructor TRegisteredWindowsMessageInformation.Create(const AIndex: Integer);
var
  LLength: Integer;
  LName: string;
  LWindowsMessageNameChars: array [Byte] of Char;
begin
  // GetClipboardFormatName https://msdn.microsoft.com/en-us/library/windows/desktop/ms649040
  // RegisterClipboardFormat https://msdn.microsoft.com/en-us/library/windows/desktop/ms649049
  // RegisterWindowMessage https://msdn.microsoft.com/en-us/library/windows/desktop/ms644947
  // max 255 characters: http://stackoverflow.com/questions/21036573/what-is-maximum-length-of-atom-strings-in-wide-characters-255-or-127 
  LLength := GetClipboardFormatName(AIndex, LWindowsMessageNameChars, High(Byte));
  if LLength = 0 then
    inherited Create(AIndex, '')
  else
  begin
    LName := StrPas(LWindowsMessageNameChars);
    SetLength(LName, LLength);
    inherited Create(AIndex, LName);
  end;
end;

class function TRegisteredWindowsMessageInformation.ClassDescription: string;
begin
  Result := 'Registered WindowsMessage';
end;

function TRegisteredWindowsMessageInformation.GetCategoryFromName(const AName: string): TAtomCategory;
begin
  if StringStartsWith(AName, 'ControlOfs') then
    Result := acControlAtom
  else
    Result := acUnknown;
end;

constructor TAtomLikeInformation.Create(const AIndex: Integer; const AName: string);
begin
  inherited Create();
  FHaveDeterminedProcessId := False;
  FIndex := AIndex;
  FName := AName;
  FCategory := GetCategoryFromName(FName);
end;

function TAtomLikeInformation.Description: string;
begin
  Result := ClassDescription;
end;

procedure TAtomLikeInformation.DetermineProcessId;
begin
  if not FHaveDeterminedProcessId then
    try
      try
        FProcessId := GetProcessIdInternal;
        FHaveProcessId := True;
      except
        FProcessId := 0;
        FHaveProcessId := False;
      end;
    finally
      FHaveDeterminedProcessId := True;
    end;
end;

function TAtomLikeInformation.GetCategory: TAtomCategory;
begin
  Result := FCategory;
end;

function TAtomLikeInformation.GetHasProcessId: Boolean;
begin
  DetermineProcessId;
  Result := FHaveProcessId;
end;

function TAtomLikeInformation.GetIndex: Integer;
begin
  Result := FIndex;
end;

function TAtomLikeInformation.GetName: string;
begin
  Result := FName;
end;

function TAtomLikeInformation.GetProcessId: Cardinal;
begin
  DetermineProcessId;
  Result := FProcessId;
end;

function TAtomLikeInformation.GetProcessIdInternal: Cardinal;
const
  MaxInt32HexChars = 8;
  THREAD_QUERY_INFORMATION = $0040;
var
  LHThread: DWord;
  LLength: Integer;
  LHex: string;
  LId: Cardinal;
begin
{
Delphi can potentially register these atoms:

1. Unit Dialogs, method InitGlobals:

  WndProcPtrAtom := GlobalAddAtom(StrFmt(AtomText,
    'WndProcPtr%.8X%.8X', [HInstance, GetCurrentThreadID]));

2. Unit Controls, method InitControls:

  WindowAtomString := Format('Delphi%.8X',[GetCurrentProcessID]);
  WindowAtom := GlobalAddAtom(PChar(WindowAtomString));
  ControlAtomString := Format('ControlOfs%.8X%.8X', [HInstance, GetCurrentThreadID]);
  ControlAtom := GlobalAddAtom(PChar(ControlAtomString));
  RM_GetObjectInstance := RegisterWindowMessage(PChar(ControlAtomString));

3. Unit QDialogs, method TaskModalDialog:

  WndProcPtrAtom := GlobalAddAtom(StrFmt(AtomText,
    'WndProcPtr%.8X%.8X', [HInstance, GetCurrentThreadID]));
  InstancePtrAtom := GlobalAddAtom(StrFmt(AtomText,
    'DlgInstancePtr%.8X%.8X', [HInstance, GetCurrentThreadID]));

Note that RegisterWindowsMessage cannot be undone:
  - http://stackoverflow.com/questions/1192204/can-abusing-registerwindowmessage-lead-to-resource-exhaustion/1194054#1194054
  - https://www.google.com/search?q="UnRegisterWindowMessage"
  - http://blogs.msdn.com/b/oldnewthing/archive/2015/03/19/10601208.aspx

Note that RegisterWindowsMessage shares the method slot with RegisterClipboardFormat:
  - http://stackoverflow.com/questions/10780402/an-exported-aliases-symbol-doesnt-exist-in-pdb-file-registerclipboardformat-ha
}
  LId := 0;
  if Category = acUnknown then
  begin
    Result := LId;
    Exit;
  end;

  LLength := Length(Name);
  if (LLength > MaxInt32HexChars) then
  begin
    LHex := '$' + Copy(Name, LLength - (MaxInt32HexChars - 1), MaxInt32HexChars);
    LId := StrToInt64Def(LHex, 0);
  end;

  case Category of
    acWindowAtom:
    begin
      // Assume LId is a process ID
      Result := LId;
    end;
    acControlAtom,
    acWndProcAtom,
    acDlgInstancePtr:
    begin
      // Assume Id is a thread ID, convert to Process Id
      if Win32MajorVersion >= 6 then // Vista and up; http://stackoverflow.com/questions/8144599/getting-the-windows-version
      begin
        // GetThreadId(Handle): https://msdn.microsoft.com/en-us/library/windows/desktop/ms683233
        // Enumerating threads: https://msdn.microsoft.com/en-us/library/windows/desktop/ms686746
        // GetProcessIdOfThread: https://msdn.microsoft.com/en-us/library/windows/desktop/ms683216
        // OpenThread: https://msdn.microsoft.com/en-us/library/windows/desktop/ms684335
        // http://stackoverflow.com/questions/2943959/openthread-through-different-thread-numbers
        // http://www.delphipraxis.net/805462-post1.html

        // OpenThread API call in Delphi: http://stackoverflow.com/questions/10159516/get-thread-start-address
        LHThread := OpenThread(THREAD_QUERY_INFORMATION, False, LId);
        if (LHThread = 0) then
          RaiseLastOSError;
        try
          Result := GetProcessIdOfThread(LHThread);
          if Result = 0 then
            RaiseLastOSError;
        finally
          CloseHandle(LHThread);
        end;
      end
      else
        Result := 0; // satisfy compiler
    end;
    else
      Result := 0; // satisfy compiler
  end;
end;

constructor TApplicationStatistics.Create(const ADummy);
begin
  AtomCount := 0;
  SpecialAtomCount := 0;
  DelphiAtomProcessStillActiveAtomCount := 0;
  ProcessOfAtomErrorCount := 0;
  DelphiAtomRemovalErrorCount := 0;
  DelphiAtomCount := 0;
  DelphiAtomRemovedAtomCount := 0;
  SpecialAtomRemovedAtomCount := 0;
  SpecialAtomRemovalErrorCount := 0;
end;

procedure TLogger.Log(const ALine: string);
begin
  Writeln(ALine);
end;

procedure TLogger.Log(const AFormat: string; const AArgs: array of const);
begin
  Log(Format(AFormat, AArgs));
end;

class function TGlobalAtomInformation.ClassDescription: string;
begin
  Result := 'Global Atom';
end;

end.
