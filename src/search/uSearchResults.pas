// SPDX-License-Identifier: MPL-2.0
unit uSearchResults;

{$mode objfpc}{$H+}

{ Result item model for Find-in-Files. UI-free core (ARCHITECTURE §4): the
  results panel renders these; the model carries enough to jump to file+line. }

interface

uses
  Classes, SysUtils;

type
  TSearchHit = record
    FileName: string;
    Line: Integer;       // 1-based
    Col: Integer;        // 1-based byte column of the match start
    MatchLen: Integer;
    LineText: string;    // the full line, for display
  end;

  { TSearchResults — ordered collection of hits, grouped logically by file
    (hits are appended in walk order, which is file-by-file). }

  TSearchResults = class
  private
    FHits: array of TSearchHit;
    FCount: Integer;
    function GetHit(Index: Integer): TSearchHit;
  public
    procedure Clear;
    procedure Add(const AHit: TSearchHit);
    function FileCount: Integer;          // distinct file names
    property Count: Integer read FCount;
    property Hits[Index: Integer]: TSearchHit read GetHit; default;
  end;

implementation

procedure TSearchResults.Clear;
begin
  SetLength(FHits, 0);
  FCount := 0;
end;

procedure TSearchResults.Add(const AHit: TSearchHit);
begin
  if FCount >= Length(FHits) then
    SetLength(FHits, (FCount + 1) * 2);
  FHits[FCount] := AHit;
  Inc(FCount);
end;

function TSearchResults.GetHit(Index: Integer): TSearchHit;
begin
  Result := FHits[Index];
end;

function TSearchResults.FileCount: Integer;
var
  i: Integer;
  last: string;
begin
  Result := 0;
  last := #0; // sentinel that no real path equals
  for i := 0 to FCount - 1 do
    if FHits[i].FileName <> last then
    begin
      Inc(Result);
      last := FHits[i].FileName;
    end;
end;

end.
