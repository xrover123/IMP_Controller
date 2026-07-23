unit Unit2;

interface

uses
  Windows, SysUtils;

var FERR:String;
    WaitMv, CheckTm: integer; //Параметры проверки изменяемости файла (с, ms)

function move(const F1, F2: String; MoveCount: integer; IntAtt: int64): boolean;
function Ansi1251ToWide(const S: AnsiString): WideString;
function RunAndWaitUnicode(const ExePath, Args: string; TimeoutMs: Cardinal = INFINITE): Cardinal;
function SaveFile(const FN1,FN2,DIR: String): boolean;

implementation

uses Unit1, Classes;

const
  CP_1251 = 1251;

function IsFileSizeStable(const FileName: string; StableDurationMs, TimeoutMs: Integer): Boolean;
var
  LastSize, CurSize: Int64;
  StartTime, CheckTime: Cardinal;
begin
  Result := False;

  Main.Label1.Caption:='Ожидание доступа к файлу.';
  Main.Update;

  if not FileExists(FileName) then
    Exit;

  // Получаем начальный размер
  with TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone) do
  try
    LastSize := Size;
  finally
    Free;
  end;

  StartTime := GetTickCount;
  CheckTime := StartTime;

  while (GetTickCount - StartTime) < TimeoutMs do
  begin
    Sleep(CheckTm); // опрос каждые 200 мс — можно менять

    with TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone) do
    try
      CurSize := Size;
    finally
      Free;
    end;

    if CurSize = LastSize then
    begin
      // Размер не менялся: проверяем, сколько времени он стабилен
      if (GetTickCount - CheckTime) >= StableDurationMs then
      begin
        Result := True;
        Main.Label1.Caption:='Копирование файла.';
        Main.Update;
        Exit;
      end;
    end
    else
    begin
      // Размер изменился — сбрасываем таймер стабильности
      LastSize := CurSize;
      CheckTime := GetTickCount;
    end;
  end;
  Main.Label1.Caption:='Файл продолжает писаться. Обработка откладывается!';
  Main.Update;
end;

function Ansi1251ToWide(const S: AnsiString): WideString;
var
  Len: Integer;
begin
  if S = '' then
  begin
    Result := '';
    Exit;
  end;
  Len := MultiByteToWideChar(CP_1251, 0, PAnsiChar(S), Length(S), nil, 0);
  SetLength(Result, Len);
  MultiByteToWideChar(CP_1251, 0, PAnsiChar(S), Length(S), PWideChar(Result), Len);
end;

function RunAndWaitUnicode(const ExePath, Args: string; TimeoutMs: Cardinal = INFINITE): Cardinal;
var
  StartupInfo: TStartupInfo;      // <-- используем стандартный тип из Windows.pas
  ProcInfo: TProcessInformation;
  CmdLineW: WideString;
  WaitResult: DWORD;
begin
  // Формируем командную строку в UTF-16 (WideString)
  CmdLineW := '"' + Ansi1251ToWide(ExePath) + '" ' + Ansi1251ToWide(Args);

  // Инициализируем структуру
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_SHOWNORMAL;

  // Вызываем CreateProcessW, передавая туда TStartupInfo
  if not CreateProcessW(nil, PWideChar(CmdLineW), nil, nil, False, 0, nil, nil,
                        StartupInfo, ProcInfo) then
    RaiseLastOSError;

  try
    WaitResult := WaitForSingleObject(ProcInfo.hProcess, TimeoutMs);
    if WaitResult = WAIT_TIMEOUT then
    begin
      TerminateProcess(ProcInfo.hProcess, 255);
      Result := 255;
      Exit;
    end;

    if not GetExitCodeProcess(ProcInfo.hProcess, Result) then
      RaiseLastOSError;
  finally
    CloseHandle(ProcInfo.hThread);
    CloseHandle(ProcInfo.hProcess);
  end;
end;

function move(const F1, F2: String; MoveCount: integer; IntAtt: int64): boolean;
  var N: integer;
      E: DWord;
  begin
  if FileExists(F2) then
    if not DeleteFile(PChar(F2)) then//Удаление старого временного файла, если он существует.
      begin
      result:=False;//Ошибка удаления временного файла приводит к невозможности
      FERR:='Не могу удалить временный файл "'+F2+'".';
      exit;         //перемещения файла, поэтому выходим из процедуры перемещения.
      end;
  if not IsFileSizeStable(F1,5000,WaitMv*1000) then
    begin
    result:=False;
    exit;
    end;
  N:=0;
  while not MoveFile(PAnsiChar(F1),PAnsiChar(F2)) do
    begin
    if N>MoveCount then
      break;
    E := GetLastError;
    case E of
      ERROR_SHARING_VIOLATION:
        Sleep(IntAtt*1000); // файл ещё занят — ждём
      ERROR_FILE_NOT_FOUND:
        begin
        FERR := 'Исходного файла уже нет (возможно, его удалили)' ;
        result := False;
        exit;
        end;
      ERROR_FILE_EXISTS:
        begin
        FERR := 'Целевой файл "'+F2+'" уже существует';
        result := False;
        exit;
        end;
      else
        begin
        FERR := SysErrorMessage(E); // другая ошибка — не повторяем
        result := False;
        exit;
        end;
      end;
    end;
  end;

function SaveFile(const FN1,FN2,DIR: String): boolean;
begin
try
  if not DirectoryExists(DIR) then
    ForceDirectories(DIR);
  CopyFile(PChar(FN1), PChar(DIR+FN2), True);
  result:=True;
  except on E: Exception do
    begin
    result := False;
    FERR := E.Message;
    end;
  end;
end;

end.
