// SPDX-License-Identifier: MPL-2.0
unit uFileIO;

{$mode objfpc}{$H+}

{ File load/save for NotepadL++. UI-free core unit (ARCHITECTURE §4).

  Layered on uEncoding. The contract is byte-faithful:
    LoadTextFile  : raw bytes -> detect encoding -> BOM-free UTF-8 text (EOL left
                    intact as decoded) + detected dominant EOL for display.
    SaveTextFile  : UTF-8 text -> encode(encoding) -> raw bytes, written verbatim.
  Therefore load-then-save with the same encoding reproduces the original file
  byte-for-byte (M1 acceptance). EOL *conversion* is an explicit caller operation
  via uEncoding (the document layer decides when to normalize/re-apply). }

interface

uses
  Classes, SysUtils, uEncoding;

type
  TLoadResult = record
    TextUTF8: string;           // decoded, BOM stripped, EOL bytes preserved
    Encoding: TFileEncoding;
    LineEnding: TLineEndingKind; // dominant/first EOL found (leLF if none)
    HasLineEnding: Boolean;
  end;

function LoadBytes(const FileName: string): TBytes;
procedure SaveBytes(const FileName: string; const Bytes: TBytes);

function LoadTextFile(const FileName: string): TLoadResult;
procedure SaveTextFile(const FileName: string; const TextUTF8: string;
  Enc: TFileEncoding);

implementation

function LoadBytes(const FileName: string): TBytes;
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, fs.Size);
    if fs.Size > 0 then
      fs.ReadBuffer(Result[0], fs.Size);
  finally
    fs.Free;
  end;
end;

procedure SaveBytes(const FileName: string; const Bytes: TBytes);
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(FileName, fmCreate);
  try
    if Length(Bytes) > 0 then
      fs.WriteBuffer(Bytes[0], Length(Bytes));
  finally
    fs.Free;
  end;
end;

function LoadTextFile(const FileName: string): TLoadResult;
var
  bytes: TBytes;
  svc: IEncodingService;
begin
  svc := EncodingService;
  bytes := LoadBytes(FileName);
  Result.Encoding := svc.DetectEncoding(bytes);
  Result.TextUTF8 := svc.DecodeToUTF8(bytes, Result.Encoding);
  Result.HasLineEnding := svc.DetectLineEnding(Result.TextUTF8, Result.LineEnding);
end;

procedure SaveTextFile(const FileName: string; const TextUTF8: string;
  Enc: TFileEncoding);
begin
  SaveBytes(FileName, EncodingService.EncodeFromUTF8(TextUTF8, Enc));
end;

end.
