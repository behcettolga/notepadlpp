// SPDX-License-Identifier: MPL-2.0
unit uTestConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  uConfig, uSession;

type

  { TConfigTest — uConfig + uSession round-trip and edge vectors against temp files. }

  TConfigTest = class(TTestCase)
  private
    FDir: string;
    function CfgFile: string;
    function SesFile: string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure DefaultsWhenNoFile;
    procedure RoundTripBasic;
    procedure RecentMostRecentFirst;
    procedure RecentDeDuplicates;
    procedure RecentCappedAtMax;
    procedure WindowStateRoundTrip;
    procedure MalformedResetsToDefaults;
    procedure SessionRoundTrip;
    procedure SessionActiveIndexClamped;
    procedure SessionSkipsEmptyPaths;
    procedure SessionMalformedIsEmpty;
  end;

implementation

function TConfigTest.CfgFile: string;
begin
  Result := FDir + PathDelim + 'config.json';
end;

function TConfigTest.SesFile: string;
begin
  Result := FDir + PathDelim + 'session.json';
end;

procedure TConfigTest.SetUp;
begin
  FDir := GetTempDir(False) + 'nlpp_cfg_' + IntToStr(PtrUInt(Self));
  ForceDirectories(FDir);
end;

procedure TConfigTest.TearDown;
begin
  if FileExists(CfgFile) then DeleteFile(CfgFile);
  if FileExists(SesFile) then DeleteFile(SesFile);
  if DirectoryExists(FDir) then RemoveDir(FDir);
end;

procedure TConfigTest.DefaultsWhenNoFile;
var c: TConfig;
begin
  c := TConfig.Create(CfgFile);
  try
    c.Load; // file does not exist
    AssertEquals('default theme', 'light', c.Theme);
    AssertEquals('default maxRecent', 10, c.MaxRecent);
    AssertEquals('no recents', 0, c.RecentFiles.Count);
    AssertFalse('window not valid', c.WindowState.Valid);
  finally c.Free; end;
end;

procedure TConfigTest.RoundTripBasic;
var c: TConfig;
begin
  c := TConfig.Create(CfgFile);
  try
    c.Theme := 'dark';
    c.AddRecentFile('/home/u/a.txt');
    c.Save;
  finally c.Free; end;

  c := TConfig.Create(CfgFile);
  try
    c.Load;
    AssertEquals('theme persisted', 'dark', c.Theme);
    AssertEquals('recent count', 1, c.RecentFiles.Count);
    AssertEquals('recent value', '/home/u/a.txt', c.RecentFiles[0]);
  finally c.Free; end;
end;

procedure TConfigTest.RecentMostRecentFirst;
var c: TConfig;
begin
  c := TConfig.Create(CfgFile);
  try
    c.AddRecentFile('/a');
    c.AddRecentFile('/b');
    c.AddRecentFile('/c');
    AssertEquals('newest first', '/c', c.RecentFiles[0]);
    AssertEquals('oldest last', '/a', c.RecentFiles[2]);
  finally c.Free; end;
end;

procedure TConfigTest.RecentDeDuplicates;
var c: TConfig;
begin
  c := TConfig.Create(CfgFile);
  try
    c.AddRecentFile('/a');
    c.AddRecentFile('/b');
    c.AddRecentFile('/a'); // re-add moves to front, no dup
    AssertEquals('count after re-add', 2, c.RecentFiles.Count);
    AssertEquals('re-added is first', '/a', c.RecentFiles[0]);
  finally c.Free; end;
end;

procedure TConfigTest.RecentCappedAtMax;
var c: TConfig; i: Integer;
begin
  c := TConfig.Create(CfgFile);
  try
    c.MaxRecent := 3;
    for i := 1 to 6 do
      c.AddRecentFile('/f' + IntToStr(i));
    AssertEquals('capped', 3, c.RecentFiles.Count);
    AssertEquals('keeps newest', '/f6', c.RecentFiles[0]);
    AssertEquals('drops oldest', '/f4', c.RecentFiles[2]);
  finally c.Free; end;
end;

procedure TConfigTest.WindowStateRoundTrip;
var c: TConfig; ws: TWindowState;
begin
  c := TConfig.Create(CfgFile);
  try
    ws.Left := 120; ws.Top := 60; ws.Width := 1024; ws.Height := 768;
    ws.Maximized := True; ws.Valid := True;
    c.WindowState := ws;
    c.Save;
  finally c.Free; end;

  c := TConfig.Create(CfgFile);
  try
    c.Load;
    AssertTrue('valid', c.WindowState.Valid);
    AssertEquals('left', 120, c.WindowState.Left);
    AssertEquals('width', 1024, c.WindowState.Width);
    AssertEquals('height', 768, c.WindowState.Height);
    AssertTrue('maximized', c.WindowState.Maximized);
  finally c.Free; end;
end;

procedure TConfigTest.MalformedResetsToDefaults;
var c: TConfig; sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Text := '{ this is : not json ]';
    sl.SaveToFile(CfgFile);
  finally sl.Free; end;

  c := TConfig.Create(CfgFile);
  try
    c.Load; // must not raise
    AssertEquals('fell back to default theme', 'light', c.Theme);
    AssertEquals('no recents', 0, c.RecentFiles.Count);
  finally c.Free; end;
end;

procedure TConfigTest.SessionRoundTrip;
var s: TSession;
begin
  s := TSession.Create(SesFile);
  try
    s.AddFile('/x.pas', 10, 4);
    s.AddFile('/y.txt', 0, 0);
    s.ActiveIndex := 1;
    s.Save;
  finally s.Free; end;

  s := TSession.Create(SesFile);
  try
    s.Load;
    AssertEquals('count', 2, s.Count);
    AssertEquals('entry0 path', '/x.pas', s.Entry(0).FilePath);
    AssertEquals('entry0 line', 10, s.Entry(0).CaretLine);
    AssertEquals('entry0 col', 4, s.Entry(0).CaretCol);
    AssertEquals('active', 1, s.ActiveIndex);
  finally s.Free; end;
end;

procedure TConfigTest.SessionActiveIndexClamped;
var s: TSession; sl: TStringList;
begin
  // active index points past the end -> clamp to last entry
  sl := TStringList.Create;
  try
    sl.Text := '{"activeIndex":9,"files":[{"path":"/only","line":0,"col":0}]}';
    sl.SaveToFile(SesFile);
  finally sl.Free; end;

  s := TSession.Create(SesFile);
  try
    s.Load;
    AssertEquals('one file', 1, s.Count);
    AssertEquals('clamped active', 0, s.ActiveIndex);
  finally s.Free; end;
end;

procedure TConfigTest.SessionSkipsEmptyPaths;
var s: TSession; sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Text := '{"activeIndex":0,"files":[{"path":""},{"path":"/real"}]}';
    sl.SaveToFile(SesFile);
  finally sl.Free; end;

  s := TSession.Create(SesFile);
  try
    s.Load;
    AssertEquals('only the real path', 1, s.Count);
    AssertEquals('path', '/real', s.Entry(0).FilePath);
  finally s.Free; end;
end;

procedure TConfigTest.SessionMalformedIsEmpty;
var s: TSession; sl: TStringList;
begin
  sl := TStringList.Create;
  try
    sl.Text := 'not json at all';
    sl.SaveToFile(SesFile);
  finally sl.Free; end;

  s := TSession.Create(SesFile);
  try
    s.Load;
    AssertEquals('empty session', 0, s.Count);
  finally s.Free; end;
end;

initialization
  RegisterTest(TConfigTest);

end.
