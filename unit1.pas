unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls;

type
  TDBType = (dtFirebird, dtSqlite3);

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
          Memo1.Lines.AddStrings(FL);
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

