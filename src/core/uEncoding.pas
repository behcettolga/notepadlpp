// SPDX-License-Identifier: MPL-2.0
unit uEncoding;

{$mode objfpc}{$H+}

{ Encoding + line-ending detection and conversion for NotepadL++.

  UI-free core unit (ARCHITECTURE §4). The encoding logic lives behind the
  IEncodingService interface so more encodings can be added in one place later
  (kickoff pre-resolved decision).

  Phase 1 encodings: UTF-8 (with/without BOM), UTF-16 LE, UTF-16 BE, CP-1252.

  Design for byte-exact round-trip (M1 acceptance):
    load:  raw bytes --detect--> encoding id; --decode--> BOM-free UTF-8 text
    save:  UTF-8 text --encode(encoding id)--> raw bytes (BOM re-emitted here)
  Because the BOM presence is captured in the encoding id and re-emitted
  deterministically, decode->encode reproduces the original bytes exactly for
  all BMP content. (UTF-16 here is UCS-2 via EncConv: characters outside the BMP
  are an upstream limitation we wrap, not fix.) }

interface

uses
  Classes, SysUtils;

type
  TFileEncoding = (
    feUTF8,      // UTF-8, no BOM
    feUTF8BOM,   // UTF-8 with EF BB BF
    feUTF16LE,   // UTF-16 little-endian, FF FE BOM
    feUTF16BE,   // UTF-16 big-endian, FE FF BOM
    feCP1252     // Windows-1252 (8-bit fallback)
  );

  TLineEndingKind = (leLF, leCRLF, leCR);

  { IEncodingService — the seam for encoding/EOL handling. }
  IEncodingService = interface
    ['{4F3A1C20-0B7E-4D8A-9C11-9A2E5D6F7A01}']
    function DetectEncoding(const Bytes: TBytes): TFileEncoding;
    function DecodeToUTF8(const Bytes: TBytes; Enc: TFileEncoding): string;
    function EncodeFromUTF8(const TextUTF8: string; Enc: TFileEncoding): TBytes;
    function EncodingName(Enc: TFileEncoding): string;
    // EOL: returns False when no line ending is present (Kind defaults to leLF).
    function DetectLineEnding(const TextUTF8: string; out Kind: TLineEndingKind): Boolean;
    function NormalizeToLF(const TextUTF8: string): string;
    function ApplyLineEnding(const TextUTF8LF: string; Kind: TLineEndingKind): string;
  end;

function EncodingService: IEncodingService;

function EncodingName(Enc: TFileEncoding): string;
function LineEndingKindName(Kind: TLineEndingKind): string;
function LineEndingBytes(Kind: TLineEndingKind): string;

implementation

uses
  encconv;

const
  UTF8_BOM: array[0..2] of Byte = ($EF, $BB, $BF);

