program IMP_Controller;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Main},
  Unit2 in 'Unit2.pas',
  EasyCript in 'EasyCript.pas',
  SearchFileByMask in 'SearchFileByMask.pas',
  Unit3 in 'Unit3.pas',
  ShowErr in 'ShowErr.pas' {ErrForm},
  MutexHash in 'MutexHash.pas',
  SysUtils;

{$R *.res}

begin
  hMutexProg:=0;
  hMutexLog:=0;
  MainConfig:='exchange.ini';
  case ParamCount of
    0: if not IsSingleInstance('') then Halt(1);
    1: begin
       if not IsSingleInstance('') then Halt(1);
       if TryStrToInt(ParamStr(1),LogStatus) then LogStatus := 0;
       end;
    2: begin
       if not IsSingleInstance(ParamStr(2)) then Halt(1);
       if TryStrToInt(ParamStr(1),LogStatus) then LogStatus := 0;
       end;
    else
       begin
       if not IsSingleInstance(ParamStr(2)) then Halt(1);
       if TryStrToInt(ParamStr(1),LogStatus) then LogStatus := 0;
       MainConfig:=ParamStr(3);
       end;
    end;
  Application.Initialize;
  Application.CreateForm(TMain, Main);
  Application.CreateForm(TErrForm, ErrForm);
  Application.Run;
end.
