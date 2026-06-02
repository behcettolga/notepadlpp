// SPDX-License-Identifier: MPL-2.0
unit uSearchEngine;

{$mode objfpc}{$H+}

{ Single-document find/replace. UI-free core (ARCHITECTURE §4), fully testable.

  Positions are 1-based byte offsets into the UTF-8 text (matching FPC string
  indexing and what the editor layer maps to caret positions). Regex uses
  TRegExpr (~90% Notepad++ parity, per kickoff). Case-insensitivity for plain
  search is ASCII case-folding (the non-ASCII ~10% is out of Phase-1 scope) and
  preserves byte positions exactly. }

interface

uses
  Classes, SysUtils, RegExpr;

type
  TSearchOption = (soMatchCase, soWholeWord, soRegex);
  TSearchOptions = set of TSearchOption;

  TSearchMatch = record
    Start: Integer;   // 1-based byte index of first char
    Length: Integer;  // byte length of the match
  end;
  TSearchMatchArray = array of TSearchMatch;

{ Find the first match at or after FromPos (1-based). If Wrap and nothing is
  found from FromPos, the search restarts at position 1. Returns False if the
  pattern is empty or no match exists. }
function FindNext(const Text, Pattern: string; FromPos: Integer;
  Options: TSearchOptions; Wrap: Boolean; out Match: TSearchMatch): Boolean;

function FindAll(const Text, Pattern: string;
  Options: TSearchOptions): TSearchMatchArray;

function CountMatches(const Text, Pattern: string;
  Options: TSearchOptions): Integer;

{ Replace all non-overlapping matches. For regex, Replacement supports $1.. group
  substitution; for plain search it is inserted literally. Returns the new text;
  Count receives the number of replacements. }
function ReplaceAll(const Text, Pattern, Replacement: string;
  Options: TSearchOptions; out Count: Integer): string;

implementation

function IsWordByte(B: Byte): Boolean; inline;
begin
  Result := (B >= Ord('0')) and (B <= Ord('9')) or
            (B >= Ord('A')) and (B <= Ord('Z')) or
            (B >= Ord('a')) and (B <= Ord('z')) or
            (B = Ord('_')) or (B >= 128); // treat UTF-8 continuation/lead as word
end;

function FoldByte(B: Byte): Byte; inline;
begin
  if (B >= Ord('A')) and (B <= Ord('Z')) then
    Result := B + 32
  else
    Result := B;
end;

{ Does Pattern occur in Text exactly at 1-based AtPos? (plain, with case option) }
function MatchesAt(const Text, Pattern: string; AtPos: Integer;
  CaseSensitive: Boolean): Boolean;
var
  i, pl, tl: Integer;
  a, b: Byte;
begin
  pl := Length(Pattern);
  tl := Length(Text);
  if AtPos + pl - 1 > tl then Exit(False);
  for i := 1 to pl do
  begin
    a := Byte(Text[AtPos + i - 1]);
    b := Byte(Pattern[i]);
    if CaseSensitive then
    begin
      if a <> b then Exit(False);
    end
    else if FoldByte(a) <> FoldByte(b) then
      Exit(False);
  end;
  Result := True;
end;

function IsWholeWordAt(const Text: string; Start, Len: Integer): Boolean;
var
  before, after: Boolean;
begin
  before := (Start <= 1) or (not IsWordByte(Byte(Text[Start - 1])));
  after := (Start + Len > Length(Text)) or (not IsWordByte(Byte(Text[Start + Len])));
  Result := before and after;
end;

{ ---- regex helpers ---- }

function MakeRegex(const Pattern: string; Options: TSearchOptions): TRegExpr;
begin
  Result := TRegExpr.Create;
  Result.Expression := Pattern;
  Result.ModifierI := not (soMatchCase in Options);
  Result.ModifierM := True; // ^/$ match line boundaries
end;

function RegexFindAll(const Text, Pattern: string;
  Options: TSearchOptions): TSearchMatchArray;
var
  r: TRegExpr;
  n: Integer;
  m: TSearchMatch;
