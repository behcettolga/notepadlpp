// SPDX-License-Identifier: MPL-2.0
unit uCsvViewer;

{$mode objfpc}{$H+}

{ CSV grid viewer. UI layer (ARCHITECTURE §4). Renders a TCsvData (parsed by
  uCsvTool) in a TStringGrid. Resourceless code-built form. }

interface

uses
  Classes, SysUtils, Forms, Grids,
  uCsvTool;

type

  { TCsvViewer }

  TCsvViewer = class(TForm)
  private
    FGrid: TStringGrid;
  public
    constructor CreateNewDlg(AOwner: TComponent);
    procedure ShowCsv(const AText: string);
  end;

implementation

uses
  Controls;

constructor TCsvViewer.CreateNewDlg(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'CSV Viewer';
  Width := 760; Height := 480;
  Position := poScreenCenter;
  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.Options := FGrid.Options + [goColSizing, goRowSizing, goThumbTracking];
end;

procedure TCsvViewer.ShowCsv(const AText: string);
var
  data: TCsvData;
  r, c: Integer;
begin
  data := ParseCsv(AText, DetectDelimiter(AText));
  try
    FGrid.RowCount := data.RowCount;
    FGrid.ColCount := data.ColCount;
    FGrid.FixedRows := 0;
    FGrid.FixedCols := 0;
    for r := 0 to data.RowCount - 1 do
      for c := 0 to data.ColCount - 1 do
        FGrid.Cells[c, r] := data.Cell(r, c);
    // use the first row as a header band if there is more than one row
    if data.RowCount > 1 then
      FGrid.FixedRows := 1;
  finally
    data.Free;
  end;
end;

end.
