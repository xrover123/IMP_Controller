unit Unit1;
{$B+}
interface

uses
  VCLFixes, VCLFixPack, VCLFlickerReduce, Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, INIFiles, ComCtrls, RXShell, StdCtrls, Unit3;

type TDays = array [1..7] of boolean;

type
  TMain = class(TForm)
    Timer1: TTimer;
    Timer2: TTimer;
    TrackBar1: TTrackBar;
    Label1: TLabel;
    Timer3: TTimer;
    procedure Timer1Timer(Sender: TObject);
    function FindFiles(F: TFoundFiles): boolean;
    //function FindFiles: TStringList;
    function  INIT: boolean;
    procedure RunProg;
    procedure LogWrite(const S: String; status: integer);
    procedure LogWriteAssured(const sMSG: String; status: integer);
    function  LogWriteFunc(const S: String): boolean;
    procedure RunIMP(const FN,Conn, Fls: String);
    procedure Timer2Timer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure LogHeapStatus(status: integer);
    procedure FormShow(Sender: TObject);
    procedure Timer3Timer(Sender: TObject);
  private
    ProgWait: Boolean;
    LogEnable: Boolean;
    MSK: TMsk;//TStringList;
    Dep: TDep;
    Files: TFoundFiles;
    FMATT: integer;
    TMPDIR:  String;
    LOGFILE: String;
    GrpID: String;
    StartTime: TDateTime;
    Int: integer;
    Per: integer;
    SH_BGN: integer;
    SH_END: integer;
    SH_INT: integer;
    Days: TDays;
    sImpSaveDir: String;
    ConnectStr: String;
    sDBN, sDBU, sDBP: String;
    ProgramName: String;
    RunProgTime: integer;
    AnswerLog: String;
    { Private declarations }
  public
    { Public declarations }
  end;


function IsSingleInstance(const AddMutex: String): Boolean;

var
  Main: TMain;
  T1,T2: TDateTime;
  MainConfig: String;
  LogStatus: Integer;
  hMutexProg: THandle;
  type EMyError01 = class(Exception);

