// SPDX-License-Identifier: MPL-2.0
unit uLexers;

{$mode objfpc}{$H+}

{ EControl lexer library wrapper. Editor-layer unit (ARCHITECTURE §4): may depend
  on ATSynEdit/EControl, must NOT depend on src/ui.

  Wraps TecSyntaxManager loaded from a single bundled lexer library (lexers/lib.lxl).
  Provides ext->lexer resolution via the upstream Lexer_FindForFilename. The curated
  Phase 1 set that this library covers: JSON, XML, HTML, CSS, JavaScript, INI, Bash,
  Python, C, C++, Markdown. (SQL, YAML, Diff, Log are a post-M1 "wire more lexers"
  task per spec §3.3 — see HUMAN-REVIEW.md.) }

interface

uses
  Classes, SysUtils,
  ec_SyntAnal, ec_proc_lexer;

type

  { TLexerLibrary }

  TLexerLibrary = class
  private
    FManager: TecSyntaxManager;
    FLoaded: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function LoadFromFile(const AFileName: string): Boolean;
    function LexerForFileName(const AFileName: string): TecSyntAnalyzer;
    function LexerByName(const AName: string): TecSyntAnalyzer;
    function LexerNames: TStringArray;
    property Manager: TecSyntaxManager read FManager;
    property Loaded: Boolean read FLoaded;
  end;

{ Resolve the bundled lexers/lib.lxl: prefer one next to the executable, then a
  repo-relative path (running from a build tree). Returns '' if none found. }
function DefaultLexerLibFile: string;

implementation

uses
  Forms;

constructor TLexerLibrary.Create;
begin
  inherited Create;
  FManager := TecSyntaxManager.Create(nil);
  FLoaded := False;
end;

destructor TLexerLibrary.Destroy;
begin
  FManager.Free;
  inherited Destroy;
end;

function TLexerLibrary.LoadFromFile(const AFileName: string): Boolean;
begin
  Result := False;
  if (AFileName = '') or (not FileExists(AFileName)) then
    Exit;
  FManager.Clear;
  FManager.LoadFromFile(AFileName);
  FLoaded := FManager.AnalyzerCount > 0;
  Result := FLoaded;
end;

function TLexerLibrary.LexerForFileName(const AFileName: string): TecSyntAnalyzer;
begin
  if not FLoaded then
    Exit(nil);
  Result := Lexer_FindForFilename(FManager, AFileName);
end;

function TLexerLibrary.LexerByName(const AName: string): TecSyntAnalyzer;
begin
  if not FLoaded then
    Exit(nil);
  Result := FManager.FindAnalyzer(AName);
end;

function TLexerLibrary.LexerNames: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, FManager.AnalyzerCount);
  for i := 0 to FManager.AnalyzerCount - 1 do
    Result[i] := FManager.Analyzers[i].LexerName;
end;

function DefaultLexerLibFile: string;
var
  exeDir, cand: string;
begin
  exeDir := ExtractFilePath(Application.ExeName);
  cand := exeDir + 'lexers' + PathDelim + 'lib.lxl';
  if FileExists(cand) then Exit(cand);
  cand := exeDir + 'lib.lxl';
  if FileExists(cand) then Exit(cand);
  // running from build tree: <repo>/notepadlpp lives at repo root, lexers/ beside it
  cand := exeDir + '..' + PathDelim + 'lexers' + PathDelim + 'lib.lxl';
  if FileExists(cand) then Exit(cand);
  // FHS install (and AppImage AppDir): /usr/bin/notepadlpp -> /usr/share/notepadlpp/lexers
  cand := exeDir + '..' + PathDelim + 'share' + PathDelim + 'notepadlpp' +
          PathDelim + 'lexers' + PathDelim + 'lib.lxl';
  if FileExists(cand) then Exit(cand);
  cand := '/usr/share/notepadlpp/lexers/lib.lxl';
  if FileExists(cand) then Exit(cand);
  Result := '';
end;

end.
