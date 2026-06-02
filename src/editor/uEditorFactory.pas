// SPDX-License-Identifier: MPL-2.0
unit uEditorFactory;

{$mode objfpc}{$H+}

{ Builds a configured TATSynEdit instance. Editor-layer unit (ARCHITECTURE §4):
  centralizes editor look/behaviour so every tab is consistent. Must not depend
  on src/ui. }

interface

uses
  Classes, ATSynEdit;

function CreateEditor(AOwner: TComponent): TATSynEdit;

implementation

function CreateEditor(AOwner: TComponent): TATSynEdit;
begin
  Result := TATSynEdit.Create(AOwner);
  Result.Font.Name := 'Monospace';
  Result.Font.Size := 10;
  Result.OptGutterVisible := True;          // gutter incl. line numbers
  Result.OptRulerVisible := False;          // NPP-like: no top ruler by default
  Result.OptShowCurLine := True;            // highlight the caret's line
  Result.OptWrapMode := TATEditorWrapMode.ModeOff;
  Result.OptUnprintedVisible := False;
  Result.OptUndoLimit := 5000;
end;

end.
