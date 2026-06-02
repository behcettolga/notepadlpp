// SPDX-License-Identifier: MPL-2.0
unit uTestFindInFiles;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  uSearchEngine, uSearchResults, uFindInFiles, uFileIO, uEncoding;

type

  { TFindInFilesTest — builds a fixture tree, searches it, asserts the hit set,
    mask filtering, and recursion behaviour. }

  TFindInFilesTest = class(TTestCase)
  private
    FRoot: string;
    procedure WriteFile(const RelPath, Content: string);
    function Params(const Pat, Mask: string; Recursive: Boolean): TFindInFilesParams;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure MaskFiltersAndRecursion;
    procedure NonRecursiveSkipsSubdir;
    procedure AllFilesWhenNoMask;
    procedure HitLineAndColumn;
    procedure ResultsModelFileCount;
  end;

implementation

procedure RemoveTree(const Dir: string);
var info: TSearchRec; full: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, info) = 0 then
  begin
    repeat
      if (info.Name = '.') or (info.Name = '..') then Continue;
      full := IncludeTrailingPathDelimiter(Dir) + info.Name;
      if (info.Attr and faDirectory) <> 0 then RemoveTree(full)
      else DeleteFile(full);
    until SysUtils.FindNext(info) <> 0;
    SysUtils.FindClose(info);
  end;
  RemoveDir(Dir);
end;

procedure TFindInFilesTest.WriteFile(const RelPath, Content: string);
var full: string;
begin
  full := IncludeTrailingPathDelimiter(FRoot) + RelPath;
  ForceDirectories(ExtractFileDir(full));
  SaveTextFile(full, Content, feUTF8);
end;

function TFindInFilesTest.Params(const Pat, Mask: string;
  Recursive: Boolean): TFindInFilesParams;
begin
  Result.Root := FRoot;
  Result.Masks := Mask;
  Result.Recursive := Recursive;
  Result.Pattern := Pat;
  Result.Options := [];
end;

procedure TFindInFilesTest.SetUp;
begin
  FRoot := IncludeTrailingPathDelimiter(GetTempDir) + 'nlpp_fif_' + IntToStr(GetProcessID);
  ForceDirectories(FRoot);
  WriteFile('a.log', 'error here'#10'ok'#10'error again');
  WriteFile('b.txt', 'error in txt');
  WriteFile('sub' + PathDelim + 'c.log', 'nested error');
end;

procedure TFindInFilesTest.TearDown;
begin
  RemoveTree(FRoot);
end;

procedure TFindInFilesTest.MaskFiltersAndRecursion;
var res: TSearchResults; n: Integer;
begin
  res := TSearchResults.Create;
  try
    n := SearchInTree(Params('error', '*.log', True), res);
    // a.log lines 1 & 3, sub/c.log line 1 = 3 hits; b.txt excluded by mask
    AssertEquals('hits', 3, n);
  finally res.Free; end;
end;

procedure TFindInFilesTest.NonRecursiveSkipsSubdir;
var res: TSearchResults;
begin
  res := TSearchResults.Create;
  try
    SearchInTree(Params('error', '*.log', False), res);
    AssertEquals('only top-level a.log (2 hits)', 2, res.Count);
  finally res.Free; end;
end;

procedure TFindInFilesTest.AllFilesWhenNoMask;
var res: TSearchResults;
begin
  res := TSearchResults.Create;
  try
    SearchInTree(Params('error', '', True), res);
    // a.log(2) + b.txt(1) + sub/c.log(1) = 4
    AssertEquals('all files', 4, res.Count);
  finally res.Free; end;
end;

procedure TFindInFilesTest.HitLineAndColumn;
var res: TSearchResults; i: Integer; found: Boolean;
begin
  res := TSearchResults.Create;
  try
    SearchInTree(Params('again', '*.log', True), res);
    AssertEquals('one hit for "again"', 1, res.Count);
    found := False;
    for i := 0 to res.Count - 1 do
      if Pos('a.log', res[i].FileName) > 0 then
      begin
        AssertEquals('line', 3, res[i].Line);
        AssertEquals('col', 7, res[i].Col); // "error again" -> 'again' at col 7
        AssertEquals('linetext', 'error again', res[i].LineText);
        found := True;
      end;
    AssertTrue('hit located', found);
  finally res.Free; end;
end;

procedure TFindInFilesTest.ResultsModelFileCount;
var res: TSearchResults;
begin
  res := TSearchResults.Create;
  try
    SearchInTree(Params('error', '*.log', True), res);
    AssertEquals('distinct files', 2, res.FileCount); // a.log + c.log
  finally res.Free; end;
end;

initialization
  RegisterTest(TFindInFilesTest);

end.
