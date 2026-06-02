// SPDX-License-Identifier: MPL-2.0
unit uFindInFiles;

{$mode objfpc}{$H+}

{ Find-in-Files engine. UI-free core (ARCHITECTURE §4).

  SearchInTree walks a directory (optionally recursive), filters by a
  semicolon/comma-separated mask list (e.g. '*.log;*.conf'; empty = all files),
  decodes each file via uFileIO (encoding-aware), and runs uSearchEngine per
  line, appending TSearchHit results. It is synchronous and fully unit-testable.

  TFindInFilesThread is a thin cancellable wrapper for the UI; it shares the same
  core, so the tested logic and the shipped logic are identical. }

interface

uses
  Classes, SysUtils, Masks,
  uSearchEngine, uSearchResults, uFileIO, uEncoding;

type
  TFindInFilesParams = record
    Root: string;
    Masks: string;        // ';'/',' separated; '' => all files
    Recursive: Boolean;
    Pattern: string;
    Options: TSearchOptions;
  end;

{ Returns total hit count. If Cancel <> nil and Cancel^ becomes True, the walk
  stops early (partial results retained). }
function SearchInTree(const P: TFindInFilesParams; Results: TSearchResults;
  Cancel: PBoolean = nil): Integer;

type
  { TFindInFilesThread — runs SearchInTree off the UI thread. OnDone is called
    via Synchronize when finished (or cancelled). Caller owns Results. }
  TFindInFilesThread = class(TThread)
  private
    FParams: TFindInFilesParams;
    FResults: TSearchResults;
    FCancel: Boolean;
    FOnDone: TNotifyEvent;
    procedure DoDone;
  protected
    procedure Execute; override;
  public
    constructor Create(const AParams: TFindInFilesParams; AResults: TSearchResults;
      AOnDone: TNotifyEvent);
    procedure CancelSearch;
    property Results: TSearchResults read FResults;
  end;

implementation

function MaskMatches(const FileName, MaskList: string): Boolean;
var
  parts: TStringArray;
  i: Integer;
  m: string;
begin
  if Trim(MaskList) = '' then Exit(True);
  parts := MaskList.Split([';', ',']);
  for i := 0 to High(parts) do
  begin
    m := Trim(parts[i]);
    if (m <> '') and MatchesMask(FileName, m) then
      Exit(True);
  end;
  Result := False;
end;

procedure SearchFile(const FileName: string; const P: TFindInFilesParams;
  Results: TSearchResults);
var
  lr: TLoadResult;
  lines: TStringArray;
  li, k: Integer;
  matches: TSearchMatchArray;
  hit: TSearchHit;
  textLF: string;
begin
  try
    lr := LoadTextFile(FileName);
  except
    Exit; // unreadable file: skip
  end;
  if Pos(#0, lr.TextUTF8) > 0 then Exit; // looks binary: skip
  textLF := EncodingService.NormalizeToLF(lr.TextUTF8);
  lines := textLF.Split([#10]);
  for li := 0 to High(lines) do
  begin
    matches := FindAll(lines[li], P.Pattern, P.Options);
    for k := 0 to High(matches) do
    begin
      hit.FileName := FileName;
      hit.Line := li + 1;
      hit.Col := matches[k].Start;
      hit.MatchLen := matches[k].Length;
      hit.LineText := lines[li];
      Results.Add(hit);
    end;
  end;
end;

function SearchInTree(const P: TFindInFilesParams; Results: TSearchResults;
  Cancel: PBoolean): Integer;

  procedure WalkDir(const Dir: string);
  var
    info: TSearchRec;
    full: string;
  begin
    if (Cancel <> nil) and Cancel^ then Exit;
    // files first
    if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, info) = 0 then
    begin
      repeat
        if (Cancel <> nil) and Cancel^ then Break;
        if (info.Name = '.') or (info.Name = '..') then Continue;
        full := IncludeTrailingPathDelimiter(Dir) + info.Name;
        if (info.Attr and faDirectory) <> 0 then
        begin
          if P.Recursive then WalkDir(full);
        end
        else if MaskMatches(info.Name, P.Masks) then
          SearchFile(full, P, Results);
      until SysUtils.FindNext(info) <> 0;
      SysUtils.FindClose(info);
    end;
  end;

begin
  if (P.Pattern = '') or (not DirectoryExists(P.Root)) then Exit(0);
  WalkDir(P.Root);
  Result := Results.Count;
end;

{ TFindInFilesThread }

constructor TFindInFilesThread.Create(const AParams: TFindInFilesParams;
  AResults: TSearchResults; AOnDone: TNotifyEvent);
begin
  inherited Create(True); // suspended
  FreeOnTerminate := False;
  FParams := AParams;
  FResults := AResults;
  FOnDone := AOnDone;
  FCancel := False;
end;

procedure TFindInFilesThread.CancelSearch;
begin
  FCancel := True;
end;

procedure TFindInFilesThread.Execute;
begin
  SearchInTree(FParams, FResults, @FCancel);
  if not Terminated then
    Synchronize(@DoDone);
end;

procedure TFindInFilesThread.DoDone;
begin
  if Assigned(FOnDone) then
    FOnDone(Self);
end;

end.
