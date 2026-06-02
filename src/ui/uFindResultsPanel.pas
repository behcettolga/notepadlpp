// SPDX-License-Identifier: MPL-2.0
unit uFindResultsPanel;

{$mode objfpc}{$H+}

{ Find-in-Files results panel. UI layer (ARCHITECTURE §4). A flat list (one row
  per hit) hosted in a caller-provided container; double-click fires OnJump with
  the file + line + column so the main form can open and navigate to it. Does NOT
  own the TSearchResults (the main form does); keeps a reference for index->hit. }

interface

uses
  Classes, SysUtils, Controls, StdCtrls,
  uSearchResults;

type
  TResultJumpEvent = procedure(const AFileName: string; ALine, ACol: Integer) of object;

  { TFindResultsPanel }

  TFindResultsPanel = class
  private
    FList: TListBox;
    FResults: TSearchResults;
    FOnJump: TResultJumpEvent;
    procedure ListDblClick(Sender: TObject);
  public
    constructor Create(AParent: TWinControl);
    procedure ShowResults(AResults: TSearchResults; const APattern: string);
    procedure Clear;
    property OnJump: TResultJumpEvent read FOnJump write FOnJump;
  end;

implementation

constructor TFindResultsPanel.Create(AParent: TWinControl);
begin
  inherited Create;
  FList := TListBox.Create(AParent);
  FList.Parent := AParent;
  FList.Align := alClient;
  FList.OnDblClick := @ListDblClick;
end;

procedure TFindResultsPanel.Clear;
begin
  FList.Items.Clear;
  FResults := nil;
end;

procedure TFindResultsPanel.ShowResults(AResults: TSearchResults; const APattern: string);
var
  i: Integer;
  h: TSearchHit;
begin
  FResults := AResults;
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    if (AResults = nil) or (AResults.Count = 0) then
    begin
      FList.Items.Add(Format('No matches for "%s".', [APattern]));
      FResults := nil;
      Exit;
    end;
    FList.Items.Add(Format('%d match(es) in %d file(s) for "%s":',
      [AResults.Count, AResults.FileCount, APattern]));
    for i := 0 to AResults.Count - 1 do
    begin
      h := AResults[i];
      // index i in list maps to hit i-1 (row 0 is the header)
      FList.Items.Add(Format('%s:%d:%d  %s',
        [ExtractFileName(h.FileName), h.Line, h.Col, Trim(h.LineText)]));
    end;
  finally
    FList.Items.EndUpdate;
  end;
end;

procedure TFindResultsPanel.ListDblClick(Sender: TObject);
var
  hitIdx: Integer;
  h: TSearchHit;
begin
  if (FResults = nil) or (FList.ItemIndex <= 0) then Exit; // 0 is header
  hitIdx := FList.ItemIndex - 1;
  if (hitIdx < 0) or (hitIdx >= FResults.Count) then Exit;
  h := FResults[hitIdx];
  if Assigned(FOnJump) then
    FOnJump(h.FileName, h.Line, h.Col);
end;

end.
