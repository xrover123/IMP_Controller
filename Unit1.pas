unit Unit1;
{$B+}
interface

uses
  VCLFixes, VCLFixPack, VCLFlickerReduce, Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, INIFiles, ComCtrls, RXShell, StdCtrls;

type TDays = array [1..7] of boolean;

type
  TMain = class(TForm)
    Timer1: TTimer;
    Timer2: TTimer;
    TrackBar1: TTrackBar;
    procedure Timer1Timer(Sender: TObject);
    function FindFiles: TStringList;
    procedure INIT;
    procedure RunProg;
    procedure LogWrite(const S: String);
    procedure RunIMP(const FN,Conn, Fls: String);
    procedure Timer2Timer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    MSK: TStringList;
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
    RunProgTime: integer;
    AnswerLog: String;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Main: TMain;
  T1,T2: TDateTime;
  type EMyError01 = class(Exception);

implementation
uses Unit2, EasyCript, SearchFileByMask;
{$R *.dfm}

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

procedure TMain.LogWrite(const S: String);
  var LOG: TextFile;
  begin
  try
    AssignFile(LOG, LOGFILE);
    if FileExists(LOGFILE) then
      Append(LOG)
      else
      rewrite(LOG);
    WriteLN(LOG,FormatDateTime('dd.mm.yyyy hh:nn:ss', Now)+' '+S);
  finally
    try
    CloseFile(LOG);
    except
    end;
  end;
  end;

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
    S:=SearchFileTS_reliably(MSK.Strings[i],GrpID,StartTime,int,per);
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
procedure TMain.RunIMP(const FN,Conn, Fls: String);
  begin
  RunAndWaitUnicode(FN, Conn+' '+Fls)
  end;

