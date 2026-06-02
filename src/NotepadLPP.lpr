// SPDX-License-Identifier: MPL-2.0
program NotepadLPP;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // LCL widgetset
  Forms,
  uMainForm;

{$R *.res}

begin
  // TMainForm is resourceless (built in code, created via CreateNew), so we do
  // not require derived-form .lfm resources.
  Application.Title := 'NotepadL++';
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
