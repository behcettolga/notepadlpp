// SPDX-License-Identifier: MPL-2.0
unit uTestFileIO;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  uEncoding, uFileIO;

type

  { TFileIOTest — writes real fixture files to a temp dir, loads them, re-saves
    with the detected encoding, and asserts the bytes are reproduced exactly. }

  TFileIOTest = class(TTestCase)
  private
    FDir: string;
    function MakeBytes(const A: array of Byte): TBytes;
    function FixturePath(const Name: string): string;
    procedure RoundTrip(const Name: string; const Raw: array of Byte;
      ExpectEnc: TFileEncoding);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure RoundTripUTF8;
    procedure RoundTripUTF8BOM;
    procedure RoundTripUTF16LE;
    procedure RoundTripUTF16BE;
    procedure RoundTripCP1252;
    procedure DetectsEolCRLF;
    procedure SaveThenReloadText;
  end;

implementation

function TFileIOTest.MakeBytes(const A: array of Byte): TBytes;
var i: Integer;
begin
  SetLength(Result, Length(A));
  for i := 0 to High(A) do Result[i] := A[i];
end;

function TFileIOTest.FixturePath(const Name: string): string;
begin
  Result := IncludeTrailingPathDelimiter(FDir) + Name;
end;

procedure TFileIOTest.SetUp;
begin
  FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'nlpp_test_' + IntToStr(GetProcessID);
  ForceDirectories(FDir);
end;

procedure TFileIOTest.TearDown;
var
  info: TSearchRec;
begin
  if FindFirst(IncludeTrailingPathDelimiter(FDir) + '*', faAnyFile, info) = 0 then
  begin
    repeat
      if (info.Name <> '.') and (info.Name <> '..') then
        DeleteFile(IncludeTrailingPathDelimiter(FDir) + info.Name);
    until FindNext(info) <> 0;
    FindClose(info);
  end;
  RemoveDir(FDir);
end;

procedure TFileIOTest.RoundTrip(const Name: string; const Raw: array of Byte;
  ExpectEnc: TFileEncoding);
var
  orig, reloaded: TBytes;
  path: string;
  lr: TLoadResult;
  i: Integer;
begin
  orig := MakeBytes(Raw);
  path := FixturePath(Name);
  SaveBytes(path, orig);

  lr := LoadTextFile(path);
  AssertTrue(Name + ': detected encoding', lr.Encoding = ExpectEnc);

  // Re-save with the detected encoding and compare bytes exactly.
  SaveTextFile(path, lr.TextUTF8, lr.Encoding);
  reloaded := LoadBytes(path);

  AssertEquals(Name + ': byte length', Length(orig), Length(reloaded));
  for i := 0 to High(orig) do
    AssertEquals(Format('%s: byte %d', [Name, i]), orig[i], reloaded[i]);
end;

procedure TFileIOTest.RoundTripUTF8;
begin
  // "Aé\n"
  RoundTrip('utf8.txt', [$41, $C3, $A9, $0A], feUTF8);
end;

procedure TFileIOTest.RoundTripUTF8BOM;
begin
  RoundTrip('utf8bom.txt', [$EF, $BB, $BF, $41, $C3, $A9, $0A], feUTF8BOM);
end;

procedure TFileIOTest.RoundTripUTF16LE;
begin
  // BOM + "Aé" + LF
  RoundTrip('utf16le.txt', [$FF, $FE, $41, $00, $E9, $00, $0A, $00], feUTF16LE);
end;

procedure TFileIOTest.RoundTripUTF16BE;
begin
  RoundTrip('utf16be.txt', [$FE, $FF, $00, $41, $00, $E9, $00, $0A], feUTF16BE);
end;

procedure TFileIOTest.RoundTripCP1252;
begin
  // "Aé" : 41 E9 (E9 invalid as UTF-8 -> CP1252)
  RoundTrip('cp1252.txt', [$41, $E9, $0A], feCP1252);
end;

procedure TFileIOTest.DetectsEolCRLF;
var
  path: string;
  lr: TLoadResult;
begin
  path := FixturePath('crlf.txt');
  SaveBytes(path, MakeBytes([$61, $0D, $0A, $62])); // "a\r\nb"
  lr := LoadTextFile(path);
  AssertTrue('found eol', lr.HasLineEnding);
  AssertTrue('is CRLF', lr.LineEnding = leCRLF);
end;

procedure TFileIOTest.SaveThenReloadText;
var
  path: string;
  lr: TLoadResult;
begin
  path := FixturePath('text.txt');
  SaveTextFile(path, 'hello'#10'world', feUTF8);
  lr := LoadTextFile(path);
  AssertEquals('text preserved', 'hello'#10'world', lr.TextUTF8);
  AssertTrue('utf8', lr.Encoding = feUTF8);
end;

initialization
  RegisterTest(TFileIOTest);

end.
