program GrafanaClient;

{$mode delphi}
//{$mode objfpc}{$H+}

uses
    {$IFDEF UNIX} {$IFDEF UseCThreads}
    cthreads,
    {$ENDIF} {$ENDIF}
    Interfaces,
    Forms, tachartlazaruspkg,
    Unit1,
    sysutils, LazLogger, Unit2;

{$R *.res}

begin
{$if declared(UseHeapTrace)}
   debugLn('Heaptrc is used.',' Heaptrc is active? ', BoolToStr(UseHeaptrace));  // heaptrc reports can be turned off when linked in... so true or false
   // you can subsequently test or set any of the heaptrc reporting options here.
   if FileExists('grafanaclient.trc') then
      DeleteFile('grafanaclient.trc');
   SetHeapTraceOutput('grafanaclient.trc'); // supported as of debugger version 3.1.1
{$else}
   debugLn('No trace of heaptrc');
{$ifend}
    RequireDerivedFormResource := True;
    Application.Initialize;
    Application.CreateForm(TForm1, Form1);
    Application.CreateForm(TForm2, Form2);
    Application.Run;
end.

