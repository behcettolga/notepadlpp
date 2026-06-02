// SPDX-License-Identifier: MPL-2.0
unit uEditorActions;

{$mode objfpc}{$H+}

{ Editor line/text operations. UI-FREE core (ARCHITECTURE §4): pure functions over
  line arrays / strings, so they carry fpcunit tests on string fixtures. The UI
  layer maps the editor's selection to a line range and feeds these.

  Line ranges are inclusive, 0-based. Case operations are UTF-8 aware (LazUTF8). }

interface

uses
  Classes, SysUtils, LazUTF8;

type
  TLines = TStringArray;

{ Line operations }
function DuplicateLines(const Lines: TLines; AFrom, ATo: Integer): TLines;
function DeleteLines(const Lines: TLines; AFrom, ATo: Integer): TLines;
function MoveLinesUp(const Lines: TLines; AFrom, ATo: Integer): TLines;
function MoveLinesDown(const Lines: TLines; AFrom, ATo: Integer): TLines;
function SortLines(const Lines: TLines; Ascending, CaseSensitive: Boolean): TLines;
function RemoveDuplicateLines(const Lines: TLines): TLines;
function ToggleLineComment(const Lines: TLines; AFrom, ATo: Integer;
  const APrefix: string): TLines;
function IndentLines(const Lines: TLines; AFrom, ATo: Integer;
  const AIndent: string): TLines;
function OutdentLines(const Lines: TLines; AFrom, ATo: Integer;
  ATabWidth: Integer): TLines;

{ Text operations }
function TrimTrailingWhitespacePerLine(const Text: string): string;
function CaseUpper(const S: string): string;
function CaseLower(const S: string): string;
function CaseTitle(const S: string): string;

implementation

{ ---- helpers ---- }

procedure ClampRange(var AFrom, ATo, ACount: Integer);
var t: Integer;
begin
  if AFrom > ATo then begin t := AFrom; AFrom := ATo; ATo := t; end;
  if AFrom < 0 then AFrom := 0;
  if ATo > ACount - 1 then ATo := ACount - 1;
end;

{ ---- line operations ---- }

function DuplicateLines(const Lines: TLines; AFrom, ATo: Integer): TLines;
var i, n, blk, outIdx: Integer;
begin
  n := Length(Lines);
  if n = 0 then Exit(Lines);
  ClampRange(AFrom, ATo, n);
  blk := ATo - AFrom + 1;
  SetLength(Result, n + blk);
  outIdx := 0;
  for i := 0 to n - 1 do
  begin
    Result[outIdx] := Lines[i]; Inc(outIdx);
    if i = ATo then // insert the duplicated block right after the range
      for blk := AFrom to ATo do
      begin
        Result[outIdx] := Lines[blk]; Inc(outIdx);
      end;
  end;
end;

function DeleteLines(const Lines: TLines; AFrom, ATo: Integer): TLines;
var i, n, outIdx: Integer;
begin
  n := Length(Lines);
  if n = 0 then Exit(Lines);
  ClampRange(AFrom, ATo, n);
  SetLength(Result, n - (ATo - AFrom + 1));
  outIdx := 0;
  for i := 0 to n - 1 do
    if (i < AFrom) or (i > ATo) then
    begin
      Result[outIdx] := Lines[i]; Inc(outIdx);
    end;
end;

function MoveLinesUp(const Lines: TLines; AFrom, ATo: Integer): TLines;
var i, n: Integer;
begin
  n := Length(Lines);
  Result := Copy(Lines, 0, n);
  if n = 0 then Exit;
  ClampRange(AFrom, ATo, n);
  if AFrom = 0 then Exit; // already at top
  // line above the block moves to just below the block
  for i := AFrom to ATo do
    Result[i - 1] := Lines[i];
  Result[ATo] := Lines[AFrom - 1];
end;

function MoveLinesDown(const Lines: TLines; AFrom, ATo: Integer): TLines;
var i, n: Integer;
begin
  n := Length(Lines);
  Result := Copy(Lines, 0, n);
  if n = 0 then Exit;
  ClampRange(AFrom, ATo, n);
  if ATo = n - 1 then Exit; // already at bottom
  for i := AFrom to ATo do
    Result[i + 1] := Lines[i];
  Result[AFrom] := Lines[ATo + 1];
end;

function SortLines(const Lines: TLines; Ascending, CaseSensitive: Boolean): TLines;
var
  i, j, n: Integer;
  cmp: Integer;
  tmp: string;
begin
  n := Length(Lines);
  Result := Copy(Lines, 0, n);
  // simple stable-ish insertion sort (line counts here are modest; deterministic)
  for i := 1 to n - 1 do
  begin
    tmp := Result[i];
    j := i - 1;
    while j >= 0 do
    begin
      if CaseSensitive then
        cmp := CompareStr(Result[j], tmp)
      else
        cmp := CompareText(Result[j], tmp);
      if (Ascending and (cmp > 0)) or ((not Ascending) and (cmp < 0)) then
      begin
        Result[j + 1] := Result[j];
        Dec(j);
      end
      else
        Break;
    end;
    Result[j + 1] := tmp;
  end;
