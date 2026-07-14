unit SearchFileByMask;

interface
var TimeStamp: String;
    SearchFileCount: integer;

function SearchFile(const FileMask: String):String;
function SearchFileTS(const FileMask: String; var TS: String): String;
function SearchFileTS_reliably(const FileMask: String; var TS: String; Start: double; Interval, Period: integer): String;

implementation
uses SysUtils;

function SearchFileByEditTime(const FileMask: string; var FileCount: integer): string;
var
  SearchRec: TSearchRec;
  DirPath, FileName, FullPath: string;
  Found: Boolean;
  EarliestTime: Cardinal;
  CurTime: Cardinal;
begin
  Result := '';
  FileCount:=0;
  DirPath := ExtractFilePath(FileMask);
  FileName := ExtractFileName(FileMask);

  if DirPath = '' then
    DirPath := '.\';

  FullPath := DirPath + FileName;

  // Ищем только файлы (исключаем каталоги)
  if FindFirst(FullPath, faAnyFile - faDirectory, SearchRec) = 0 then
  begin
    try
      Found := False;
      EarliestTime := $FFFFFFFF; // максимально возможное значение

      repeat
        // Двойная проверка, что это не каталог
        if (SearchRec.Attr and faDirectory) = 0 then
        begin
          inc(FileCount);
          CurTime := SearchRec.Time;
          if not Found or (CurTime < EarliestTime) then
          begin
            EarliestTime := CurTime;
            Result := DirPath + SearchRec.Name;
            Found := True;
          end;
        end;
      until FindNext(SearchRec) <> 0;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

function SearchFile(const FileMask: String):String;
var
  SearchRec: TSearchRec;
  DirPath, FileName: string;
begin
  Result := '';

  // Нормализуем путь: ExtractFilePath гарантирует наличие разделителя в конце
  DirPath := ExtractFilePath(FileMask);
  FileName := ExtractFileName(FileMask);

  if DirPath = '' then
    DirPath := '.\'; // текущий каталог, если путь не указан

  // Ищем только файлы (исключаем каталоги)
  if FindFirst(DirPath + FileName, faAnyFile - faDirectory, SearchRec) = 0 then
  begin
    try
      // Двойная проверка: даже после фильтрации faDirectory
      if (SearchRec.Attr and faDirectory) = 0 then
        Result := DirPath + SearchRec.Name;
    finally
      FindClose(SearchRec);
    end;
  end;
end;

function SearchFileTS(const FileMask: String; var TS: String): String;
var i,j,t: integer;
    S,R,N,P: String;
begin

S:=FileMask;

if TS='' then
  begin
  i:=LastDelimiter('#', S);
  if i>0 then
    begin
    N:=ExtractFileName(S);
    i:=LastDelimiter('#', N);
    j:=length(N)-i;

    S:=StringReplace(S,'#','*',[]);
    R:=SearchFileByEditTime(S,SearchFileCount);
    N:=ExtractFileName(R);
    TS:=copy(N,i,length(N)-j);
    result:=R;
    end
    else
    result:=SearchFileByEditTime(FileMask,t);
  end
  else
  begin
  P:=ExtractFilePath(S);
  N:=ExtractFileName(S);
  N:=StringReplace(N,'#',TS,[rfReplaceAll]);
  S:=P+N;
  if FileExists(S) then
    Result:=S
    else
    Result:=SearchFileByEditTime(S,t);
  end;
end;

function SearchFileTS_reliably(const FileMask: String; var TS: String; Start: double; Interval, Period: integer): String;
var Period_: int64;
begin
if TS='' then //Ожидаем только следующих файлов
  Period_:=0
  else
  Period_:=Period;
repeat
result:=SearchFileTS(FileMask,TS);
if result<>'' then break;
if Period_>0 then
  sleep(Interval*1000);
until ((now()-Start)*24*60*60>=Period_);
end;

begin
TimeStamp := '';
SearchFileCount := 0;
end.
