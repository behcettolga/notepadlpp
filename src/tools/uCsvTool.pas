// SPDX-License-Identifier: MPL-2.0
unit uCsvTool;

{$mode objfpc}{$H+}

{ CSV parsing into a row/column model. UI-free core (ARCHITECTURE §4), tested.
  Handles quoted fields with embedded delimiters, quotes ("" escape) and newlines.
  Delimiter is auto-detectable or supplied. The grid viewer (UI) renders TCsvData. }

interface

uses
  Classes, SysUtils;

type

  { TCsvData }

  TCsvData = class
  private
    FRows: array of TStringArray;
  public
    procedure AddRow(const ARow: TStringArray);
    function RowCount: Integer;
    function ColCount: Integer;            // widest row
    function Cell(ARow, ACol: Integer): string;
    function Row(AIndex: Integer): TStringArray;
  end;

function DetectDelimiter(const AText: string): Char;
function ParseCsv(const AText: string; ADelimiter: Char): TCsvData;

implementation

{ TCsvData }

procedure TCsvData.AddRow(const ARow: TStringArray);
begin
  SetLength(FRows, Length(FRows) + 1);
  FRows[High(FRows)] := ARow;
end;

function TCsvData.RowCount: Integer;
begin
  Result := Length(FRows);
end;

function TCsvData.ColCount: Integer;
var i: Integer;
begin
  Result := 0;
  for i := 0 to High(FRows) do
    if Length(FRows[i]) > Result then
      Result := Length(FRows[i]);
end;

function TCsvData.Cell(ARow, ACol: Integer): string;
begin
  if (ARow < 0) or (ARow > High(FRows)) then Exit('');
  if (ACol < 0) or (ACol > High(FRows[ARow])) then Exit('');
  Result := FRows[ARow][ACol];
end;

function TCsvData.Row(AIndex: Integer): TStringArray;
begin
  if (AIndex < 0) or (AIndex > High(FRows)) then Exit(nil);
  Result := FRows[AIndex];
end;

function DetectDelimiter(const AText: string): Char;
const
  Cands: array[0..2] of Char = (',', ';', #9);
var
  i, ci, best, score: Integer;
  c: Char;
  inQuote: Boolean;
  counts: array[0..2] of Integer;
begin
  // count delimiter occurrences outside quotes on the first line
  for ci := 0 to 2 do counts[ci] := 0;
  inQuote := False;
  for i := 1 to Length(AText) do
  begin
    c := AText[i];
    if c = '"' then inQuote := not inQuote
    else if (c = #10) and (not inQuote) then Break
    else if not inQuote then
      for ci := 0 to 2 do
        if c = Cands[ci] then Inc(counts[ci]);
  end;
  best := 0; score := counts[0];
  for ci := 1 to 2 do
    if counts[ci] > score then begin score := counts[ci]; best := ci; end;
  Result := Cands[best];
end;

function ParseCsv(const AText: string; ADelimiter: Char): TCsvData;
var
  i, len: Integer;
  c: Char;
  field: string;
  row: TStringArray;
  inQuote, rowHasData: Boolean;

  procedure EndField;
  begin
    SetLength(row, Length(row) + 1);
    row[High(row)] := field;
    field := '';
  end;

  procedure EndRow;
  begin
    EndField;
    Result.AddRow(row);
    SetLength(row, 0);
    rowHasData := False;
  end;

begin
  Result := TCsvData.Create;
  field := '';
  SetLength(row, 0);
  inQuote := False;
  rowHasData := False;
  len := Length(AText);
  i := 1;
  while i <= len do
  begin
    c := AText[i];
    if inQuote then
    begin
      if c = '"' then
      begin
        if (i < len) and (AText[i + 1] = '"') then
        begin
          field := field + '"'; // escaped quote
          Inc(i);
        end
        else
          inQuote := False;
      end
      else
        field := field + c;
    end
    else
    begin
      case c of
        '"': inQuote := True;
        #13: ; // ignore CR; LF drives row breaks
        #10: EndRow;
      else
        if c = ADelimiter then EndField
        else field := field + c;
      end;
      if c <> #10 then rowHasData := True;
    end;
    Inc(i);
  end;
  // flush trailing field/row if anything pending
  if (field <> '') or (Length(row) > 0) or rowHasData then
    EndRow;
end;

end.
