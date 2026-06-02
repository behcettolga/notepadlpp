// SPDX-License-Identifier: MPL-2.0
unit uTestSmoke;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type

  { TSmokeTest — proves the fpcunit + consoletestrunner harness is wired up.
    Real per-unit suites (core/, search/, tools/, editor/) arrive from M1 onward. }

  TSmokeTest = class(TTestCase)
  published
    procedure TestHarnessRuns;
  end;

implementation

procedure TSmokeTest.TestHarnessRuns;
begin
  AssertEquals('fpcunit harness is alive', 4, 2 + 2);
end;

initialization
  RegisterTest(TSmokeTest);

end.
