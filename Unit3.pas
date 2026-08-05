unit Unit3;

interface
uses Classes;

type TBranches = array of String;
type TTree = record
       R: String;
       B: TBranches;
       end;
type TDep = Class
       private
       T: array of TTree;
       CurrInd: integer;
       function GetBranches(const Name: String): TBranches;
       function TreeCount: integer;
       public
       function GetInd(const Name: String): integer;
       procedure Clear;
       procedure AddStrings(SS: TStringList);
       procedure AddRoot(const root: String);
       procedure AddChild(const root, branch: String);
       constructor Create;
       published
       property Count: integer read TreeCount;
       end;

type TFMsk = record
       F,M: String;
       B: TBranches
       end;
type TMsk = class
       private
       function GetCnt: integer;

       public
       Items: array of TFMsk;
       procedure AddStrings(SS: TStringList);
       procedure Add(const FName,FMask: String);
       procedure Clear;
       procedure Link(const D: TDep);

       published
       property Count: integer read GetCnt;
       end;
type TFile = record
       FileName: String;
       FileAttr: TFMsk;
       Enabled: boolean;
       end;
type TFoundFiles = class
       protected
       MSK: TMsk;
       CNT: integer;
       public
       Items: array of TFile;
       constructor Create;
       procedure Clear;
       function IndexOf(const FileCode: String; ind: integer): integer;
       procedure FindAllChild(ind: integer; SS: TStringList);
       procedure Add(const FullName: String; Attr: TFMsk);
       //procedure SetEnable(ind: integer; en: boolean);
       published
       property Count: integer read CNT;
       end;
implementation
uses SysUtils;
constructor TFoundFiles.Create;
begin
inherited Create;
CNT:=0;
end;

procedure TFoundFiles.Clear;
begin
CNT:=0;
end;

function TFoundFiles.IndexOf(const FileCode: String; ind: integer): integer;
var i: integer;
begin
for i:=ind to CNT-1 do
  if Items[i].FileAttr.F=FileCode then
    begin
    result:=i;
    exit;
    end;
result:=-1;
end;

procedure TFoundFiles.FindAllChild(ind: integer; SS: TStringList);
var i,j: integer;
begin
  with Items[ind].FileAttr do
    for i:=0 to Length(B)-1 do
    begin
      j:=IndexOf(B[i],ind+1);
      if j>=0 then
        begin
        SS.Add(Items[j].FileName);
        Items[j].Enabled:=False;
        FindAllChild(j,SS);
        end;
    end;
end;

procedure TFoundFiles.Add(const FullName: String; Attr: TFMsk);
begin
  inc(CNT);
  if CNT>Length(Items) then
    SetLength(Items,CNT+3);
  with Items[CNT-1] do
  begin
    FileName := FullName;
    FileAttr := Attr;
    Enabled := True;
  end;
end;

{
//Установка флага доступности для подчиненных файлов
procedure TFoundFiles.SetEnable(ind: integer; en: boolean);
var i,j: integer;
begin

//Имеет сысл ограничивать доступность только для пока не переписанных
//файлов, т.е тех, которые идут ниже по списку (for j:=ind+1 to CNT-1 do)

with Items[ind].FileAttr do //Текущий файл (доп. аттрибуты)
  for i:=0 to length(B) do //По зависимостям текущего файла (из доп. аттрибутов)
    for j:=ind+1 to CNT-1 do            //По всем файлам начиная с текущего
      if Items[j].FileAttr.F=B[i] then  //Ишем зависимые файлы
        Items[j].Enabled:=en;           //Проставляем доступность
end;
}

function TMsk.GetCnt: integer;
begin
  result:=Length(Items);
end;

procedure TMsk.AddStrings(SS: TStringList);
var i,j:integer;
    S1,S2: String;
begin
for i:=0 to SS.Count-1 do
  begin
    S1:=SS.Strings[i];
    j:=pos('=',S1);
    S2:=copy(S1,j+1,Length(S1)-j);
    setLength(S1,j-1);
    j:=pos(';',S2);
    if j>0 then
      SetLength(S2,j-1);
    Add(S1,S2);
  end;
end;

procedure TMsk.Add(const FName,FMask: String);
var i: integer;
begin
  i:=Length(Items);
  SetLength(Items,i+1);
  with Items[i] do
  begin
    F:=FName;
    M:=FMask;
  end;
end;
procedure TMsk.Clear;
begin
SetLength(Items,0);
end;
procedure TMsk.Link(const D: TDep);
var i: integer;
begin
for i:=0 to Length(Items)-1 do
  Items[i].B:=D.GetBranches(Items[i].F);
end;


constructor TDep.Create;
begin
  inherited Create;
  CurrInd := -1;
end;

procedure TDep.AddStrings(SS: TStringList);
var i,j,n: integer;
    S1,S2: String;
    TT: TStringList;
begin
  TT:=TStringList.Create;
  with SS do
  for i:=0 to Count-1 do
    begin
    TT.Clear;
    S1:=Strings[i];
    n := pos('=',S1);
    if n=0 then continue;
    S2 := copy(S1,1,n-1);
    AddRoot(S2);
    TT.CommaText:=StringReplace(copy(S1,n+1,Length(S1)-n),';',',',[rfReplaceAll]);
    for j:=0 to TT.Count-1 do
      AddChild(S2,TT.Strings[j]);
    end;
end;

function TDep.GetInd(const Name: String): integer;
var i: integer;
begin
  if CurrInd<>-1 then
    begin
    for i:=CurrInd to Length(T)-1 do
      if T[i].R = Name then
        begin
        result := i;
        CurrInd:=i;
        exit;
        end;
    for i:=0 to CurrInd-1 do
      if T[i].R = Name then
        begin
        result := i;
        CurrInd:=i;
        exit;
        end;
    result := -1;
    end;
end;
function TDep.GetBranches(const Name: String): TBranches;
var i: integer;
begin
  if CurrInd<>-1 then
  begin
    for i:=CurrInd to Length(T)-1 do
      if T[i].R = Name then
      begin
        result := T[i].B;
        CurrInd:=i;
        exit;
      end;
    for i:=0 to CurrInd-1 do
      if T[i].R = Name then
      begin
        result := T[i].B;
        CurrInd:=i;
        exit;
      end;
    result := nil;
  end;
end;
function TDep.TreeCount: integer;
begin
  result:=Length(T);
end;
procedure TDep.Clear;
var i: integer;
begin
  for i:=0 to Length(T)-1 do
    SetLength(T[i].B,0);
  SetLength(T,0);
end;
procedure TDep.AddRoot(const root: String);
begin
  CurrInd:=Length(T);
  SetLength(T,CurrInd+1);
  T[CurrInd].R := root;
end;
procedure TDep.AddChild(const root, branch: String);
var i,j: integer;
begin
  i := GetInd(root);
  if i = -1 then
  begin
    AddRoot(root);
    i:=CurrInd;
  end;
  with T[i] do
  begin
    j:=Length(B);
    setLength(B,j+1);
    B[j]:=branch;
  end

end;

end.