begin
  SetLength(Result, 0);
  n := 0;
  r := MakeRegex(Pattern, Options);
  try
    try
      if r.Exec(Text) then
        repeat
          m.Start := r.MatchPos[0];
          m.Length := r.MatchLen[0];
          if m.Length = 0 then Break; // avoid infinite loop on empty match
          Inc(n);
          SetLength(Result, n);
          Result[n - 1] := m;
        until not r.ExecNext;
    except
      on E: Exception do
        SetLength(Result, 0); // invalid pattern => no matches
    end;
  finally
    r.Free;
  end;
end;

{ ---- plain helpers ---- }

function PlainFindAll(const Text, Pattern: string;
  Options: TSearchOptions): TSearchMatchArray;
var
  pos, tl, pl, n: Integer;
  caseSens, wholeWord: Boolean;
  m: TSearchMatch;
begin
  SetLength(Result, 0);
  pl := Length(Pattern);
  tl := Length(Text);
  if (pl = 0) or (pl > tl) then Exit;
  caseSens := soMatchCase in Options;
  wholeWord := soWholeWord in Options;
  n := 0;
  pos := 1;
  while pos <= tl - pl + 1 do
  begin
    if MatchesAt(Text, Pattern, pos, caseSens) and
       ((not wholeWord) or IsWholeWordAt(Text, pos, pl)) then
    begin
      m.Start := pos;
      m.Length := pl;
      Inc(n);
      SetLength(Result, n);
      Result[n - 1] := m;
      Inc(pos, pl); // non-overlapping
    end
    else
      Inc(pos);
  end;
end;

{ ---- public ---- }

function FindAll(const Text, Pattern: string;
  Options: TSearchOptions): TSearchMatchArray;
begin
  if Pattern = '' then Exit(nil);
  if soRegex in Options then
    Result := RegexFindAll(Text, Pattern, Options)
  else
    Result := PlainFindAll(Text, Pattern, Options);
end;

function CountMatches(const Text, Pattern: string;
  Options: TSearchOptions): Integer;
begin
  Result := Length(FindAll(Text, Pattern, Options));
end;

function FindNext(const Text, Pattern: string; FromPos: Integer;
  Options: TSearchOptions; Wrap: Boolean; out Match: TSearchMatch): Boolean;
var
  all: TSearchMatchArray;
  i: Integer;
begin
  Result := False;
  Match.Start := 0; Match.Length := 0;
  all := FindAll(Text, Pattern, Options);
  if Length(all) = 0 then Exit;
  for i := 0 to High(all) do
    if all[i].Start >= FromPos then
    begin
      Match := all[i];
      Exit(True);
    end;
  if Wrap then
  begin
    Match := all[0];
    Result := True;
  end;
end;

function ReplaceAll(const Text, Pattern, Replacement: string;
  Options: TSearchOptions; out Count: Integer): string;
var
  r: TRegExpr;
  all: TSearchMatchArray;
  i, prev: Integer;
  sb: string;
begin
  Count := 0;
  if Pattern = '' then Exit(Text);

  if soRegex in Options then
  begin
    Count := CountMatches(Text, Pattern, Options);
    if Count = 0 then Exit(Text);
    r := MakeRegex(Pattern, Options);
    try
      try
        Result := r.Replace(Text, Replacement, True); // True => $1 substitution
      except
        on E: Exception do begin Result := Text; Count := 0; end;
      end;
    finally
      r.Free;
    end;
    Exit;
  end;

  // plain: build result from match list, inserting Replacement literally
  all := PlainFindAll(Text, Pattern, Options);
  Count := Length(all);
  if Count = 0 then Exit(Text);
  sb := '';
  prev := 1;
  for i := 0 to High(all) do
  begin
    sb := sb + Copy(Text, prev, all[i].Start - prev) + Replacement;
    prev := all[i].Start + all[i].Length;
  end;
  sb := sb + Copy(Text, prev, Length(Text) - prev + 1);
  Result := sb;
end;

end.
