// SPDX-License-Identifier: MPL-2.0
unit uDocumentManager;

{$mode objfpc}{$H+}

{ The set of open documents <-> tabs. UI-free core model (ARCHITECTURE §4).
  Owns its TDocument instances. Opening a file already open re-selects it
  rather than duplicating. }

interface

uses
  Classes, SysUtils, contnrs, uDocument;

type

  { TDocumentManager }

  TDocumentManager = class
  private
    FDocs: TObjectList;     // owns TDocument
    FActiveIndex: Integer;
    FOnListChange: TNotifyEvent;
    function GetCount: Integer;
    function GetDoc(Index: Integer): TDocument;
    procedure SetActiveIndex(AValue: Integer);
    procedure ListChanged;
  public
    constructor Create;
    destructor Destroy; override;
    function NewDocument: TDocument;
    function OpenFile(const AFileName: string): TDocument;
    function IndexOfPath(const AFileName: string): Integer;
    procedure Close(Index: Integer);
    procedure CloseAll;
    function HasModified: Boolean;
    function Active: TDocument;

    property Count: Integer read GetCount;
    property Docs[Index: Integer]: TDocument read GetDoc; default;
    property ActiveIndex: Integer read FActiveIndex write SetActiveIndex;
    property OnListChange: TNotifyEvent read FOnListChange write FOnListChange;
  end;

implementation

constructor TDocumentManager.Create;
begin
  inherited Create;
  FDocs := TObjectList.Create(True); // owns documents
  FActiveIndex := -1;
end;

destructor TDocumentManager.Destroy;
begin
  FDocs.Free;
  inherited Destroy;
end;

function TDocumentManager.GetCount: Integer;
begin
  Result := FDocs.Count;
end;

function TDocumentManager.GetDoc(Index: Integer): TDocument;
begin
  Result := TDocument(FDocs[Index]);
end;

procedure TDocumentManager.ListChanged;
begin
  if Assigned(FOnListChange) then
    FOnListChange(Self);
end;

procedure TDocumentManager.SetActiveIndex(AValue: Integer);
begin
  if AValue < -1 then AValue := -1;
  if AValue >= FDocs.Count then AValue := FDocs.Count - 1;
  if FActiveIndex = AValue then Exit;
  FActiveIndex := AValue;
  ListChanged;
end;

function TDocumentManager.Active: TDocument;
begin
  if (FActiveIndex >= 0) and (FActiveIndex < FDocs.Count) then
    Result := TDocument(FDocs[FActiveIndex])
  else
    Result := nil;
end;

function TDocumentManager.NewDocument: TDocument;
begin
  Result := TDocument.Create;
  FDocs.Add(Result);
  FActiveIndex := FDocs.Count - 1;
  ListChanged;
end;

function TDocumentManager.IndexOfPath(const AFileName: string): Integer;
var
  i: Integer;
begin
  for i := 0 to FDocs.Count - 1 do
    if (not TDocument(FDocs[i]).Untitled) and
       SameFileName(TDocument(FDocs[i]).FilePath, AFileName) then
      Exit(i);
  Result := -1;
end;

function TDocumentManager.OpenFile(const AFileName: string): TDocument;
var
  idx: Integer;
begin
  idx := IndexOfPath(AFileName);
  if idx >= 0 then
  begin
    FActiveIndex := idx;
    Result := TDocument(FDocs[idx]);
    ListChanged;
    Exit;
  end;
  Result := TDocument.Create;
  Result.LoadFromFile(AFileName);
  FDocs.Add(Result);
  FActiveIndex := FDocs.Count - 1;
  ListChanged;
end;

procedure TDocumentManager.Close(Index: Integer);
begin
  if (Index < 0) or (Index >= FDocs.Count) then Exit;
  FDocs.Delete(Index); // frees the document (owned)
  if FActiveIndex >= FDocs.Count then
    FActiveIndex := FDocs.Count - 1;
  ListChanged;
end;

procedure TDocumentManager.CloseAll;
begin
  FDocs.Clear;
  FActiveIndex := -1;
  ListChanged;
end;

function TDocumentManager.HasModified: Boolean;
var
  i: Integer;
begin
  for i := 0 to FDocs.Count - 1 do
    if TDocument(FDocs[i]).Modified then
      Exit(True);
  Result := False;
end;

end.
