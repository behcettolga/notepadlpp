// SPDX-License-Identifier: MPL-2.0
unit uTestDocument;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  uEncoding, uFileIO, uDocument, uDocumentManager;

type

  { TDocumentTest }

  TDocumentTest = class(TTestCase)
  private
    FDir: string;
    function P(const Name: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure NewIsUntitledClean;
    procedure SetTextMarksModified;
    procedure SaveLoadPreservesContent;
    procedure SaveAppliesLineEnding;
    procedure ChangingEncodingMarksModified;
    procedure ReloadDiscardsChanges;
  end;

  { TDocumentManagerTest }

  TDocumentManagerTest = class(TTestCase)
  private
    FDir: string;
    function P(const Name: string): string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure NewDocumentBecomesActive;
    procedure OpenSameFileTwiceReuses;
    procedure CloseAdjustsActive;
    procedure HasModifiedReflectsDocs;
  end;

implementation

procedure WipeDir(const Dir: string);
var info: TSearchRec;
begin
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, info) = 0 then
  begin
    repeat
      if (info.Name <> '.') and (info.Name <> '..') then
        DeleteFile(IncludeTrailingPathDelimiter(Dir) + info.Name);
    until FindNext(info) <> 0;
    FindClose(info);
  end;
  RemoveDir(Dir);
end;

{ TDocumentTest }

function TDocumentTest.P(const Name: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDir) + Name;
end;

procedure TDocumentTest.SetUp;
begin
  FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'nlpp_doc_' + IntToStr(GetProcessID);
  ForceDirectories(FDir);
end;

procedure TDocumentTest.TearDown;
begin
  WipeDir(FDir);
end;

procedure TDocumentTest.NewIsUntitledClean;
var d: TDocument;
begin
  d := TDocument.Create;
  try
    AssertTrue('untitled', d.Untitled);
    AssertFalse('not modified', d.Modified);
    AssertEquals('display name', 'untitled', d.DisplayName);
    AssertEquals('empty', '', d.TextLF);
  finally
    d.Free;
  end;
end;

procedure TDocumentTest.SetTextMarksModified;
var d: TDocument;
begin
  d := TDocument.Create;
  try
    d.TextLF := 'hello';
    AssertTrue('modified after edit', d.Modified);
  finally
    d.Free;
  end;
end;

procedure TDocumentTest.SaveLoadPreservesContent;
var d: TDocument;
begin
  d := TDocument.Create;
  try
    d.TextLF := 'line1'#10'line2';
    d.Encoding := feUTF8;
    d.LineEnding := leLF;
    d.SaveToFile(P('a.txt'));
    AssertFalse('clean after save', d.Modified);
    AssertEquals('path adopted', P('a.txt'), d.FilePath);
  finally
    d.Free;
  end;

  d := TDocument.Create;
  try
    d.LoadFromFile(P('a.txt'));
    AssertEquals('content', 'line1'#10'line2', d.TextLF);
    AssertTrue('encoding', d.Encoding = feUTF8);
    AssertFalse('clean after load', d.Modified);
  finally
    d.Free;
  end;
end;

procedure TDocumentTest.SaveAppliesLineEnding;
var d: TDocument; raw: TBytes;
begin
  d := TDocument.Create;
  try
    d.TextLF := 'a'#10'b';
    d.LineEnding := leCRLF;
    d.SaveToFile(P('crlf.txt'));
  finally
    d.Free;
  end;
  raw := LoadBytes(P('crlf.txt'));
  // "a\r\nb" = 61 0D 0A 62
  AssertEquals('len', 4, Length(raw));
  AssertEquals('a', $61, raw[0]);
  AssertEquals('CR', $0D, raw[1]);
  AssertEquals('LF', $0A, raw[2]);
  AssertEquals('b', $62, raw[3]);
end;

procedure TDocumentTest.ChangingEncodingMarksModified;
var d: TDocument;
begin
  d := TDocument.Create;
  try
    d.TextLF := 'x';
    d.SaveToFile(P('e.txt'));
    AssertFalse('clean', d.Modified);
    d.Encoding := feUTF16LE;
    AssertTrue('modified after encoding change', d.Modified);
  finally
    d.Free;
  end;
end;

procedure TDocumentTest.ReloadDiscardsChanges;
var d: TDocument;
begin
  d := TDocument.Create;
  try
    d.TextLF := 'saved';
    d.SaveToFile(P('r.txt'));
    d.TextLF := 'unsaved edit';
    AssertTrue('dirty', d.Modified);
    d.Reload;
    AssertEquals('restored', 'saved', d.TextLF);
    AssertFalse('clean after reload', d.Modified);
  finally
    d.Free;
  end;
end;

{ TDocumentManagerTest }

function TDocumentManagerTest.P(const Name: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDir) + Name;
end;

procedure TDocumentManagerTest.SetUp;
begin
  FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'nlpp_dm_' + IntToStr(GetProcessID);
  ForceDirectories(FDir);
end;

procedure TDocumentManagerTest.TearDown;
begin
  WipeDir(FDir);
end;

procedure TDocumentManagerTest.NewDocumentBecomesActive;
var m: TDocumentManager;
begin
  m := TDocumentManager.Create;
  try
    m.NewDocument;
    m.NewDocument;
    AssertEquals('count', 2, m.Count);
    AssertEquals('active index', 1, m.ActiveIndex);
    AssertTrue('active is last', m.Active = m.Docs[1]);
  finally
    m.Free;
  end;
end;

procedure TDocumentManagerTest.OpenSameFileTwiceReuses;
var m: TDocumentManager; d1, d2: TDocument;
begin
  SaveTextFile(P('shared.txt'), 'data', feUTF8);
  m := TDocumentManager.Create;
  try
    d1 := m.OpenFile(P('shared.txt'));
    d2 := m.OpenFile(P('shared.txt'));
    AssertEquals('no duplicate', 1, m.Count);
    AssertTrue('same instance', d1 = d2);
  finally
    m.Free;
  end;
end;

procedure TDocumentManagerTest.CloseAdjustsActive;
var m: TDocumentManager;
begin
  m := TDocumentManager.Create;
  try
    m.NewDocument;
    m.NewDocument;
    m.NewDocument;
    AssertEquals('active', 2, m.ActiveIndex);
    m.Close(2);
    AssertEquals('count', 2, m.Count);
    AssertEquals('active clamped', 1, m.ActiveIndex);
  finally
    m.Free;
  end;
end;

procedure TDocumentManagerTest.HasModifiedReflectsDocs;
var m: TDocumentManager; d: TDocument;
begin
  m := TDocumentManager.Create;
  try
    d := m.NewDocument;
    AssertFalse('clean initially', m.HasModified);
    d.TextLF := 'edit';
    AssertTrue('has modified', m.HasModified);
  finally
    m.Free;
  end;
end;

initialization
  RegisterTest(TDocumentTest);
  RegisterTest(TDocumentManagerTest);

end.
