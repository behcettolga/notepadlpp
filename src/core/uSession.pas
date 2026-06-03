// SPDX-License-Identifier: MPL-2.0
unit uSession;

{$mode objfpc}{$H+}

{ Workspace session: which files were open and which tab was active, so a launch
  can restore the previous working set (ARCHITECTURE §3.2, §4). UI-free core model.

  Kept separate from uConfig on purpose: uConfig is durable user *preferences*
  (theme, recent list, window box), while a session is volatile *workspace* state
  that is rewritten on every exit. The path is injectable for headless tests.

  JSON shape:
    {
      "activeIndex": 1,
      "files": [ { "path":"/a.txt", "line":0, "col":0 },
                 { "path":"/b.pas", "line":42, "col":4 } ]
    }
  Entries with a missing/empty path are skipped on load; a malformed file loads as
  an empty session rather than raising. }

interface

uses
  Classes, SysUtils, fpjson, jsonparser;

type

  { TSessionEntry — one previously-open file and its caret (0-based). }

  TSessionEntry = record
    FilePath: string;
    CaretLine, CaretCol: Integer;
  end;

  { TSession }

  TSession = class
  private
    FFilePath: string;
    FEntries: array of TSessionEntry;
    FActiveIndex: Integer;
  public
    constructor Create(const AFilePath: string = '');
    // Load replaces current entries; on any error the session ends up empty.
    procedure Load;
    procedure Save;
    procedure Clear;
    procedure AddFile(const APath: string; ACaretLine: Integer = 0;
      ACaretCol: Integer = 0);
    function Count: Integer;
    function Entry(AIndex: Integer): TSessionEntry;
    property ActiveIndex: Integer read FActiveIndex write FActiveIndex;
    property FilePath: string read FFilePath;
  end;

function DefaultSessionFile: string;

implementation

function DefaultSessionFile: string;
var base: string;
begin
  base := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if base = '' then
    base := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.config';
  Result := IncludeTrailingPathDelimiter(base) + 'notepadlpp' +
            PathDelim + 'session.json';
end;

constructor TSession.Create(const AFilePath: string);
begin
  inherited Create;
  if AFilePath <> '' then
    FFilePath := AFilePath
  else
    FFilePath := DefaultSessionFile;
  Clear;
end;

procedure TSession.Clear;
begin
  SetLength(FEntries, 0);
  FActiveIndex := -1;
end;

procedure TSession.AddFile(const APath: string; ACaretLine: Integer;
  ACaretCol: Integer);
var n: Integer;
begin
  if APath = '' then Exit;
  n := Length(FEntries);
  SetLength(FEntries, n + 1);
  FEntries[n].FilePath := APath;
  FEntries[n].CaretLine := ACaretLine;
  FEntries[n].CaretCol := ACaretCol;
  if FActiveIndex < 0 then
    FActiveIndex := 0;
end;

function TSession.Count: Integer;
begin
  Result := Length(FEntries);
end;

function TSession.Entry(AIndex: Integer): TSessionEntry;
begin
  Result := FEntries[AIndex];
end;

procedure TSession.Load;
var
  raw, path: string;
  data: TJSONData;
  root, obj: TJSONObject;
  arr: TJSONArray;
  i: Integer;
  fs: TFileStream;
  ss: TStringStream;
begin
  Clear;
  if not FileExists(FFilePath) then Exit;

  fs := TFileStream.Create(FFilePath, fmOpenRead or fmShareDenyWrite);
  try
    ss := TStringStream.Create('');
    try
      ss.CopyFrom(fs, fs.Size);
      raw := ss.DataString;
    finally
      ss.Free;
    end;
  finally
    fs.Free;
  end;

  data := nil;
  try
    try
      data := GetJSON(raw);
    except
      on E: Exception do
      begin
        Clear;
        Exit;
      end;
    end;

    if not (data is TJSONObject) then Exit;
    root := TJSONObject(data);

    arr := root.Find('files', jtArray) as TJSONArray;
    if arr <> nil then
      for i := 0 to arr.Count - 1 do
        if arr.Items[i].JSONType = jtObject then
        begin
          obj := TJSONObject(arr.Items[i]);
          path := obj.Get('path', '');
          if path <> '' then
            AddFile(path, obj.Get('line', 0), obj.Get('col', 0));
        end;

    // active index, clamped to the entries we actually loaded
    FActiveIndex := root.Get('activeIndex', FActiveIndex);
    if FActiveIndex >= Length(FEntries) then
      FActiveIndex := Length(FEntries) - 1;
    if (Length(FEntries) > 0) and (FActiveIndex < 0) then
      FActiveIndex := 0;
  finally
    data.Free;
  end;
end;

procedure TSession.Save;
var
  root, obj: TJSONObject;
  arr: TJSONArray;
  i: Integer;
  dir, text: string;
  fs: TFileStream;
begin
  root := TJSONObject.Create;
  try
    root.Add('activeIndex', FActiveIndex);
    arr := TJSONArray.Create;
    for i := 0 to High(FEntries) do
    begin
      obj := TJSONObject.Create;
      obj.Add('path', FEntries[i].FilePath);
      obj.Add('line', FEntries[i].CaretLine);
      obj.Add('col', FEntries[i].CaretCol);
      arr.Add(obj);
    end;
    root.Add('files', arr);
    text := root.FormatJSON;
  finally
    root.Free;
  end;

  dir := ExtractFileDir(FFilePath);
  if (dir <> '') and not DirectoryExists(dir) then
    ForceDirectories(dir);

  fs := TFileStream.Create(FFilePath, fmCreate);
  try
    if text <> '' then
      fs.WriteBuffer(text[1], Length(text));
  finally
    fs.Free;
  end;
end;

end.
