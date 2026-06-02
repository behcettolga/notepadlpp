// SPDX-License-Identifier: MPL-2.0
unit uJsonTool;

{$mode objfpc}{$H+}

{ JSON pretty-print / minify / validate. UI-free core (ARCHITECTURE §4), tested.
  Built on fpjson + jsonparser (stdlib). On parse failure the error message
  includes the line/position reported by the JSON scanner. }

interface

uses
  Classes, SysUtils, fpjson, jsonparser;

{ Return formatted JSON; on error returns '' and sets AError. }
function JsonPretty(const S: string; out AError: string): string;
{ Return compact JSON (no whitespace); on error returns '' and sets AError. }
function JsonMinify(const S: string; out AError: string): string;
{ True if well-formed; AError carries the parser message (with position) otherwise. }
function JsonValidate(const S: string; out AError: string): Boolean;

implementation

function ParseJson(const S: string; out AError: string): TJSONData;
begin
  AError := '';
  Result := nil;
  try
    Result := GetJSON(S);
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := nil;
    end;
  end;
end;

function JsonPretty(const S: string; out AError: string): string;
var d: TJSONData;
begin
  Result := '';
  d := ParseJson(S, AError);
  if d = nil then Exit;
  try
    Result := d.FormatJSON; // default = indented, 2 spaces
  finally
    d.Free;
  end;
end;

function JsonMinify(const S: string; out AError: string): string;
var d: TJSONData;
begin
  Result := '';
  d := ParseJson(S, AError);
  if d = nil then Exit;
  try
    Result := d.FormatJSON(AsCompressedJSON);
  finally
    d.Free;
  end;
end;

function JsonValidate(const S: string; out AError: string): Boolean;
var d: TJSONData;
begin
  d := ParseJson(S, AError);
  Result := d <> nil;
  d.Free;
end;

end.
