unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses
  FileUtil
  ;


{ TForm1 }
const
  {$IFDEF MSWINDOWS}
  fnmasks: array[0..1] of string = ('fbclient.*','gds*.dll');
  {$ELSE}
    {$IFDEF CACAO}
      fnmasks: array[0..0] of string = ('libfbclient.so.*');
    {$ELSE}
      fnmasks: array[0..1] of string = ('Firebird', 'libfbclient.*');
    {$ENDIF}
  {$ENDIF}

  {$IFNDEF MSWINDOWS}
  PATH_FIREBIRD_LIB   = '/opt/firebird/lib';
  PATH_USR_LIB64      = '/usr/lib64';
  PATH_USR_LIB        = '/usr/lib';
  PATH_USR_LIB_X86    = '/usr/lib/x86_64-linux-gnu';
  PATH_FRAMEWORKS_FB  = '/Library/Frameworks/Firebird.framework';
  {$ENDIF}

var
  path_arr: array of string;

{$IFDEF MSWINDOWS}
procedure FillPaths;
var
  SysDrive: string;
begin
  SysDrive := GetEnvironmentVariable('SystemDrive');
  if SysDrive = '' then SysDrive := 'C:';
  path_arr := [
    SysDrive + '\Windows\System32',
    SysDrive + '\Windows\SysWOW64'
  ];
end;
{$ELSE}
procedure FillPaths;
begin
  path_arr := [
    PATH_FIREBIRD_LIB,
    PATH_USR_LIB64,
    PATH_USR_LIB,
    PATH_USR_LIB_X86,
    PATH_FRAMEWORKS_FB
  ];
end;
{$ENDIF}

procedure TForm1.Button1Click(Sender: TObject);
var
  i: SizeInt = -1;
  j: SizeInt = -1;
  k: SizeInt = -1;
  FL: TStringList = nil;
begin
  FillPaths;
  FL:= TStringList.Create;
  Memo1.Clear;
  Memo1.Lines.Add(Format('=== начато: %s ===',[FormatDateTime('hh.nn.ss.zzz dd.mm.yyyy',Now)]));
  try
    for i:= Low(path_arr) to High(path_arr) do
    begin
      for k := Low(fnmasks) to High(fnmasks) do
      begin
        FL.Clear;
        FindAllFiles(FL, path_arr[i], fnmasks[k], False);
        for j := 0 to Pred(FL.Count) do Memo1.Lines.Add(FL.Strings[j]);
      end;
    end;
  finally
    FL.Free;
    Memo1.Lines.Add(Format('=== закончено: %s ===',[FormatDateTime('hh.nn.ss.zzz dd.mm.yyyy',Now)]));
  end;
end;

end.

