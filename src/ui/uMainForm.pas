// SPDX-License-Identifier: MPL-2.0
unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls,
  ATSynEdit;

type

  { TMainForm }

  TMainForm = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    FEditor: TATSynEdit;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  // M0: a blank main window that hosts a TATSynEdit and shows text.
  // The editor is created in code (not the .lfm) so M0 carries no IDE-registered
  // custom component dependency. Real editor configuration lands via uEditorFactory in M1.
  FEditor := TATSynEdit.Create(Self);
  FEditor.Parent := Self;
  FEditor.Align := alClient;
  FEditor.Text :=
    'NotepadL++ - M0 skeleton.' + LineEnding +
    'A TATSynEdit is hosted in the main window and showing this text.';
end;

end.
