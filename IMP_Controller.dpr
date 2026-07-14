program IMP_Controller;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Main},
  Unit2 in 'Unit2.pas',
  EasyCript in 'EasyCript.pas',
  SearchFileByMask in 'SearchFileByMask.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMain, Main);
  Application.Run;
end.
