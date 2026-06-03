// SPDX-License-Identifier: MPL-2.0
unit uConverters;

{$mode objfpc}{$H+}

{ Developer converters. UI-FREE core (ARCHITECTURE §4), tested against known
  vectors (RFC 4648 Base64, NIST SHA-256). Base64 via fcl-base; MD5/SHA-1 via FPC
  RTL; SHA-256 via our uSHA256; UUID via CreateGUID; numeric base done here. }

interface

uses
  Classes, SysUtils, base64, md5, sha1, uSHA256;

{ Base64 }
function Base64Encode(const S: RawByteString): string;
function Base64Decode(const S: string): RawByteString;

{ URL percent-encoding (RFC 3986 unreserved kept) }
function UrlEncode(const S: string): string;
function UrlDecode(const S: string): string;

{ Hashes (lowercase hex of the UTF-8/byte content) }
function HashMD5(const S: RawByteString): string;
function HashSHA1(const S: RawByteString): string;
function HashSHA256(const S: RawByteString): string;

{ UUID v4-style, lowercase, no braces }
function NewUuid: string;

{ Numeric base conversion. FromBase/ToBase in 2..36. Returns '' on invalid input. }
function ConvertBase(const ANumber: string; AFromBase, AToBase: Integer): string;

implementation

function Base64Encode(const S: RawByteString): string;
begin
  Result := EncodeStringBase64(S);
end;

function Base64Decode(const S: string): RawByteString;
begin
  Result := DecodeStringBase64(S);
end;

function UrlEncode(const S: string): string;
var
  i: Integer;
  ch: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    ch := S[i];
    if (ch in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~']) then
      Result := Result + ch
    else
      Result := Result + '%' + IntToHex(Ord(ch), 2);
  end;
end;

function UrlDecode(const S: string): string;
var
  i, code: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(S) do
  begin
    if (S[i] = '%') and (i + 2 <= Length(S)) and
       TryStrToInt('$' + Copy(S, i + 1, 2), code) then
    begin
      Result := Result + Chr(code);
      Inc(i, 3);
    end
    else if S[i] = '+' then
    begin
      Result := Result + ' ';
      Inc(i);
    end
    else
    begin
      Result := Result + S[i];
      Inc(i);
    end;
  end;
end;

function HashMD5(const S: RawByteString): string;
begin
  Result := LowerCase(MD5Print(MD5String(S)));
end;

function HashSHA1(const S: RawByteString): string;
begin
  Result := LowerCase(SHA1Print(SHA1String(S)));
end;

function HashSHA256(const S: RawByteString): string;
begin
  Result := SHA256OfString(S);
end;

function NewUuid: string;
var
  g: TGUID;
  s: string;
begin
  CreateGUID(g);
  s := GUIDToString(g); // {XXXXXXXX-XXXX-...}
  s := StringReplace(s, '{', '', []);
  s := StringReplace(s, '}', '', []);
  Result := LowerCase(s);
end;

function ConvertBase(const ANumber: string; AFromBase, AToBase: Integer): string;
const
  Digits = '0123456789abcdefghijklmnopqrstuvwxyz';
var
  i, d: Integer;
  value: QWord;
  s, t: string;
  neg: Boolean;
begin
  Result := '';
  if (AFromBase < 2) or (AFromBase > 36) or (AToBase < 2) or (AToBase > 36) then Exit;
  s := LowerCase(Trim(ANumber));
  if s = '' then Exit;
  neg := (s[1] = '-');
  if neg then Delete(s, 1, 1);
  if s = '' then Exit;

  // parse to value
  value := 0;
  for i := 1 to Length(s) do
  begin
    d := Pos(s[i], Digits) - 1;
    if (d < 0) or (d >= AFromBase) then Exit; // invalid digit for base
    value := value * QWord(AFromBase) + QWord(d);
  end;

  // emit in target base
  if value = 0 then
    t := '0'
  else
  begin
    t := '';
    while value > 0 do
    begin
      t := Digits[(value mod QWord(AToBase)) + 1] + t;
      value := value div QWord(AToBase);
    end;
  end;
  if neg then t := '-' + t;
  Result := t;
end;

end.
