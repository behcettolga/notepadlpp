// SPDX-License-Identifier: MPL-2.0
unit uTestEncoding;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  uEncoding;

type

  { TEncodingTest — explicit input->output byte vectors for encoding detection,
    decode/encode, byte-exact round-trips, and EOL detect/convert. }

  TEncodingTest = class(TTestCase)
  private
    function B(const A: array of Byte): TBytes;
    procedure AssertBytes(const Msg: string; const Expected: TBytes; const Got: TBytes);
  published
    procedure DetectUTF8NoBOM;
    procedure DetectUTF8BOM;
    procedure DetectUTF16LE;
    procedure DetectUTF16BE;
    procedure DetectCP1252;
    procedure RoundTripUTF8;
    procedure RoundTripUTF8BOM;
    procedure RoundTripUTF16LE;
    procedure RoundTripUTF16BE;
    procedure RoundTripCP1252;
    procedure DecodeCP1252Value;
    procedure EOLDetectLF;
    procedure EOLDetectCRLF;
    procedure EOLDetectCR;
    procedure EOLDetectNone;
    procedure EOLConvertRoundTrip;
  end;

implementation

// Test text "Aé" : 'A' = U+0041, 'é' = U+00E9.
//   UTF-8     : 41 C3 A9
//   UTF-16 LE : 41 00 E9 00   (+ BOM FF FE)
//   UTF-16 BE : 00 41 00 E9   (+ BOM FE FF)
//   CP-1252   : 41 E9

function TEncodingTest.B(const A: array of Byte): TBytes;
var i: Integer;
begin
  SetLength(Result, Length(A));
  for i := 0 to High(A) do Result[i] := A[i];
end;

procedure TEncodingTest.AssertBytes(const Msg: string; const Expected: TBytes; const Got: TBytes);
var i: Integer;
begin
  AssertEquals(Msg + ' (length)', Length(Expected), Length(Got));
  for i := 0 to High(Expected) do
    AssertEquals(Format('%s (byte %d)', [Msg, i]), Expected[i], Got[i]);
end;

procedure TEncodingTest.DetectUTF8NoBOM;
begin
  AssertTrue('utf8 no bom', EncodingService.DetectEncoding(B([$41, $C3, $A9])) = feUTF8);
end;

procedure TEncodingTest.DetectUTF8BOM;
begin
  AssertTrue('utf8 bom', EncodingService.DetectEncoding(B([$EF, $BB, $BF, $41])) = feUTF8BOM);
end;

procedure TEncodingTest.DetectUTF16LE;
begin
  AssertTrue('utf16le', EncodingService.DetectEncoding(B([$FF, $FE, $41, $00])) = feUTF16LE);
end;

procedure TEncodingTest.DetectUTF16BE;
begin
  AssertTrue('utf16be', EncodingService.DetectEncoding(B([$FE, $FF, $00, $41])) = feUTF16BE);
end;

procedure TEncodingTest.DetectCP1252;
begin
  // 41 E9 : E9 is not a valid UTF-8 lead/standalone -> falls back to CP-1252.
  AssertTrue('cp1252', EncodingService.DetectEncoding(B([$41, $E9])) = feCP1252);
end;

procedure TEncodingTest.RoundTripUTF8;
var src: TBytes;
begin
  src := B([$41, $C3, $A9]);
  AssertBytes('utf8 round-trip', src,
    EncodingService.EncodeFromUTF8(EncodingService.DecodeToUTF8(src, feUTF8), feUTF8));
end;

procedure TEncodingTest.RoundTripUTF8BOM;
var src: TBytes;
begin
  src := B([$EF, $BB, $BF, $41, $C3, $A9]);
  AssertBytes('utf8bom round-trip', src,
    EncodingService.EncodeFromUTF8(EncodingService.DecodeToUTF8(src, feUTF8BOM), feUTF8BOM));
end;

procedure TEncodingTest.RoundTripUTF16LE;
var src: TBytes;
begin
  src := B([$FF, $FE, $41, $00, $E9, $00]);
  AssertBytes('utf16le round-trip', src,
    EncodingService.EncodeFromUTF8(EncodingService.DecodeToUTF8(src, feUTF16LE), feUTF16LE));
end;

procedure TEncodingTest.RoundTripUTF16BE;
var src: TBytes;
begin
  src := B([$FE, $FF, $00, $41, $00, $E9]);
  AssertBytes('utf16be round-trip', src,
    EncodingService.EncodeFromUTF8(EncodingService.DecodeToUTF8(src, feUTF16BE), feUTF16BE));
end;

procedure TEncodingTest.RoundTripCP1252;
var src: TBytes;
begin
  src := B([$41, $E9]);
  AssertBytes('cp1252 round-trip', src,
    EncodingService.EncodeFromUTF8(EncodingService.DecodeToUTF8(src, feCP1252), feCP1252));
end;

procedure TEncodingTest.DecodeCP1252Value;
var s: string;
begin
  // CP-1252 41 E9 must decode to UTF-8 "Aé" = 41 C3 A9.
  s := EncodingService.DecodeToUTF8(B([$41, $E9]), feCP1252);
  AssertEquals('decoded length', 3, Length(s));
  AssertEquals('byte1', $41, Ord(s[1]));
  AssertEquals('byte2', $C3, Ord(s[2]));
  AssertEquals('byte3', $A9, Ord(s[3]));
end;

procedure TEncodingTest.EOLDetectLF;
var k: TLineEndingKind;
begin
  AssertTrue('found', EncodingService.DetectLineEnding('a'#10'b', k));
  AssertTrue('is LF', k = leLF);
end;

procedure TEncodingTest.EOLDetectCRLF;
var k: TLineEndingKind;
begin
  AssertTrue('found', EncodingService.DetectLineEnding('a'#13#10'b', k));
  AssertTrue('is CRLF', k = leCRLF);
end;

procedure TEncodingTest.EOLDetectCR;
var k: TLineEndingKind;
begin
  AssertTrue('found', EncodingService.DetectLineEnding('a'#13'b', k));
  AssertTrue('is CR', k = leCR);
end;

procedure TEncodingTest.EOLDetectNone;
var k: TLineEndingKind;
begin
  AssertFalse('no eol', EncodingService.DetectLineEnding('abc', k));
end;

procedure TEncodingTest.EOLConvertRoundTrip;
var crlf, lf: string;
begin
  crlf := 'one'#13#10'two'#13#10'three';
  lf := EncodingService.NormalizeToLF(crlf);
  AssertEquals('normalized', 'one'#10'two'#10'three', lf);
  AssertEquals('reapplied CRLF', crlf, EncodingService.ApplyLineEnding(lf, leCRLF));
  AssertEquals('reapplied CR', 'one'#13'two'#13'three', EncodingService.ApplyLineEnding(lf, leCR));
  AssertEquals('reapplied LF', lf, EncodingService.ApplyLineEnding(lf, leLF));
end;

initialization
  RegisterTest(TEncodingTest);

end.