procedure TMain.INIT;
  var TMP_FILE, FN: String;
      INI: TIniFile;
      w: word;
      bERR: boolean;
      sErr: String;
      i,j: integer;
      SH_DAY: String;
      SS: TStringList;
  begin
  try
  FN:=ExtractFilePath(ParamStr(0));
  INI := TIniFile.Create(FN+'exchange.ini');

  AnswerLog := trim(INI.ReadString('OTHERS','IMP_ANSW','answer.tmp'));//Ответ от программы импорта

  SH_DAY := trim(INI.ReadString('SHEDULER','IMP_DEY','1,2,3,4,5,6'));
  SH_BGN := trunc(getTime(trim(INI.ReadString('SHEDULER','IMP_BGN','00:00')),sErr)*24*60*60);
  if sErr<>'' then LogWrite(sErr + ' в параметре "IMP_BGN" секции "SHEDULER" конфигурационного файла "exchange.ini".');
  SH_END := trunc(getTime(trim(INI.ReadString('SHEDULER','IMP_END','20:30')),sErr)*24*60*60);
  if sErr<>'' then LogWrite(sErr + ' в параметре "IMP_END" секции "SHEDULER" конфигурационного файла "exchange.ini".');
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
  Per:=INI.ReadInteger('FILE','IMP_FILE_MOVE_TIME',60*15);//Период ожидания следующих за первым файлов (с)
  TMPDIR:=trim(INI.ReadString('FILE','IMP_FILE_MOVE_TMP',ExtractFilePath(ParamStr(0))));

  LOGFILE := trim(INI.ReadString('OTHERS','IMP_LOG',''));
  if LOGFILE[2]<>':' then
    begin
    TMP_FILE := trim(INI.ReadString('OTHERS', 'LOG', ''));
    {$B-}
    if (length(TMP_FILE) > 0) and (TMP_FILE[length(TMP_FILE)] = '\') then
      LOGFILE := TMP_FILE + LOGFILE;
    end;

  try
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
    LogWrite('Процедура определения ID компьютера выдала ошибку: '+sErr);
    exit;
    Close;
    end;

  sDBN:=trim(INI.ReadString('DB','DB_NAME',''));
  sDBU:=trim(INI.ReadString('DB','USER',''));
  sDBP:=trim(INI.ReadString('DB','PSW',''));

  sDBP := DecryptStr(sDBP,w);
  i:=pos(chr(10),sDBP);
  setLength(sDBP,i-1);
  ConnectStr := sDBU+'/'+sDBP+'@'+sDBN;

  sImpSaveDir := trim(INI.ReadString('FILE','IMP_SAVE_PATH',FN+'IMP_SAVE\'));

  INI.ReadSectionValues('FILES',MSK);
  for i := 0 to MSK.Count-1 do
    begin
    FN:=MSK.ValueFromIndex[i];
    j:=pos(';',FN);
    FN:=copy(FN,1,j-1);
    if j>0 then MSK.Strings[i]:=FN;
    end;
  finally
  INI.Destroy;
  end;

  end;

procedure TMain.RunProg; //Основная процедура обработки файлов
  const INIFN = 'files.ini';
  var Files, TMP_F, ANSW: TStringList;
      i,j: integer;
      FName, TMP_FILE, FN: String;
      SX, ISD: String;
  procedure CancelMove;
    var i: integer;
    begin
    for i := 0 to TMP_F.Count-1 do
      begin
      TMP_FILE:=TMP_F.ValueFromIndex[i];
      FName:=Files.Strings[i];
      move(TMP_FILE, FName, FMATT, Int);
      LogWrite('Файл "'+TMP_FILE+'" возвращен на базу "'+ExtractFilePath(FName)+'".');
      end;
    end;
  begin

  //Поиск файлов, заданных в ini-файле по маскам в MSK.
  Files:=FindFiles;

  if Files=nil then exit;//Файлы не найдены, выходим
  TMP_F := TStringList.Create;
  for i :=0 to Files.Count-1 do
    begin
    TMP_FILE := TMPDIR+ExtractFileName(Files.Strings[i]);
    FName := Files.Strings[i];
    //Перемещение во временную дирректорию
    move(FName,TMP_FILE,FMATT,Int);

    //Вычисление дирректории для бекапа
    SX:=FormatDateTime('dd.mm.yyyy hh:nn:ss', now());//DateTimeToStr(now());
    for j:=1 to length(SX) do
      case SX[j] of
        '0'..'9': ;
        ' ': SX[j]:='\';
        ':': SX[j]:='-';
        '/','\','.': SX[j]:='.'
        else SX[j]:='-';
      end;

    ISD := sImpSaveDir+'IMP_'+SX+'\';//Дирректория для бекапа

    SX:=ExtractFileName(TMP_FILE);   //Имя файла для бекапирования
    if SaveFile(TMP_FILE, SX, ISD) then//Бекапим из временной дирректории
      LogWrite('Создана резервная копия файла "'+SX+'"  в директории "'+sImpSaveDir+'". ')
      else
      LogWrite('Файл "'+SX+'" не забекапился. '+FERR);

    //Вносим изменение в список файлов, там будут файлы из временной дирректории
    TMP_F.Add( 'F' + IntToStr(i+1) + '=' + TMP_FILE );
    end;

  //Сохраняем список файлов для использования программой импорта
  TMP_F.SaveToFile(FN+INIFN);
  //Запускаем программу импорта с указанием строки подключения и списка файлов
  try

    RunIMP(FN+'ORAIMP.EXE',ConnectStr,INIFN);
    if FileExists( AnswerLog ) then
      begin
      ANSW := TStringList.Create;
      try
        ANSW.LoadFromFile(AnswerLog);
        for i := 0 to Files.Count-1 do SX:=SX+chr(10)+'  "'+Files.Strings[i]+'";';
        SX := UpperCase(trim(ANSW.Values['SUCCESS']));
        if (SX = 'YES') or (SX = 'Y') or (SX = 'OK') or (SX = '1') then
          begin
          setLength(SX,0);
          for i := 0 to Files.Count-1 do SX:=SX+chr(10)+'  "'+Files.Strings[i]+'";';
          if Length(SX)>0 then SX[Length(SX)] := chr(10);
          LogWrite('Файлы:' + SX + 'были удачно импортированы в базу "'+sDBN+'".');
          end
          else
          ;
        finally
        ANSW.Free;
        end;
      end
      else
      begin
      raise EMyError01.Create('Не получен файл ответа "'+AnswerLog+'"!');
      end;
    except
      on E: EMyError01 do
        begin
        LogWrite('Запущена программа импорта из файлов. Ошибка: '+E.Message);
        CancelMove;
        end;
      on E: Exception do
        begin
        LogWrite('Не могу запустить программу импорта файлов ORAIMP.EXE. Ошибка: '+E.Message);
        CancelMove;
        end;
    end;
  Files.Free;
  TMP_F.Free
  end;

procedure TMain.Timer1Timer(Sender: TObject);
  begin
  Timer1.Enabled:=False;
  INIT;
  RunProg;
  Timer2.Interval:=SH_INT;
  Timer2.Enabled:=True;
  end;

procedure TMain.Timer2Timer(Sender: TObject);
 var T: TDateTime;
     TT: integer;
  begin
  T:=now();

  TT:=trunc(frac(T)*24*60*60);
  if (TT>=SH_BGN) and (TT<=SH_END) then
    begin
    if Days[DayOfWeek(T)] then
      begin;
      if not TrackBar1.Visible then
        begin
        TrackBar1.Visible := True;
        TrackBar1.Min := SH_BGN;
        end;
      TrackBar1.Position := trunc(frac(now())*24*60*60);
      repeat
        RunProg;
        until SearchFileCount<2
      end
      else if TrackBar1.Visible then TrackBar1.Visible:=False;
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
    end;
  end;

procedure TMain.FormCreate(Sender: TObject);
begin
MSK:=TStringList.Create;
end;

procedure TMain.FormDestroy(Sender: TObject);
begin
MSK.Free;
end;

begin
T1:=now();
end.