implementation
uses Unit2, crypt, SearchFileByMask, psapi{, EasyCript;//w := GetPC;//GetCriptCode;},
  ShowErr, MutexHash;
{$R *.dfm}

function AddSuffixToFileName(const FileName, Suffix: string): string;
var
  Path, Base, Ext: string;
begin
  Path := ExtractFilePath(FileName);        // C:\
  Base := ChangeFileExt(ExtractFileName(FileName), ''); // MYFILE
  Ext  := ExtractFileExt(FileName);         // .txt

  Result := Path + Base + '_' + Suffix + Ext; // C:\MYFILE_<суффикс>.txt
end;


function GetProcessMemoryBytes: Int64;
var
  pmc: PROCESS_MEMORY_COUNTERS;
begin
  pmc.cb := SizeOf(pmc);
  if GetProcessMemoryInfo(GetCurrentProcess(), @pmc, SizeOf(pmc)) then
    Result := pmc.WorkingSetSize
  else
    Result := 0;
end;



function IsSingleInstance(const AddMutex: String): Boolean;//Проверка единичного запуска
const
  MutexPref = 'Global\Apsida-IMP_Controller';
var
  MutexName: String; // уникальное имя мьютекса

begin
  if AddMutex='' then
    MutexName := MutexPref
    else
    MutexName:=MutexPref+'('+AddMutex+')';
  // Пытаемся создать мьютекс. Если он уже есть — GetLastError вернёт ERROR_ALREADY_EXISTS
  hMutexProg := CreateMutex(nil, False, PChar(MutexName));

  if hMutexProg = 0 then
    raise Exception.Create('Не удалось создать мьютекс');

  if GetLastError = ERROR_ALREADY_EXISTS then
  begin
    // Мьютекс уже существует — значит, другой экземпляр запущен
    CloseHandle(hMutexProg);
    Result := False;
  end
  else
  begin
    // Мьютекса не было — мы его создали, значит, других экземпляров нет
    Result := True;
    // Не закрываем hMutex: пока процесс жив, мьютекс будет держать блокировку.
    // При завершении программы ОС сама его освободит.
  end;
end;



function GetPC: word; stdcall;
  external 'NetParam.dll' name 'GetPCCode';

function GetTime(const S: String; var sMSG: String): TDateTime;
  const sERR = 'Неправильный формат времени';
  var i: integer;
      S1, S2, S3: String;
  begin
  sMSG:='';

  if S='' then
    begin
    result:=0;
    exit;
    end;
  if (length(S)=8) and (S[3]=':') and (S[6]=':') then
    begin
    S1:=copy(S,1,2);
    S2:=copy(S,4,2);
    S3:=copy(S,7,2)
    end
  else if (length(S)=5) and (S[3]=':') then
    begin
    S1:=copy(S,1,2);
    S2:=copy(S,4,2);
    S3:='00';
    end
  else
    begin
    sMSG:=sERR+' "'+S+'"';
    result:=0;
    exit;
    end;
  try
    result := StrToInt(S1)/24 + StrToInt(S2)/(24*60) + StrToInt(S2)/(24*60*60);
    except on E: Exception do
      begin
      sMSG:=sERR+' "'+S+'"';
      result:=0;
      exit;
      end;
    end;
  end;

procedure TMain.LogWrite(const S: String; status: integer);
  var LOG: TextFile;
      X: String;
  begin

  try
    AssignFile(LOG, LOGFILE);
    if FileExists(LOGFILE) then
      Append(LOG)
      else
      rewrite(LOG);
    //WriteLN(LOG,FormatDateTime('dd.mm.yyyy HH:nn:ss', Now)+' '+S);
    if GrpID='' then
      X:=' Controller: '
      else
      X:=' ('+GrpID+') Controller: ';
    WriteLN(LOG,DateTimeToStr(Now)+X+S);
  finally
    try
    CloseFile(LOG);
    except
    end;
  end;
  end;


procedure TMain.LogWriteAssured(const sMSG: String; status: integer);
var WaitRes: DWORD;
begin
  if (status>LogStatus) or (not LogEnable) then exit;
  if hMutexLog = 0 then
    Exit;

  WaitRes := WaitForSingleObject(hMutexLog, 5000);

  // И WAIT_OBJECT_0, и WAIT_ABANDONED — значит, мьютекс теперь у нас
  if (WaitRes <> WAIT_OBJECT_0) and (WaitRes <> WAIT_ABANDONED) then
    Exit; // только таймаут и ошибки — выходим

  try
    if WaitRes = WAIT_ABANDONED then
      LogWrite('WARNING: захвачен заброшенный мьютекс (предыдущий процесс мог упасть)', 0);

    LogWrite(sMSG,0);
  finally
    ReleaseMutex(hMutexLog);
  end;
end;

function TMain.LogWriteFunc(const S: String): boolean;
  begin
  if length(S)>0 then
    begin
    LogWriteAssured(S,0);
    result:=True;
    end
    else
    result:=False;
  end;

function BytesToHuman(B: Int64): string;
const
  KB = 1024;
  MB = KB * 1024;
  GB = MB * 1024;
begin
  if B >= GB then
    Result := Format('%.2f GB', [B / GB])
  else if B >= MB then
    Result := Format('%.2f MB', [B / MB])
  else if B >= KB then
    Result := Format('%.2f KB', [B / KB])
  else
    Result := Format('%d B', [B]);
end;

procedure TMain.LogHeapStatus(status: integer);
var
  hs: THeapStatus;
  S: String;
begin
  if status>LogStatus then exit;
  hs := GetHeapStatus;
  S := #13#10'  TotalAllocated: ' + BytesToHuman(hs.TotalAllocated)+
       #13#10'  TotalFree:      ' + BytesToHuman(hs.TotalFree)+
       #13#10'  Overhead:       ' + BytesToHuman(hs.Overhead)+
       #13#10'  Unused:         ' + BytesToHuman(hs.Unused)+
       #13#10'  ProcessMemory   ' + BytesToHuman(GetProcessMemoryBytes);
  LogWriteAssured('HeapStatus:'+S,2);
end;

function TMain.FindFiles(F: TFoundFiles): boolean;
  var S: String;
      i: integer;
  begin
  F.Clear;
  //После этого времени остальные файлы группы будут ожидаться per секунд
  StartTime := now();
  for i := 0 to MSK.Count-1 do
    begin
    S:=SearchFileTS_reliably(MSK.Items[i].M,GrpID,StartTime,int,per);
    if S<>'' then F.Add(S,MSK.Items[i]);
    end;
  result := (F.Count > 0);
  end;
{
function TMain.FindFiles: TStringList;
  var SS: TStringList;
      S: String;
      i: integer;
  begin
  GrpID := '';

  //После этого времени остальные файлы группы будут ожидаться per секунд
  StartTime := now();

  SS := TStringList.Create;
  for i := 0 to MSK.Count-1 do
    begin
    S:=SearchFileTS_reliably(MSK.Items[i].M,GrpID,StartTime,int,per);
    if S<>'' then SS.Add(S);
    end;

  //Если за время per успели переместится все файлы
  if SS.Count=MSK.Count then
    result:=SS//Возвращаем список файлов
    else
    begin     //Если нет освобождаем список и возвращаем nil
    SS.Free;
    result:=nil;
    end;
  end;
}
procedure TMain.RunIMP(const FN,Conn, Fls: String);
  var S: String;
  begin
  S:=' '+IntToStr(LogStatus);
  if GrpID<>'' then S:=S+' '+GrpID;
  RunAndWaitUnicode(FN, Conn+' '+Fls+S, ProgWait)
  end;

function TestFile(const FileName: String): boolean;
  var F: TextFile;
      bb: boolean;
  begin
  bb := False;
  result := False;
  try
    AssignFile(F,FileName);
    try
      if FileExists(FileName) then
        append(F)
        else
        begin
        rewrite(F);
        bb:=True;
        end;
      result := True;
      finally
      CloseFile(F);
      end;
    except;
    end;
  try
    if bb then DeleteFile(FileName)
    except
    result := False;
    end;
  end;

function TMain.INIT: boolean;
  var TMP_FILE, FN: String;
      INI: TIniFile;
      w: word;
      bERR: boolean;
      sErr: String;
      i,j: integer;
      SH_DAY: String;
      SS: TStringList;
  begin
  result := True;
  if ParamCount>0 then
    try
      LogStatus:=StrToInt(ParamStr(1));
      except
      LogStatus:=0;
      end
    else
    LogStatus:=0;
  FN:=ExtractFilePath(ParamStr(0));
  if pos('\',MainConfig)<>0 then
    TMP_FILE := MainConfig
    else
    TMP_FILE := FN+MainConfig;
  if not FileExists(TMP_FILE) then
    begin
    //Label1.Caption := 'Не найден главный конфигурационный файл "'+TMP_FILE+'".';
    Timer3.Enabled:=True;
    ErrForm.ShowMessage('Не найден главный конфигурационный файл "'+TMP_FILE+'".');
    Exit;
    end;
  try
  INI := TIniFile.Create(TMP_FILE);

  LOGFILE := trim(INI.ReadString('OTHERS','IMP_LOG',''));
  if LOGFILE[2]<>':' then
    begin
    TMP_FILE := trim(INI.ReadString('OTHERS', 'LOG', ''));
    {$B-}
    if (length(TMP_FILE) > 0) and (TMP_FILE[length(TMP_FILE)] = '\') then
      LOGFILE := TMP_FILE + LOGFILE;
    end;
  if (LOGFILE='') or (not TestFile( LOGFILE )) then
    begin
    LogEnable := False;
    result:=False;
    INI.Free;
    exit;
    end
    else
    LogEnable := True;
  if LogEnable then
    InitLogMutex(LOGFILE);
  LogWriteAssured('Старт контроллера файлового импорта',0);

  ProgWait:=INI.ReadBool('OTHERS', 'PROG_WITE', True);

  AnswerLog := trim(INI.ReadString('OTHERS','IMP_ANSW',FN+'answer.tmp'));//Ответ от программы импорта
  if ProgWait and (AnswerLog<>'') and (not TestFile( AnswerLog )) then
    begin
    result:=False;
    INI.Free;
    LogWriteAssured('Нет доступа к файлу ответа"'+AnswerLog+'"!',0);
    exit;
    end;

  ProgramName := trim(INI.ReadString('OTHERS','IMP_PROG',''));
  if ProgramName<>'' then
    begin
    if pos('\', ProgramName)=0 then
      ProgramName := FN+ProgramName;

    if not FileExists( ProgramName ) then
      begin
      result:=False;
      INI.Free;
      LogWriteAssured('Не найдена программа импорта "'+ProgramName+'"!',0);
      exit;
      end;
    end;


  SH_DAY := trim(INI.ReadString('SHEDULER','IMP_DEY','1,2,3,4,5,6'));
  SH_BGN := trunc(getTime(trim(INI.ReadString('SHEDULER','IMP_BGN','00:00')),sErr)*24*60*60);
  if sErr<>'' then LogWriteAssured(sErr + ' в параметре "IMP_BGN" секции "SHEDULER" конфигурационного файла "exchange.ini".',0);
  SH_END := trunc(getTime(trim(INI.ReadString('SHEDULER','IMP_END','20:30')),sErr)*24*60*60);
  if sErr<>'' then LogWriteAssured(sErr + ' в параметре "IMP_END" секции "SHEDULER" конфигурационного файла "exchange.ini".',0);
  SH_INT := INI.ReadInteger('SHEDULER','IMP_INT',3*60)*1000;
  TrackBar1.Min := trunc(frac(now())*24*60*60);
  TrackBar1.Max := SH_END;

  SS:=TStringList.Create;
  try
    SS.CommaText := SH_DAY;
    for i := 1 to 7 do Days[i]:=False;
    for i := 0 to SS.Count-1 do
      begin
      SH_DAY:=SS.Strings[i];
      if (Length(SH_DAY)=1) then
        case SH_DAY[1] of
          '1': Days[1]:=true;
          '2': Days[2]:=true;
          '3': Days[3]:=true;
          '4': Days[4]:=true;
          '5': Days[5]:=true;
          '6': Days[6]:=true;
          '7': Days[7]:=true;
          end;
      end;
  finally
    SS.Free;
  end;

  FMATT:=INI.ReadInteger('FILE','IMP_FILE_MOVE_ATT',10);//Кол-во попыток перемещения
  Int:=INI.ReadInteger('FILE','IMP_FILE_MOVE_SLEEP',60); //задержка перед следующим поиском (с)
  Per:=INI.ReadInteger('FILE','IMP_FILE_MOVE_TIME',60*20);//Период ожидания следующих за первым файлов (с)
  WaitMv:=INI.ReadInteger('FILE','IMP_FILE_WAIT_MOVE',60*10); //Ожидание стабильности файла (с)
  WaitMv:=INI.ReadInteger('FILE','IMP_FILE_CHECK_INTERVAL',500); //Ожидание стабильности файла (интервал проверки изменений (мс))
  TMPDIR:=trim(INI.ReadString('FILE','IMP_FILE_MOVE_TMP',ExtractFilePath(ParamStr(0))));
  if not TestFile(TMPDIR+'tst') then
    begin
    result:=False;
    INI.Free;
    LogWriteAssured('В дирректории "'+TMPDIR+'" не возможна запись файла!',1);
    exit;
    end;

  sDBN:=trim(INI.ReadString('DB','DB_NAME',''));
  sDBU:=trim(INI.ReadString('DB','USER',''));
  sDBP:=trim(INI.ReadString('DB','PSW',''));

  if (sDBN='') or (sDBU='') or (sDBP='') then
    begin
    result:=False;
    INI.Free;
    LogWriteAssured('Заданы не все параметры подключения к БД!',0);
    exit;
    end;

{  try
    w := GetPC;//GetCriptCode;
    bErr:=False
    except on E: Exception do
      begin
      bErr:=True;
      sErr:=E.Message;
      end;
    end;
  if bErr then
    begin
    LogWriteAssured('Процедура определения ID компьютера выдала ошибку: '+sErr,0);
    exit;
    Close;
    end;
  sDBP := DecryptStr(sDBP,w);}
  sDBP:=myCrypt( sDBP, coDecrypt, litter, PswLen );

  i:=pos(chr(10),sDBP);
  setLength(sDBP,i-1);
  ConnectStr := sDBU+'/'+sDBP+'@'+sDBN;

  sImpSaveDir := trim(INI.ReadString('FILE','IMP_SAVE_PATH',''));

  SS:=nil;
  try
    SS:=TStringList.Create;
  //INI.ReadSectionValues('FILES',MSK);
    try
      INI.ReadSectionValues('FILES',SS);
      MSK.AddStrings(SS);
      SS.Clear;
      INI.ReadSectionValues('DEPENDENCIES',SS);
      DEP.AddStrings(SS);
      MSK.Link(DEP);
    finally
      SS.Free;
    end;
  except
  end;
  if MSK.Count=0 then
    begin
    result:=False;
    INI.Free;
    LogWriteAssured('Не заданы маски файлов!',0);
    exit;
    end;

{  for i := 0 to MSK.Count-1 do
    begin
    FN:=MSK.ValueFromIndex[i];
    j:=pos(';',FN);
    FN:=copy(FN,1,j-1);
    if j>0 then MSK.Strings[i]:=FN;
    end;}
  INI.Destroy;
  LogWriteAssured('Чтение настроек контроллера файлового импорта закончено.',1);
  except
    try
      result:=False;
      INI.Destroy;
      except
      end;
  end;
  end;

procedure TMain.RunProg; //Основная процедура обработки файлов
  const INIFN = 'files.ini';
  var TMP_F, ANSW, SS: TStringList;
      i,j,n: integer;
      FName, TMP_FILE, FN, FILES_FN: String;
      SX, BackupDir : String;
      bMove: boolean;
  procedure CancelMove;
    var i: integer;
    begin
    for i := 0 to TMP_F.Count-1 do
      begin
      TMP_FILE:=TMP_F.ValueFromIndex[i];
      FName:=Files.Items[i].FileName;
      move(TMP_FILE, FName, FMATT, Int);
      Label1.Caption:='Копирование закончено!';
      Update;
      LogWriteAssured('Файл "'+TMP_FILE+'" возвращен на базу "'+ExtractFilePath(FName)+'".',0);
      end;
    end;
  begin
  GrpID := '';
  //Поиск файлов, заданных в ini-файле по маскам в MSK.
  //Files:=FindFiles;//Просто поиск файлов без попыток их перетаскивания

  LogWriteAssured('Запуск поиска новых файлов.',2);

  if sImpSaveDir<>'' then
    begin
    SX:=FormatDateTime('dd.mm.yyyy hh:nn:ss', now());//DateTimeToStr(now());
    for j:=1 to length(SX) do
      case SX[j] of
        '0'..'9': ;
        ' ': SX[j]:='\';
        ':': SX[j]:='-';
        '/','\','.': SX[j]:='.'
        else SX[j]:='-';
        end;
      BackupDir := sImpSaveDir+'IMP_'+SX+'\';//Дирректория для бекапа
    end;

  try
    if not FindFiles(Files) then
      begin
      GrpID := '';
      exit;//Файлы не найдены, выходим
      end;
    except on E: Exception do
      LogWriteAssured('Ошибка при поиске файлов:'#13#10+E.Message,0);
    end;

  TMP_F := TStringList.Create;
  for i :=0 to Files.Count-1 do
    begin
    if not Files.Items[i].Enabled then Continue;
    TMP_FILE := TMPDIR+ExtractFileName(Files.Items[i].FileName);
    FName := Files.Items[i].FileName;
    //Перемещение во временную дирректорию
    bMove:=move(FName,TMP_FILE,FMATT,Int);

    if not CheckFile(TMP_FILE) then
      begin
      Label1.Caption:='Проверка содержания файла дала отрицательный результат.';Update;
      if bMove then
        begin
        DeleteFile(TMP_FILE);//Удаляем текущий файл из временной дирректории
        LogWriteAssured('Файл "'+Files.Items[i].FileName+'" не имеел значащих строк и был удален.',1);
        end
        else
        LogWriteAssured('Файл "'+Files.Items[i].FileName+'" не был найден.',1);
      //Удаляем подчиненные файлы из дирректории забора файлов
      SX:='';
      try
        SS:=TStringList.Create;
        try
          Files.FindAllChild(i,SS);
          for j:=0 to SS.Count-1 do
            if FileExists(SS.Strings[j]) then
              begin
              DeleteFile(SS.Strings[j]);
              SX:=SX+#13#10'  '+SS.Strings[j];
              end;
        finally
          SS.Free;
        end;
      except
      end;
      if SX<>'' then
        LogWriteAssured('Так как "'+Files.Items[i].FileName+'" не имеел значащих строк,'#13#10'следующие файлы были также удалены:'+SX,1);
//      TMP_F.Free;
//      Files.Clear;
      //exit;
      continue;
      end;
    if not bMove then
      begin
      Label1.Caption:='Файл не смог переместится во временную дирректорию.';Update;
      LogWriteAssured('Файл "'+Files.Items[i].FileName+'" не смог переместится в дирректорию "'+TMPDIR+'".'#13#10'  Ошибка: '+FERR,0);
      continue;
      end;
    Label1.Caption:='Проверка содержания файла дала положительный результат.';Update;
    LogWriteAssured('Найден новыq файл "'+FName+'".',1);
    //Вычисление дирректории для бекапа
    if sImpSaveDir<>'' then
      begin
      SX:=ExtractFileName(TMP_FILE);   //Имя файла для бекапирования
      if SaveFile(TMP_FILE, SX, BackupDir) then//Бекапим из временной дирректории
        LogWriteAssured('Создана резервная копия файла "'+SX+'"  в директории "'+sImpSaveDir+'". ',1)
        else
        LogWriteAssured('Файл "'+SX+'" не забекапился. '+FERR,1);
      end;

    //Вносим изменение в список файлов, там будут файлы из временной дирректории
    //TMP_F.Add( 'F' + IntToStr(i+1) + '=' + TMP_FILE );
    TMP_F.Add( Files.Items[i].FileAttr.F + '=' + TMP_FILE )
    end;

  if (TMP_F.Count>0) and (ProgramName<>'') then
    begin
    //Сохраняем список файлов для использования программой импорта
    if GrpID='' then
      FILES_FN := INIFN
      else
      FILES_FN := AddSuffixToFileName(INIFN,GrpID);
    TMP_F.SaveToFile(FN+FILES_FN);
    //Запускаем программу импорта с указанием строки подключения и списка файлов
    try
      LogWriteAssured('Запуск "'+ProgramName+' '+sDBU+'/***@'+sDBN+' '+INIFN+'".',2);
      RunIMP(ProgramName,ConnectStr,FILES_FN);
      LogWriteAssured('Отработала программа импоорта "'+ProgramName+'".',2);
      if ProgWait and FileExists( AnswerLog ) then
        begin
        LogWriteAssured('Получен файл ответа "'+ProgramName+'".',1);
        ANSW := nil;
        try
        ANSW := TStringList.Create;
        try
          ANSW.CaseSensitive:=False;
          ANSW.LoadFromFile(AnswerLog);
          DeleteFile(AnswerLog);
          for i := 0 to Files.Count-1 do SX:=SX+chr(10)+'  "'+Files.Items[i].FileName+'";';
          SX := UpperCase(trim(ANSW.Values['SUCCESS']));
          LogWriteAssured('Получен ответ от программы импорта: SUCCESS="'+SX+'".',1);
          if (SX = 'YES') or (SX = 'Y') or (SX = 'OK') or (SX = '1') then
            begin
            setLength(SX,0);
            for i := 0 to Files.Count-1 do SX:=SX+chr(10)+'  "'+Files.Items[i].FileName+'";';
            if Length(SX)>0 then SX[Length(SX)] := chr(10);
            LogWriteAssured('Файлы:' + SX + 'были удачно импортированы в базу "'+sDBN+'".',0);
            end
            else
            begin
            LogWriteAssured('Программа импорта закончилась с ошибками.',0);
            SX := ANSW.Text;
            LogWriteAssured('Файл ответа:'+#13#10+SX,1);
            i:=0;
            if LogStatus=0 then
              repeat
              inc(i);
              SX:=ANSW.Values['ERROR'+IntToStr(i)];
              until not LogWriteFunc(SX);
            end;
          except on E: Exception do LogWriteFunc('Ошибка распознания файла ответа: '+E.Message);
          end;
        finally
        ANSW.Free;
        end
        end
        else
        begin
        if ProgWait and (AnswerLog<>'') then
          LogWriteAssured('Не получен файл ответа "'+AnswerLog+'"!',0);
        //raise EMyError01.Create('Не получен файл ответа "'+AnswerLog+'"!');
        end;
      except
        on E: EMyError01 do
          begin
          CancelMove;
          end;
        on E: Exception do
          begin
          LogWriteAssured('Не могу запустить программу импорта файлов "'+ProgramName+'". Ошибка: '+E.Message,0);
          CancelMove;
          end;
      end;
    end;
  Files.Clear;
  TMP_F.Free;
  GrpID := '';
  Label1.Caption := 'Режим поиска файлов.'; Update;
  end;

procedure TMain.Timer1Timer(Sender: TObject);
  var bb: boolean;
  begin
  Timer1.Enabled:=False;
  bb:=INIT;
  if bb then
    begin
    RunProg;
    Timer2.Interval:=SH_INT;
    Timer2.Enabled:=True;
    end
    else
    begin
    if LogEnable then
      ErrForm.ShowMessage('Ошибка инициализации см.LOG!)')
      else
      ErrForm.ShowMessage('Не могу открыть LOG!');
    Timer3.Enabled:=True;
    end;
  end;

procedure TMain.Timer2Timer(Sender: TObject);
 var T: TDateTime;
     TT: integer;
  begin
  T:=now();
  LogWriteAssured('Отработка очередного такта (период: '+FormatDateTime('HH:nn:ss',Timer2.Interval/(24 * 60 * 60 * 1000))+').',2);
  LogHeapStatus(2);
  TT:=trunc(frac(T)*24*60*60);
  if (TT>=SH_BGN) and (TT<=SH_END) then
    begin
    if Days[DayOfWeek(T)] then
      begin;
      Label1.Caption:='Поиск файлов по маскам.';
      Update;
      if not TrackBar1.Visible then
        begin
        if LogStatus=1 then LogHeapStatus(1);
        TrackBar1.Visible := True;
        TrackBar1.Min := SH_BGN;
        LogWriteAssured('Перехожу в режим периодического поиска новых файлов (период: '+FormatDateTime('HH:nn:ss',Timer2.Interval/(24 * 60 * 60 * 1000))+').',1);
        end;
      TrackBar1.Position := trunc(frac(now())*24*60*60);
      repeat
        RunProg;
        until SearchFileCount<2;
      end
      else if TrackBar1.Visible then
        begin
        LogHeapStatus(1);
        TrackBar1.Visible:=False;
        LogWriteAssured('Перехожу в режим сна.',1);
        Label1.Caption:='Режим сна.';
        Update;
        end
    end
    else
    begin
    //Если не задано начало раб.дня это одноразовый запуск до окончания раб.дня.
    if (trunc(SH_BGN)=0) then
      begin
      Close; //Поэтому выходим из программы
      exit;
      end;
    if TrackBar1.Visible then TrackBar1.Visible:=False;
    Label1.Caption:='Режим сна.';
    Update;
    end;
  end;

procedure TMain.FormCreate(Sender: TObject);
begin
MSK:=TMsk.Create;
DEP:=TDep.Create;
Files:=TFoundFiles.Create;
end;

procedure TMain.FormDestroy(Sender: TObject);
begin
MSK.Free;
DEP.Free;
Files.Free;
end;

procedure TMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
Timer1.Enabled := False;
Timer2.Enabled := False;
Timer3.Enabled := False;
LogWriteAssured('Закрытие контроллера импорта файлов.',0);
end;

procedure TMain.FormShow(Sender: TObject);
begin
Label1.Caption:='Старт!';
Update;
end;

procedure TMain.Timer3Timer(Sender: TObject);
begin
Close;
end;

begin
T1:=now();

end.
