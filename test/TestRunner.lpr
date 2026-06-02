// SPDX-License-Identifier: MPL-2.0
program TestRunner;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, consoletestrunner,
  uTestSmoke,
  uTestEncoding,
  uTestFileIO,
  uTestDocument,
  uTestSearch,
  uTestFindInFiles,
  uTestEditorActions,
  uTestConverters;

var
  App: TTestRunner;

begin
  App := TTestRunner.Create(nil);
  try
    App.Initialize;
    App.Title := 'NotepadL++ test runner';
    App.Run;
  finally
    App.Free;
  end;
end.
