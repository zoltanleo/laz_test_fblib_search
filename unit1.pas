unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type
  TDBType = (dtFirebird, dtSqlite3);
  TLibBitness = (lbUnknown, lb32bit, lb64bit);

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    RadioGroup1: TRadioGroup;
    procedure Button1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RadioGroup1Click(Sender: TObject);
  private
    FDBType: TDBType;
    procedure GetLibList(aType: TDBType);
  public
    property DBType: TDBType read FDBType;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses
  FileUtil
  ;

{ *** Определение битности библиотеки *** }

{$IFDEF MSWINDOWS}

{ ADDED: функция определения битности библиотеки по PE-заголовку (Windows) }
{ На Windows читаем PE-заголовок через TFileStream.
  Typed-file API (Reset/BlockRead) подвержен WoW64 File System Redirector,
  из-за чего 32-битный процесс не может честно открыть файлы из System32.
  TFileStream открывает файл по точному пути без редиректа. }
function GetLibBitness(const APath: string): TLibBitness;
var
  FS: TFileStream;
  DosHeader: array[0..63] of Byte;
  PEOffset: LongWord;
  Machine: Word;
begin
  Result := lbUnknown;
  try
    FS := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
    try
      { Читаем DOS-заголовок (64 байта) }
      if FS.Read(DosHeader, SizeOf(DosHeader)) < 64 then Exit;

      { Проверяем сигнатуру MZ }
      if (DosHeader[0] <> $4D) or (DosHeader[1] <> $5A) then Exit;

      { e_lfanew по смещению 0x3C — смещение PE-заголовка }
      PEOffset := DosHeader[$3C]
               or (DosHeader[$3D] shl 8)
               or (DosHeader[$3E] shl 16)
               or (DosHeader[$3F] shl 24);

      { Переходим к IMAGE_FILE_HEADER, пропуская сигнатуру "PE\0\0" (4 байта) }
      FS.Seek(PEOffset + 4, soBeginning);

      { Читаем поле Machine (первые 2 байта IMAGE_FILE_HEADER) }
      if FS.Read(Machine, SizeOf(Machine)) < 2 then Exit;

      case Machine of
        $014C: Result := lb32bit;  { IMAGE_FILE_MACHINE_I386  }
        $8664: Result := lb64bit;  { IMAGE_FILE_MACHINE_AMD64 }
        $0200: Result := lb64bit;  { IMAGE_FILE_MACHINE_IA64  }
        $AA64: Result := lb64bit;  { IMAGE_FILE_MACHINE_ARM64 }
      end;
    finally
      FS.Free;
    end;
  except
    { файл заблокирован, нет прав — оставляем lbUnknown }
  end;
end;

{$ELSE}

{ ADDED: функция определения битности библиотеки по ELF-заголовку (Linux/macOS) }
{ На Linux/macOS читаем ELF-заголовок через TFileStream }
function GetLibBitness(const APath: string): TLibBitness;
var
  FS: TFileStream;
  ELFIdent: array[0..4] of Byte;
begin
  Result := lbUnknown;
  try
    FS := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
    try
      if FS.Read(ELFIdent, SizeOf(ELFIdent)) < 5 then Exit;

      { Проверяем ELF-магию: 0x7F 'E' 'L' 'F' }
      if (ELFIdent[0] <> $7F) or (ELFIdent[1] <> $45)
      or (ELFIdent[2] <> $4C) or (ELFIdent[3] <> $46) then Exit;

      { EI_CLASS: 1 = 32-бит, 2 = 64-бит }
      case ELFIdent[4] of
        1: Result := lb32bit;
        2: Result := lb64bit;
      end;
    finally
      FS.Free;
    end;
  except
  end;
end;

{$ENDIF}

function BitnessLabel(ABitness: TLibBitness): string;
begin
  case ABitness of
    lb32bit:   Result := '[32-bit]';
    lb64bit:   Result := '[64-bit]';
    lbUnknown: Result := '[?-bit] ';
  end;
end;

{ *** Добавление строк с битностью *** }

{ Для каждой найденной библиотеки в FL определяет битность
  и добавляет в Memo строки вида: "/usr/lib64/libfbclient.so.2 [64-bit]" }
procedure AddLibsWithBitness(AMemo: TMemo; FL: TStringList);
var
  j: Integer;
  Bitness: TLibBitness;
  Line: string;
begin
  for j := 0 to FL.Count - 1 do
  begin
    Bitness := GetLibBitness(FL[j]);
    Line := Format('%s %s',[FL[j], BitnessLabel(Bitness)]);
    AMemo.Lines.Add(Line);
  end;
end;

{ Пути поиска по платформам }

{$IFDEF MSWINDOWS}
function GetSearchPaths: TStringArray;
var
  SysDrive: string;
begin
  SysDrive := GetEnvironmentVariable('SystemDrive');
  if SysDrive = '' then SysDrive := 'C:';
  Result := [
    SysDrive + '\Windows\System32',
    SysDrive + '\Windows\SysWOW64'
  ];
end;
{$ELSE}
function GetSearchPaths: TStringArray;
begin
  Result := [
    '/opt/firebird/lib',
    '/usr/lib64',
    '/usr/lib',
    '/lib64',
    '/Library/Frameworks/Firebird.framework'
  ];
end;
{$ENDIF}

{ Маски файлов по типу БД и платформе }

function GetFileMasks(aType: TDBType): TStringArray;
begin
  case aType of
    dtFirebird:
      begin
        {$IFDEF MSWINDOWS}
        Result := ['fbclient.*', 'gds*.dll'];
        {$ELSE}
          {$IFDEF LINUX}
          Result := ['libfbclient.so.*'];
          {$ELSE}
          Result := ['Firebird', 'libfbclient.*'];
          {$ENDIF}
        {$ENDIF}
      end;
    dtSqlite3:
      begin
        {$IFDEF MSWINDOWS}
        Result := ['sqlite*.dll'];
        {$ELSE}
          {$IFDEF LINUX}
          Result := ['libsqlite3.*'];
          {$ELSE}
          Result := ['libtclsqlite3.*'];
          {$ENDIF}
        {$ENDIF}
      end;
  end;
end;

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
begin
  RadioGroup1Click(Sender);
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  //RadioGroup1Click(Sender);
end;

procedure TForm1.RadioGroup1Click(Sender: TObject);
begin
  case RadioGroup1.ItemIndex of
    0: FDBType:= dtFirebird;
    else
      FDBType := dtSqlite3;
  end;
  GetLibList(DBType);
end;

procedure TForm1.GetLibList(aType: TDBType);
var
  Paths, Masks: TStringArray;
  FL: TStringList;
  i, k: SizeInt;
begin
  Paths := GetSearchPaths;
  Masks := GetFileMasks(aType);

  FL := TStringList.Create;
  try
    Memo1.Lines.BeginUpdate;
    try
      Memo1.Clear;
      Memo1.Lines.Add(Format('=== начато: %s ===', [FormatDateTime('hh.nn.ss.zzz dd.mm.yyyy', Now)]));

      for i := Low(Paths) to High(Paths) do
        for k := Low(Masks) to High(Masks) do
        begin
          FL.Clear;
          FindAllFiles(FL, Paths[i], Masks[k], True);
          //Memo1.Lines.AddStrings(FL);
          AddLibsWithBitness(Memo1, FL);
        end;

      Memo1.Lines.Add(Format('=== закончено: %s ===', [FormatDateTime('hh.nn.ss.zzz dd.mm.yyyy', Now)]));
    finally
      Memo1.Lines.EndUpdate;
    end;
  finally
    FL.Free;
  end;
end;

end.

