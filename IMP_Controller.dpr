program IMP_Controller;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Main},
  Unit2 in 'Unit2.pas',
  EasyCript in 'EasyCript.pas',
  SearchFileByMask in 'SearchFileByMask.pas',
  Unit3 in 'Unit3.pas',
  ShowErr in 'ShowErr.pas' {ErrForm},
  MutexHash in 'MutexHash.pas';

{$R *.res}

begin
  hMutexProg:=0;
  hMutexLog:=0;
  case ParamCount of
    1: begin
       if not IsSingleInstance('') then Halt(1);
       MainConfig:=ParamStr(1);
       end;
    2: begin
       if not IsSingleInstance(ParamStr(2)) then Halt(1);
       MainConfig:=ParamStr(1);
       end
    else
       begin
       if not IsSingleInstance('') then Halt(1);
       MainConfig:='exchange.ini';
       end;
    end;
  Application.Initialize;
  Application.CreateForm(TMain, Main);
  Application.CreateForm(TErrForm, ErrForm);
  Application.Run;
end.
