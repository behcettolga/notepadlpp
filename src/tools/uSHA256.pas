// SPDX-License-Identifier: MPL-2.0
unit uSHA256;

{$mode objfpc}{$H+}

{ SHA-256 (FIPS 180-4). UI-free core. FPC 3.2.2 ships no SHA-256 unit, so we
  implement it here — pure Pascal, dependency-free, verified against NIST vectors
  in the test suite. Returns the lowercase hex digest. }

interface

function SHA256OfBytes(const AData: array of Byte): string;
function SHA256OfString(const S: RawByteString): string;

implementation

const
  K: array[0..63] of LongWord = (
    $428a2f98, $71374491, $b5c0fbcf, $e9b5dba5, $3956c25b, $59f111f1, $923f82a4, $ab1c5ed5,
    $d807aa98, $12835b01, $243185be, $550c7dc3, $72be5d74, $80deb1fe, $9bdc06a7, $c19bf174,
    $e49b69c1, $efbe4786, $0fc19dc6, $240ca1cc, $2de92c6f, $4a7484aa, $5cb0a9dc, $76f988da,
    $983e5152, $a831c66d, $b00327c8, $bf597fc7, $c6e00bf3, $d5a79147, $06ca6351, $14292967,
    $27b70a85, $2e1b2138, $4d2c6dfc, $53380d13, $650a7354, $766a0abb, $81c2c92e, $92722c85,
    $a2bfe8a1, $a81a664b, $c24b8b70, $c76c51a3, $d192e819, $d6990624, $f40e3585, $106aa070,
    $19a4c116, $1e376c08, $2748774c, $34b0bcb5, $391c0cb3, $4ed8aa4a, $5b9cca4f, $682e6ff3,
    $748f82ee, $78a5636f, $84c87814, $8cc70208, $90befffa, $a4506ceb, $bef9a3f7, $c67178f2);

function RotR(x: LongWord; n: Byte): LongWord; inline;
begin
  Result := (x shr n) or (x shl (32 - n));
end;

function SHA256OfBytes(const AData: array of Byte): string;
var
  H: array[0..7] of LongWord;
  msg: array of Byte;
  origLenBits: QWord;
  i, padLen, total, chunk: Integer;
  w: array[0..63] of LongWord;
  a, b, c, d, e, f, g, hh, t1, t2, s0, s1, ch, maj: LongWord;
  hexStr: string;
const
  HexDigits = '0123456789abcdef';
begin
  H[0] := $6a09e667; H[1] := $bb67ae85; H[2] := $3c6ef372; H[3] := $a54ff53a;
  H[4] := $510e527f; H[5] := $9b05688c; H[6] := $1f83d9ab; H[7] := $5be0cd19;

  origLenBits := QWord(Length(AData)) * 8;
  // padding: 0x80, zeros, until length ≡ 56 (mod 64), then 8-byte big-endian length
  padLen := 56 - ((Length(AData) + 1) mod 64);
  if padLen < 0 then padLen := padLen + 64;
  total := Length(AData) + 1 + padLen + 8;
  SetLength(msg, total);
  if Length(AData) > 0 then
    Move(AData[0], msg[0], Length(AData));
  msg[Length(AData)] := $80;
  for i := Length(AData) + 1 to Length(AData) + padLen do
    msg[i] := 0;
  for i := 0 to 7 do
    msg[total - 1 - i] := Byte(origLenBits shr (8 * i));

  chunk := 0;
  while chunk < total do
  begin
    for i := 0 to 15 do
      w[i] := (LongWord(msg[chunk + i*4]) shl 24) or
              (LongWord(msg[chunk + i*4 + 1]) shl 16) or
              (LongWord(msg[chunk + i*4 + 2]) shl 8) or
              (LongWord(msg[chunk + i*4 + 3]));
    for i := 16 to 63 do
    begin
      s0 := RotR(w[i-15], 7) xor RotR(w[i-15], 18) xor (w[i-15] shr 3);
      s1 := RotR(w[i-2], 17) xor RotR(w[i-2], 19) xor (w[i-2] shr 10);
      w[i] := w[i-16] + s0 + w[i-7] + s1;
    end;

    a := H[0]; b := H[1]; c := H[2]; d := H[3];
    e := H[4]; f := H[5]; g := H[6]; hh := H[7];

    for i := 0 to 63 do
    begin
      s1 := RotR(e, 6) xor RotR(e, 11) xor RotR(e, 25);
      ch := (e and f) xor ((not e) and g);
      t1 := hh + s1 + ch + K[i] + w[i];
      s0 := RotR(a, 2) xor RotR(a, 13) xor RotR(a, 22);
      maj := (a and b) xor (a and c) xor (b and c);
      t2 := s0 + maj;
      hh := g; g := f; f := e; e := d + t1;
      d := c; c := b; b := a; a := t1 + t2;
    end;

    H[0] := H[0] + a; H[1] := H[1] + b; H[2] := H[2] + c; H[3] := H[3] + d;
    H[4] := H[4] + e; H[5] := H[5] + f; H[6] := H[6] + g; H[7] := H[7] + hh;

    Inc(chunk, 64);
  end;

  hexStr := '';
  for i := 0 to 7 do
  begin
    hexStr := hexStr +
      HexDigits[((H[i] shr 28) and $F) + 1] + HexDigits[((H[i] shr 24) and $F) + 1] +
      HexDigits[((H[i] shr 20) and $F) + 1] + HexDigits[((H[i] shr 16) and $F) + 1] +
      HexDigits[((H[i] shr 12) and $F) + 1] + HexDigits[((H[i] shr 8) and $F) + 1] +
      HexDigits[((H[i] shr 4) and $F) + 1] + HexDigits[(H[i] and $F) + 1];
  end;
  Result := hexStr;
end;

function SHA256OfString(const S: RawByteString): string;
var
  bytes: array of Byte;
begin
  SetLength(bytes, Length(S));
  if Length(S) > 0 then
    Move(S[1], bytes[0], Length(S));
  Result := SHA256OfBytes(bytes);
end;

end.
