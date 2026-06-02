// SPDX-License-Identifier: MPL-2.0
unit uDocument;

{$mode objfpc}{$H+}

{ One open document. UI-free core model (ARCHITECTURE §4).

  Holds path, encoding, line-ending kind, dirty state, and the text. Text is kept
  LF-normalized internally (the natural editor representation); the document's
  line-ending kind is re-applied when producing bytes for saving. Encoding and
  line-ending changes mark the document modified because they change saved bytes. }

interface

uses
  Classes, SysUtils, uEncoding, uFileIO;

type

  { TDocument }

  TDocument = class
  private
    FFilePath: string;
    FEncoding: TFileEncoding;
    FLineEnding: TLineEndingKind;
    FModified: Boolean;
    FTextLF: string;
    FOnChange: TNotifyEvent;
    procedure Changed;
    procedure SetTextLF(const AValue: string);
    procedure SetEncoding(AValue: TFileEncoding);
    procedure SetLineEnding(AValue: TLineEndingKind);
    procedure SetModified(AValue: Boolean);
    function GetUntitled: Boolean;
    function GetDisplayName: string;
  public
    constructor Create;
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string); // Save As: adopts the path
    procedure Save;                                // save to current path
    procedure Reload;                              // re-read current path from disk
    function EncodedBytes: TBytes;                 // EOL applied + encoded

    property FilePath: string read FFilePath;
    property DisplayName: string read GetDisplayName;
    property Untitled: Boolean read GetUntitled;
    property Encoding: TFileEncoding read FEncoding write SetEncoding;
    property LineEnding: TLineEndingKind read FLineEnding write SetLineEnding;
    property Modified: Boolean read FModified write SetModified;
    property TextLF: string read FTextLF write SetTextLF;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

constructor TDocument.Create;
begin
  inherited Create;
  FFilePath := '';
  FEncoding := feUTF8;
  FLineEnding := leLF;
  FModified := False;
  FTextLF := '';
end;

procedure TDocument.Changed;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TDocument.SetTextLF(const AValue: string);
begin
  if FTextLF = AValue then Exit;
  FTextLF := AValue;
  FModified := True;
  Changed;
end;

procedure TDocument.SetEncoding(AValue: TFileEncoding);
begin
  if FEncoding = AValue then Exit;
  FEncoding := AValue;
  FModified := True;
  Changed;
end;

procedure TDocument.SetLineEnding(AValue: TLineEndingKind);
begin
  if FLineEnding = AValue then Exit;
  FLineEnding := AValue;
  FModified := True;
  Changed;
end;

procedure TDocument.SetModified(AValue: Boolean);
begin
  if FModified = AValue then Exit;
  FModified := AValue;
  Changed;
end;

function TDocument.GetUntitled: Boolean;
begin
  Result := FFilePath = '';
end;

function TDocument.GetDisplayName: string;
begin
  if Untitled then
    Result := 'untitled'
  else
    Result := ExtractFileName(FFilePath);
end;

procedure TDocument.LoadFromFile(const AFileName: string);
var
  lr: TLoadResult;
begin
  lr := LoadTextFile(AFileName);
  FFilePath := AFileName;
  FEncoding := lr.Encoding;
  if lr.HasLineEnding then
    FLineEnding := lr.LineEnding
  else
    FLineEnding := leLF;
  FTextLF := EncodingService.NormalizeToLF(lr.TextUTF8);
  FModified := False;
  Changed;
end;

function TDocument.EncodedBytes: TBytes;
var
  withEol: string;
begin
  withEol := EncodingService.ApplyLineEnding(FTextLF, FLineEnding);
  Result := EncodingService.EncodeFromUTF8(withEol, FEncoding);
end;

procedure TDocument.SaveToFile(const AFileName: string);
begin
  uFileIO.SaveBytes(AFileName, EncodedBytes);
  FFilePath := AFileName;
  FModified := False;
  Changed;
end;

procedure TDocument.Save;
begin
  if Untitled then
    raise Exception.Create('Cannot Save an untitled document; use SaveToFile');
  SaveToFile(FFilePath);
end;

procedure TDocument.Reload;
begin
  if Untitled then
    raise Exception.Create('Cannot Reload an untitled document');
  LoadFromFile(FFilePath);
end;

end.