{ ---- byte helpers (CP_NONE preserves bytes through encconv's string params) ---- }

function BytesToRaw(const B: TBytes): RawByteString;
begin
  SetLength(Result, Length(B));
  if Length(B) > 0 then
    Move(B[0], Result[1], Length(B));
end;

function RawToBytes(const S: RawByteString): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

{ Validate that the bytes form well-formed UTF-8 (used to disambiguate UTF-8 vs CP-1252
  when there is no BOM). }
function IsValidUTF8(const B: TBytes): Boolean;
var
  i, n, len: Integer;
  c: Byte;
begin
  i := 0;
  len := Length(B);
  while i < len do
  begin
    c := B[i];
    if c < $80 then
      n := 0
    else if (c and $E0) = $C0 then
      n := 1
    else if (c and $F0) = $E0 then
      n := 2
    else if (c and $F8) = $F0 then
      n := 3
    else
      Exit(False);
    if i + n >= len then
      Exit(False);
    while n > 0 do
    begin
      Inc(i);
      if (B[i] and $C0) <> $80 then
        Exit(False);
      Dec(n);
    end;
    Inc(i);
  end;
  Result := True;
end;

{ ---- IEncodingService implementation ---- }

type
  TEncodingService = class(TInterfacedObject, IEncodingService)
  public
    function DetectEncoding(const Bytes: TBytes): TFileEncoding;
    function DecodeToUTF8(const Bytes: TBytes; Enc: TFileEncoding): string;
    function EncodeFromUTF8(const TextUTF8: string; Enc: TFileEncoding): TBytes;
    function EncodingName(Enc: TFileEncoding): string;
    function DetectLineEnding(const TextUTF8: string; out Kind: TLineEndingKind): Boolean;
    function NormalizeToLF(const TextUTF8: string): string;
    function ApplyLineEnding(const TextUTF8LF: string; Kind: TLineEndingKind): string;
  end;

function TEncodingService.DetectEncoding(const Bytes: TBytes): TFileEncoding;
var
  n: Integer;
begin
  n := Length(Bytes);
  if (n >= 3) and (Bytes[0] = $EF) and (Bytes[1] = $BB) and (Bytes[2] = $BF) then
    Exit(feUTF8BOM);
  if (n >= 2) and (Bytes[0] = $FF) and (Bytes[1] = $FE) then
    Exit(feUTF16LE);
  if (n >= 2) and (Bytes[0] = $FE) and (Bytes[1] = $FF) then
    Exit(feUTF16BE);
  if IsValidUTF8(Bytes) then
    Exit(feUTF8);
  Result := feCP1252;
end;

function TEncodingService.DecodeToUTF8(const Bytes: TBytes; Enc: TFileEncoding): string;
var
  raw: RawByteString;
begin
  case Enc of
    feUTF8:
      raw := BytesToRaw(Bytes);
    feUTF8BOM:
      raw := BytesToRaw(Copy(Bytes, 3, Length(Bytes) - 3));  // strip EF BB BF
    feUTF16LE:
      raw := EncConvertToUTF8(BytesToRaw(Copy(Bytes, 2, Length(Bytes) - 2)), eidUCS2LE);  // strip FF FE
    feUTF16BE:
      raw := EncConvertToUTF8(BytesToRaw(Copy(Bytes, 2, Length(Bytes) - 2)), eidUCS2BE);  // strip FE FF
    feCP1252:
      raw := EncConvertToUTF8(BytesToRaw(Bytes), eidCP1252);
  else
    raw := BytesToRaw(Bytes);
  end;
  Result := raw;  // raw holds UTF-8 bytes
end;

function TEncodingService.EncodeFromUTF8(const TextUTF8: string; Enc: TFileEncoding): TBytes;
var
  body, raw: RawByteString;
begin
  raw := TextUTF8;  // treat UTF-8 text bytes as raw
  case Enc of
    feUTF8:
      Exit(RawToBytes(raw));
    feUTF8BOM:
      Exit(RawToBytes(RawByteString(#$EF#$BB#$BF) + raw));
    feUTF16LE:
      begin
        body := EncConvertFromUTF8(raw, eidUCS2LE);
        Exit(RawToBytes(RawByteString(#$FF#$FE) + body));
      end;
    feUTF16BE:
      begin
        body := EncConvertFromUTF8(raw, eidUCS2BE);
        Exit(RawToBytes(RawByteString(#$FE#$FF) + body));
      end;
    feCP1252:
      Exit(RawToBytes(EncConvertFromUTF8(raw, eidCP1252)));
  end;
  Result := RawToBytes(raw);
end;

function TEncodingService.EncodingName(Enc: TFileEncoding): string;
begin
  Result := uEncoding.EncodingName(Enc);
end;

function TEncodingService.DetectLineEnding(const TextUTF8: string;
  out Kind: TLineEndingKind): Boolean;
var
  i, len: Integer;
begin
  Kind := leLF;
  len := Length(TextUTF8);
  i := 1;
  while i <= len do
  begin
    if TextUTF8[i] = #13 then
    begin
      if (i < len) and (TextUTF8[i + 1] = #10) then
        Kind := leCRLF
      else
        Kind := leCR;
      Exit(True);
    end
    else if TextUTF8[i] = #10 then
    begin
      Kind := leLF;
      Exit(True);
    end;
    Inc(i);
  end;
  Result := False;
end;

function TEncodingService.NormalizeToLF(const TextUTF8: string): string;
begin
  // CRLF first, then lone CR -> LF
  Result := StringReplace(TextUTF8, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
end;

function TEncodingService.ApplyLineEnding(const TextUTF8LF: string;
  Kind: TLineEndingKind): string;
begin
  case Kind of
    leLF:   Result := TextUTF8LF;
    leCRLF: Result := StringReplace(TextUTF8LF, #10, #13#10, [rfReplaceAll]);
    leCR:   Result := StringReplace(TextUTF8LF, #10, #13, [rfReplaceAll]);
  else
    Result := TextUTF8LF;
  end;
end;

{ ---- unit-level helpers + singleton ---- }

function EncodingName(Enc: TFileEncoding): string;
begin
  case Enc of
    feUTF8:    Result := 'UTF-8';
    feUTF8BOM: Result := 'UTF-8 BOM';
    feUTF16LE: Result := 'UTF-16 LE';
    feUTF16BE: Result := 'UTF-16 BE';
    feCP1252:  Result := 'Windows-1252';
  else
    Result := '?';
  end;
end;

function LineEndingKindName(Kind: TLineEndingKind): string;
begin
  case Kind of
    leLF:   Result := 'LF';
    leCRLF: Result := 'CRLF';
    leCR:   Result := 'CR';
  else
    Result := '?';
  end;
end;

function LineEndingBytes(Kind: TLineEndingKind): string;
begin
  case Kind of
    leLF:   Result := #10;
    leCRLF: Result := #13#10;
    leCR:   Result := #13;
  else
    Result := #10;
  end;
end;

var
  FService: IEncodingService = nil;

function EncodingService: IEncodingService;
begin
  if FService = nil then
    FService := TEncodingService.Create;
  Result := FService;
end;

end.
