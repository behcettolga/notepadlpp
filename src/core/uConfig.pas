// SPDX-License-Identifier: MPL-2.0
unit uConfig;

{$mode objfpc}{$H+}

{ Persistent application settings, stored as JSON (CudaText-style, ARCHITECTURE
  §3.4). UI-free core model (§4): holds recent-files list, theme name, and window
  geometry, and round-trips them through a JSON file. The file path is injectable
  so the suite can exercise load/save against a temp file with no UI or HOME deps.

  JSON shape:
    {
      "theme": "dark",
      "maxRecent": 10,
      "recentFiles": ["/a.txt", "/b.pas"],
      "window": { "left":100, "top":80, "width":1000, "height":700,
                  "maximized":false, "valid":true }
    }
  Unknown keys are ignored; missing keys fall back to defaults. A malformed file
  never raises out of Load — it resets to defaults so a corrupt config can't wedge
  startup. }

interface

uses
  Classes, SysUtils, fpjson, jsonparser;

type

  { TWindowState — last window geometry. Valid=False means "never saved yet",
    so the UI should fall back to its default placement. }

  TWindowState = record
    Left, Top, Width, Height: Integer;
    Maximized: Boolean;
    Valid: Boolean;
  end;

  { TConfig }

  TConfig = class
  private
    FFilePath: string;
    FRecentFiles: TStringList;
    FTheme: string;
    FWindowState: TWindowState;
    FMaxRecent: Integer;
    procedure SetDefaults;
    procedure TrimRecent;
  public
    constructor Create(const AFilePath: string = '');
    destructor Destroy; override;
    // Load reads the file if present; on any error it resets to defaults.
    procedure Load;
    // Save writes pretty-printed JSON, creating the parent directory if needed.
    procedure Save;
    // AddRecentFile pushes a path to the front (most-recent-first), de-duplicates
    // case-sensitively, and caps the list at MaxRecent.
    procedure AddRecentFile(const APath: string);
    procedure ClearRecent;
    property FilePath: string read FFilePath;
    property RecentFiles: TStringList read FRecentFiles;
    property Theme: string read FTheme write FTheme;
    property WindowState: TWindowState read FWindowState write FWindowState;
    property MaxRecent: Integer read FMaxRecent write FMaxRecent;
  end;

// Default config file under XDG_CONFIG_HOME (or ~/.config): notepadlpp/config.json.
function DefaultConfigFile: string;

implementation

function DefaultConfigFile: string;
var base: string;
begin
  base := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if base = '' then
    base := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.config';
  Result := IncludeTrailingPathDelimiter(base) + 'notepadlpp' +
            PathDelim + 'config.json';
end;

constructor TConfig.Create(const AFilePath: string);
begin
  inherited Create;
  FRecentFiles := TStringList.Create;
  if AFilePath <> '' then
    FFilePath := AFilePath
  else
    FFilePath := DefaultConfigFile;
  SetDefaults;
end;

destructor TConfig.Destroy;
begin
  FRecentFiles.Free;
  inherited Destroy;
end;

procedure TConfig.SetDefaults;
begin
  FRecentFiles.Clear;
  FTheme := 'light';
  FMaxRecent := 10;
  FWindowState := Default(TWindowState); // all-zero, Valid=False
end;

procedure TConfig.TrimRecent;
begin
  while FRecentFiles.Count > FMaxRecent do
    FRecentFiles.Delete(FRecentFiles.Count - 1);
end;

procedure TConfig.AddRecentFile(const APath: string);
var idx: Integer;
begin
  if APath = '' then Exit;
  idx := FRecentFiles.IndexOf(APath);
  if idx >= 0 then
    FRecentFiles.Delete(idx);
  FRecentFiles.Insert(0, APath);
  TrimRecent;
end;

procedure TConfig.ClearRecent;
begin
  FRecentFiles.Clear;
end;

procedure TConfig.Load;
var
  raw: string;
  data: TJSONData;
  root, win: TJSONObject;
  arr: TJSONArray;
  i: Integer;
  fs: TFileStream;
  ss: TStringStream;
begin
  SetDefaults;
  if not FileExists(FFilePath) then Exit;

  // Read the whole file into a string.
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
        SetDefaults; // malformed JSON: keep defaults, never propagate
        Exit;
      end;
    end;

    if not (data is TJSONObject) then Exit;
    root := TJSONObject(data);

    FTheme := root.Get('theme', FTheme);
    FMaxRecent := root.Get('maxRecent', FMaxRecent);
    if FMaxRecent < 1 then FMaxRecent := 1;

    arr := root.Find('recentFiles', jtArray) as TJSONArray;
    if arr <> nil then
      for i := 0 to arr.Count - 1 do
        if arr.Items[i].JSONType = jtString then
          FRecentFiles.Add(arr.Items[i].AsString);
    TrimRecent;

    win := root.Find('window', jtObject) as TJSONObject;
    if win <> nil then
    begin
      FWindowState.Left := win.Get('left', 0);
      FWindowState.Top := win.Get('top', 0);
      FWindowState.Width := win.Get('width', 0);
      FWindowState.Height := win.Get('height', 0);
      FWindowState.Maximized := win.Get('maximized', False);
      FWindowState.Valid := win.Get('valid', False);
    end;
  finally
    data.Free;
  end;
end;

procedure TConfig.Save;
var
  root, win: TJSONObject;
  arr: TJSONArray;
  i: Integer;
  dir, text: string;
  fs: TFileStream;
begin
  root := TJSONObject.Create;
  try
    root.Add('theme', FTheme);
    root.Add('maxRecent', FMaxRecent);

    arr := TJSONArray.Create;
    for i := 0 to FRecentFiles.Count - 1 do
      arr.Add(FRecentFiles[i]);
    root.Add('recentFiles', arr);

    win := TJSONObject.Create;
    win.Add('left', FWindowState.Left);
    win.Add('top', FWindowState.Top);
    win.Add('width', FWindowState.Width);
    win.Add('height', FWindowState.Height);
    win.Add('maximized', FWindowState.Maximized);
    win.Add('valid', FWindowState.Valid);
    root.Add('window', win);

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
