// SPDX-License-Identifier: MPL-2.0
unit uTestConverters;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  uConverters, uSHA256;

type

  { TConvertersTest — RFC 4648 Base64, NIST SHA-256, and round-trip vectors. }

  TConvertersTest = class(TTestCase)
  published
    procedure Base64RFC4648Vectors;
    procedure Base64RoundTrip;
    procedure UrlEncodeBasic;
    procedure UrlRoundTrip;
    procedure MD5Vector;
    procedure SHA1Vector;
    procedure SHA256NistAbc;
    procedure SHA256NistEmpty;
    procedure SHA256NistLong;
    procedure UuidShape;
    procedure BaseConvertHexToDec;
    procedure BaseConvertDecToBin;
    procedure BaseConvertRoundTrip;
    procedure BaseConvertInvalid;
  end;

implementation

procedure TConvertersTest.Base64RFC4648Vectors;
begin
  // RFC 4648 §10 test vectors
  AssertEquals('', '', Base64Encode(''));
  AssertEquals('f', 'Zg==', Base64Encode('f'));
  AssertEquals('fo', 'Zm8=', Base64Encode('fo'));
  AssertEquals('foo', 'Zm9v', Base64Encode('foo'));
  AssertEquals('foob', 'Zm9vYg==', Base64Encode('foob'));
  AssertEquals('fooba', 'Zm9vYmE=', Base64Encode('fooba'));
  AssertEquals('foobar', 'Zm9vYmFy', Base64Encode('foobar'));
end;

procedure TConvertersTest.Base64RoundTrip;
begin
  AssertEquals('rt', 'Hello, World!',
    Base64Decode(Base64Encode('Hello, World!')));
end;

procedure TConvertersTest.UrlEncodeBasic;
begin
  AssertEquals('space+special', 'a%20b%2Bc%2Fd', UrlEncode('a b+c/d'));
  AssertEquals('unreserved kept', 'A-z_0.9~', UrlEncode('A-z_0.9~'));
end;

procedure TConvertersTest.UrlRoundTrip;
begin
  AssertEquals('rt', 'key=value & more/stuff?',
    UrlDecode(UrlEncode('key=value & more/stuff?')));
end;

procedure TConvertersTest.MD5Vector;
begin
  // RFC 1321: MD5("abc")
  AssertEquals('md5 abc', '900150983cd24fb0d6963f7d28e17f72', HashMD5('abc'));
end;

procedure TConvertersTest.SHA1Vector;
begin
  AssertEquals('sha1 abc', 'a9993e364706816aba3e25717850c26c9cd0d89d', HashSHA1('abc'));
end;

procedure TConvertersTest.SHA256NistAbc;
begin
  // NIST: SHA-256("abc")
  AssertEquals('sha256 abc',
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    HashSHA256('abc'));
end;

procedure TConvertersTest.SHA256NistEmpty;
begin
  AssertEquals('sha256 empty',
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    HashSHA256(''));
end;

procedure TConvertersTest.SHA256NistLong;
begin
  // NIST: 448-bit message (exercises multi-block + padding boundary)
  AssertEquals('sha256 56-char',
    '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    HashSHA256('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'));
end;

procedure TConvertersTest.UuidShape;
var u: string;
begin
  u := NewUuid;
  AssertEquals('length 36', 36, Length(u));
  AssertEquals('dash 9', '-', u[9]);
  AssertEquals('dash 14', '-', u[14]);
  AssertEquals('dash 19', '-', u[19]);
  AssertEquals('dash 24', '-', u[24]);
end;

procedure TConvertersTest.BaseConvertHexToDec;
begin
  AssertEquals('ff -> 255', '255', ConvertBase('ff', 16, 10));
  AssertEquals('FF -> 255 (case)', '255', ConvertBase('FF', 16, 10));
end;

procedure TConvertersTest.BaseConvertDecToBin;
begin
  AssertEquals('10 -> 1010', '1010', ConvertBase('10', 10, 2));
  AssertEquals('255 -> ff', 'ff', ConvertBase('255', 10, 16));
end;

procedure TConvertersTest.BaseConvertRoundTrip;
begin
  AssertEquals('dec->oct->dec', '511',
    ConvertBase(ConvertBase('511', 10, 8), 8, 10));
end;

procedure TConvertersTest.BaseConvertInvalid;
begin
  AssertEquals('invalid digit', '', ConvertBase('2', 2, 10)); // '2' invalid in base 2
  AssertEquals('bad base', '', ConvertBase('10', 1, 10));
end;

initialization
  RegisterTest(TConvertersTest);

end.
