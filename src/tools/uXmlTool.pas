// SPDX-License-Identifier: MPL-2.0
unit uXmlTool;

{$mode objfpc}{$H+}

{ XML pretty-print / well-formedness check. UI-free core (ARCHITECTURE §4), tested.
  Built on laz2_DOM + laz2_XMLRead/Write (LazUtils). On parse failure the message
  carries the line/pos reported by the reader. }

interface

uses
  Classes, SysUtils, laz2_DOM, laz2_XMLRead, laz2_XMLWrite;

function XmlFormat(const S: string; out AError: string): string;
function XmlValidate(const S: string; out AError: string): Boolean;

implementation

function ReadDoc(const S: string; out ADoc: TXMLDocument; out AError: string): Boolean;
var stream: TStringStream;
begin
  AError := '';
  ADoc := nil;
  stream := TStringStream.Create(S);
  try
    try
      ReadXMLFile(ADoc, stream);
      Result := True;
    except
      on E: Exception do
      begin
        AError := E.Message;
        ADoc := nil;
        Result := False;
      end;
    end;
  finally
    stream.Free;
  end;
end;

function XmlFormat(const S: string; out AError: string): string;
var
  doc: TXMLDocument;
  outs: TStringStream;
begin
  Result := '';
  if not ReadDoc(S, doc, AError) then Exit;
  try
    outs := TStringStream.Create('');
    try
      WriteXMLFile(doc, outs);
      Result := outs.DataString;
    finally
      outs.Free;
    end;
  finally
    doc.Free;
  end;
end;

function XmlValidate(const S: string; out AError: string): Boolean;
var doc: TXMLDocument;
begin
  Result := ReadDoc(S, doc, AError);
  if doc <> nil then doc.Free;
end;

end.
