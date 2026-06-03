// SPDX-License-Identifier: MPL-2.0
unit uTestTools;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  uJsonTool, uXmlTool, uCsvTool;

type

  { TToolsTest — JSON/XML/CSV vectors. }

  TToolsTest = class(TTestCase)
  published
    procedure JsonMinifyVector;
    procedure JsonPrettyRoundsTrip;
    procedure JsonValidateOk;
    procedure JsonValidateErrorHasPosition;
    procedure XmlValidateOk;
    procedure XmlValidateMalformed;
    procedure XmlFormatIndents;
    procedure CsvBasicGrid;
    procedure CsvQuotedFields;
    procedure CsvDelimiterDetect;
  end;

implementation

procedure TToolsTest.JsonMinifyVector;
var err: string;
begin
  AssertEquals('minify', '{"a":1,"b":[2,3]}',
    JsonMinify('{ "a" : 1, "b" : [ 2, 3 ] }', err));
  AssertEquals('no error', '', err);
end;

procedure TToolsTest.JsonPrettyRoundsTrip;
var err, pretty, mini: string;
begin
  pretty := JsonPretty('{"x":[1,2]}', err);
  AssertTrue('pretty produced', pretty <> '');
  // re-minify the pretty output -> canonical compact form
  mini := JsonMinify(pretty, err);
  AssertEquals('round-trip', '{"x":[1,2]}', mini);
end;

procedure TToolsTest.JsonValidateOk;
var err: string;
begin
  AssertTrue('valid', JsonValidate('{"ok":true}', err));
end;

procedure TToolsTest.JsonValidateErrorHasPosition;
var err: string;
begin
  AssertFalse('invalid', JsonValidate('{bad}', err));
  AssertTrue('mentions line/pos', (Pos('line', LowerCase(err)) > 0) or
                                   (Pos('pos', LowerCase(err)) > 0));
end;

procedure TToolsTest.XmlValidateOk;
var err: string;
begin
  AssertTrue('valid xml', XmlValidate('<r><a>1</a></r>', err));
end;

procedure TToolsTest.XmlValidateMalformed;
var err: string;
begin
  AssertFalse('malformed', XmlValidate('<r><a></r>', err));
  AssertTrue('error nonempty', err <> '');
end;

procedure TToolsTest.XmlFormatIndents;
var err, f: string;
begin
  f := XmlFormat('<root><a>hi</a></root>', err);
  AssertTrue('has indented child', Pos('  <a>hi</a>', f) > 0);
end;

procedure TToolsTest.CsvBasicGrid;
var d: TCsvData;
begin
  d := ParseCsv('a,b,c'#10'1,2,3', ',');
  try
    AssertEquals('rows', 2, d.RowCount);
    AssertEquals('cols', 3, d.ColCount);
    AssertEquals('cell 0,0', 'a', d.Cell(0, 0));
    AssertEquals('cell 1,2', '3', d.Cell(1, 2));
  finally d.Free; end;
end;

procedure TToolsTest.CsvQuotedFields;
var d: TCsvData;
begin
  // quoted field containing the delimiter and an escaped quote
  d := ParseCsv('"a,b","c""d"'#10'x,y', ',');
  try
    AssertEquals('cell 0,0 keeps comma', 'a,b', d.Cell(0, 0));
    AssertEquals('cell 0,1 unescapes quote', 'c"d', d.Cell(0, 1));
    AssertEquals('row1 col0', 'x', d.Cell(1, 0));
  finally d.Free; end;
end;

procedure TToolsTest.CsvDelimiterDetect;
begin
  AssertEquals('semicolon', ';', DetectDelimiter('a;b;c'#10'1;2;3'));
  AssertEquals('comma', ',', DetectDelimiter('a,b,c'));
end;

initialization
  RegisterTest(TToolsTest);

end.