end;

function RemoveDuplicateLines(const Lines: TLines): TLines;
var
  i, outIdx: Integer;
  seen: TStringList;
begin
  seen := TStringList.Create;
  try
    seen.Sorted := True;
    seen.Duplicates := dupIgnore;
    SetLength(Result, Length(Lines));
    outIdx := 0;
    for i := 0 to High(Lines) do
      if seen.IndexOf(Lines[i]) < 0 then
      begin
        seen.Add(Lines[i]);
        Result[outIdx] := Lines[i];
        Inc(outIdx);
      end;
    SetLength(Result, outIdx);
  finally
    seen.Free;
  end;
end;

function ToggleLineComment(const Lines: TLines; AFrom, ATo: Integer;
  const APrefix: string): TLines;
var
  i, n: Integer;
  allCommented: Boolean;
  trimmed: string;
begin
  n := Length(Lines);
  Result := Copy(Lines, 0, n);
  if n = 0 then Exit;
  ClampRange(AFrom, ATo, n);
  // if every non-blank line in range is already commented -> uncomment, else comment
  allCommented := True;
  for i := AFrom to ATo do
  begin
    trimmed := TrimLeft(Lines[i]);
    if (trimmed <> '') and (Copy(trimmed, 1, Length(APrefix)) <> APrefix) then
    begin
      allCommented := False;
      Break;
    end;
  end;
  for i := AFrom to ATo do
  begin
    if allCommented then
    begin
      trimmed := TrimLeft(Result[i]);
      if Copy(trimmed, 1, Length(APrefix)) = APrefix then
      begin
        // remove first occurrence of prefix, preserving leading indent
        Result[i] := StringReplace(Result[i], APrefix, '', []);
      end;
    end
    else if TrimLeft(Result[i]) <> '' then
      Result[i] := APrefix + Result[i];
  end;
end;

function IndentLines(const Lines: TLines; AFrom, ATo: Integer;
  const AIndent: string): TLines;
var i, n: Integer;
begin
  n := Length(Lines);
  Result := Copy(Lines, 0, n);
  if n = 0 then Exit;
  ClampRange(AFrom, ATo, n);
  for i := AFrom to ATo do
    Result[i] := AIndent + Result[i];
end;

function OutdentLines(const Lines: TLines; AFrom, ATo: Integer;
  ATabWidth: Integer): TLines;
var
  i, n, removed: Integer;
begin
  n := Length(Lines);
  Result := Copy(Lines, 0, n);
  if n = 0 then Exit;
  ClampRange(AFrom, ATo, n);
  if ATabWidth < 1 then ATabWidth := 4;
  for i := AFrom to ATo do
  begin
    if (Length(Result[i]) > 0) and (Result[i][1] = #9) then
      Delete(Result[i], 1, 1) // one leading tab
    else
    begin
      removed := 0;
      while (removed < ATabWidth) and (Length(Result[i]) > 0) and
            (Result[i][1] = ' ') do
      begin
        Delete(Result[i], 1, 1);
        Inc(removed);
      end;
    end;
  end;
end;

{ ---- text operations ---- }

function TrimTrailingWhitespacePerLine(const Text: string): string;
var
  lines: TStringArray;
  i: Integer;
begin
  lines := Text.Split([#10]);
  for i := 0 to High(lines) do
    lines[i] := TrimRight(lines[i]);
  Result := string.Join(#10, lines);
end;

function CaseUpper(const S: string): string;
begin
  Result := UTF8UpperCase(S);
end;

function CaseLower(const S: string): string;
begin
  Result := UTF8LowerCase(S);
end;

function CaseTitle(const S: string): string;
var
  i, len: Integer;
  atWordStart: Boolean;
  ch: string;
  cp: Cardinal;
  p: PChar;
  cl: Integer;
begin
  // Walk codepoints; uppercase the first letter of each word, lowercase the rest.
  Result := '';
  atWordStart := True;
  p := PChar(S);
  len := Length(S);
  i := 0;
  while i < len do
  begin
    cl := UTF8CodepointSize(p + i);
    if cl < 1 then cl := 1;
    ch := Copy(S, i + 1, cl);
    cp := UTF8CodepointToUnicode(p + i, cl);
    // word char: letter or digit (ASCII test is enough for boundary detection)
    if ((cp >= Ord('A')) and (cp <= Ord('Z'))) or
       ((cp >= Ord('a')) and (cp <= Ord('z'))) or
       ((cp >= Ord('0')) and (cp <= Ord('9'))) or (cp >= 128) then
    begin
      if atWordStart then
        Result := Result + UTF8UpperCase(ch)
      else
        Result := Result + UTF8LowerCase(ch);
      atWordStart := False;
    end
    else
    begin
      Result := Result + ch;
      atWordStart := True;
    end;
    Inc(i, cl);
  end;
end;

end.
