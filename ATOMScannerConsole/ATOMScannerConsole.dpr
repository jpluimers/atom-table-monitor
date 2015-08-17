program ATOMScannerConsole;

{$APPTYPE CONSOLE}

{$R 'MAINICON.res' 'MAINICON.rc'}
{$R 'VERSIONINFO.res' 'VERSIONINFO.rc'}

uses
  SysUtils,
  ATOMScannerConsoleApplicationUnit in 'ATOMScannerConsoleApplicationUnit.pas';

begin
  try
    Application.Run;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
