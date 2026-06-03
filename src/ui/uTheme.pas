// SPDX-License-Identifier: MPL-2.0
unit uTheme;

{$mode objfpc}{$H+}

{ Editor color themes — one light, one dark (ARCHITECTURE §3.4, §4). UI-layer:
  applies a color set to a TATSynEdit's public Colors record and repaints. The
  themes are defined in code (the values below); ThemeByName selects between them
  so uConfig can persist just the name string. }

interface

uses
  Graphics, ATSynEdit;

type

  { TEditorTheme — the subset of TATEditorColors we drive. Plain TColors so the
    set is trivially comparable and serializable by name. }

  TEditorTheme = record
    Name: string;                     // 'light' | 'dark'
    TextBG, TextFont: TColor;
    TextSelBG, TextSelFont: TColor;
    Caret: TColor;
    GutterBG, GutterFont: TColor;
    GutterCaretBG, GutterCaretFont: TColor;
    CurrentLineBG: TColor;
  end;

function LightTheme: TEditorTheme;
function DarkTheme: TEditorTheme;
// ThemeByName returns DarkTheme for 'dark' (case-insensitive), else LightTheme.
function ThemeByName(const AName: string): TEditorTheme;
// ApplyTheme writes the colors into the editor and repaints it.
procedure ApplyTheme(AEditor: TATSynEdit; const ATheme: TEditorTheme);

implementation

uses
  SysUtils;

function LightTheme: TEditorTheme;
begin
  Result.Name := 'light';
  Result.TextBG := clWhite;
  Result.TextFont := TColor($202020);          // near-black
  Result.TextSelBG := TColor($F0D090);         // soft blue selection (BGR)
  Result.TextSelFont := clBlack;
  Result.Caret := clBlack;
  Result.GutterBG := TColor($F5F5F5);
  Result.GutterFont := TColor($909090);
  Result.GutterCaretBG := TColor($E8E8E8);
  Result.GutterCaretFont := TColor($404040);
  Result.CurrentLineBG := TColor($F5F0E8);
end;

function DarkTheme: TEditorTheme;
begin
  Result.Name := 'dark';
  Result.TextBG := TColor($2B2B2B);            // BGR: dark grey
  Result.TextFont := TColor($DCDCDC);          // light grey text
  Result.TextSelBG := TColor($785828);         // muted blue selection
  Result.TextSelFont := clWhite;
  Result.Caret := clWhite;
  Result.GutterBG := TColor($333333);
  Result.GutterFont := TColor($808080);
  Result.GutterCaretBG := TColor($454545);
  Result.GutterCaretFont := TColor($D0D0D0);
  Result.CurrentLineBG := TColor($3A3A3A);
end;

function ThemeByName(const AName: string): TEditorTheme;
begin
  if SameText(AName, 'dark') then
    Result := DarkTheme
  else
    Result := LightTheme;
end;

procedure ApplyTheme(AEditor: TATSynEdit; const ATheme: TEditorTheme);
begin
  if AEditor = nil then Exit;
  AEditor.Colors.TextBG := ATheme.TextBG;
  AEditor.Colors.TextFont := ATheme.TextFont;
  AEditor.Colors.TextSelBG := ATheme.TextSelBG;
  AEditor.Colors.TextSelFont := ATheme.TextSelFont;
  AEditor.Colors.Caret := ATheme.Caret;
  AEditor.Colors.GutterBG := ATheme.GutterBG;
  AEditor.Colors.GutterFont := ATheme.GutterFont;
  AEditor.Colors.GutterCaretBG := ATheme.GutterCaretBG;
  AEditor.Colors.GutterCaretFont := ATheme.GutterCaretFont;
  AEditor.Colors.CurrentLineBG := ATheme.CurrentLineBG;
  AEditor.Update(True);
end;

end.
