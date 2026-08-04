unit MutexHash;

interface

const WaitSecProg = 60*10*1000;
const WaitSecLog = 5000;

var hMutexLog, hMutexProg: THandle;
    LogMutexName: AnsiString;
function FilePathToMutexHash(const FilePath: string): AnsiString;
procedure DumpErr(const sMSG:String);
procedure InitLogMutex(const sLogName:String);
function InitMutexProg: boolean;
procedure CloseMutex;
function LockLog: boolean;
procedure UnlockLog;




implementation
uses SysUtils, Windows, Classes, Types;
const MutexPrefix: AnsiString = 'Global\Apsida-IMPLog-';
var WaitRes: DWORD;



function FilePathToMutexHash(const FilePath: string): AnsiString;
type
  TCrcTable = array[0..255] of Cardinal;
var
  CrcTable: TCrcTable;
  I, J: Integer;
  Crc: Cardinal;
  B: Byte;
{$IFNDEF VER150} // Для XE7 и новее
  Bytes: TBytes;
{$ENDIF}
{$IFDEF VER150} // Для Delphi 7
  Utf8Str: UTF8String;
{$ENDIF}
begin
  // 1. Строим таблицу CRC32 (полином 0xEDB88320)
  for I := 0 to 255 do
  begin
    Crc := I;
    for J := 0 to 7 do
      if (Crc and 1) <> 0 then
        Crc := (Crc shr 1) xor $EDB88320
      else
        Crc := Crc shr 1;
    CrcTable[I] := Crc;
  end;

  // 2. Считаем CRC32 по байтам UTF?8
  Crc := $FFFFFFFF;

{$IFDEF VER150} // Delphi 7: нет TBytes, нет TEncoding
  Utf8Str := UTF8Encode(WideString(FilePath));
  for I := 1 to Length(Utf8Str) do
  begin
    B := Byte(Utf8Str[I]);
    Crc := CrcTable[(Crc xor B) and $FF] xor (Crc shr 8);
  end;
{$ELSE}          // XE7 и новее: используем TEncoding и TBytes
  Bytes := SysUtils.TEncoding.UTF8.GetBytes(FilePath);
  for I := Low(Bytes) to High(Bytes) do
  begin
    B := Bytes[I];
    Crc := CrcTable[(Crc xor B) and $FF] xor (Crc shr 8);
  end;
{$ENDIF}

  // 3. Финальная инверсия и HEX?результат
  Crc := not Crc;
  Result := SysUtils.IntToHex(Crc, 8);
end;

procedure DumpErr(const sMSG: string);
var
  FNM: string;
  F: TextFile;
begin
  FNM := ExtractFilePath(ParamStr(0)) + 'err.dmp';
  // Формируем строку с переносом
  AssignFile(F, FNM);
  try
  try
    if FileExists(FNM) then
      rewrite(F)
    else
      append(F);
  writeLN(DateTimeToStr(now())+' '+sMSG );
  finally
  CloseFile(F)
  end;
  except
  end;
end;

function InitMutexProg: boolean;
var MutexName: AnsiString;
begin
  MutexName := MutexPrefix + '-PRG';
  hMutexProg := CreateMutexA(nil, False, PAnsiChar(MutexName));
  if hMutexProg = 0 then
    begin
    DumpErr( 'Не удалось создать мьютекс '+MutexName+': ' + SysErrorMessage(GetLastError) );
    Result:=False;
    Exit;
    end;

  WaitRes := WaitForSingleObject(hMutexProg, WaitSecProg);

  case WaitRes of
    WAIT_OBJECT_0, WAIT_ABANDONED: result:=True;
    WAIT_TIMEOUT:                  result:=False;
    end;
end;

procedure InitLogMutex(const sLogName:String);
begin
  // Создаём именованный мьютекс. Префикс Global\ нужен, если программы могут запускаться в разных сессиях

  LogMutexName := MutexPrefix+FilePathToMutexHash(sLogName);
  hMutexLog := CreateMutexA(nil, False, PAnsiChar(LogMutexName));
  if hMutexLog = 0 then DumpErr( 'Не удалось создать мьютекс для лога: ' + SysErrorMessage(GetLastError) );
    //raise Exception.Create('Не удалось создать мьютекс для лога: ' + SysErrorMessage(GetLastError));
end;

function LockLog: boolean;
begin
  WaitRes := WaitForSingleObject(hMutexLog, WaitSecLog);

  case WaitRes of
    WAIT_OBJECT_0, WAIT_ABANDONED: result:=True;
    WAIT_TIMEOUT:                  result:=False;
    end;
end;
procedure UnlockLog;
begin
  if hMutexLog = 0 then
    Exit;
  ReleaseMutex(hMutexLog)
end;

procedure CloseMutex;
begin
if hMutexProg<>0 then CloseHandle(hMutexProg);
if hMutexLog<>0 then CloseHandle(hMutexLog);
end;

initialization
begin
hMutexLog := 0;
hMutexProg := 0;
end;

finalization
begin
CloseMutex;
end;
end.
 