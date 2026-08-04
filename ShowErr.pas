unit ShowErr;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls;

type
  TErrForm = class(TForm)
    Err: TRichEdit;
  private
    { Private declarations }
  public
  procedure ShowMessage(const MSG: String);
    { Public declarations }
  end;

var
  ErrForm: TErrForm;

implementation
{$R *.dfm}
procedure TErrForm.ShowMessage(const MSG: String);
begin
Err.Lines.Text := MSG;
self.Show;
end;

end.
