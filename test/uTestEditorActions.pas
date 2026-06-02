// SPDX-License-Identifier: MPL-2.0
unit uTestEditorActions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  uEditorActions;

type

  { TEditorActionsTest — string-fixture vectors for line ops, case, sort, comment. }

  TEditorActionsTest = class(TTestCase)
  private
    function L(const A: array of string): TLines;
    procedure AssertLines(const Msg: string; const Expected: array of string;
      const Got: TLines);
  published
    procedure Duplicate;
    procedure DeleteRange;
    procedure MoveUp;
    procedure MoveDown;
    procedure SortAsc;
    procedure SortDesc;
    procedure Dedup;
    procedure CommentToggleOn;
    procedure CommentToggleOff;
    procedure Indent;
    procedure Outdent;
    procedure TrimTrailing;
    procedure CaseOps;
    procedure CaseTitleVector;
  end;

implementation

function TEditorActionsTest.L(const A: array of string): TLines;
var i: Integer;
begin
  SetLength(Result, Length(A));
  for i := 0 to High(A) do Result[i] := A[i];
end;

procedure TEditorActionsTest.AssertLines(const Msg: string;
  const Expected: array of string; const Got: TLines);
var i: Integer;
begin
  AssertEquals(Msg + ' (count)', Length(Expected), Length(Got));
  for i := 0 to High(Expected) do
    AssertEquals(Format('%s[%d]', [Msg, i]), Expected[i], Got[i]);
end;

procedure TEditorActionsTest.Duplicate;
begin
  AssertLines('dup b', ['a', 'b', 'b', 'c'],
    DuplicateLines(L(['a', 'b', 'c']), 1, 1));
end;

procedure TEditorActionsTest.DeleteRange;
begin
  AssertLines('del 1..2', ['a', 'd'],
    DeleteLines(L(['a', 'b', 'c', 'd']), 1, 2));
end;

procedure TEditorActionsTest.MoveUp;
begin
  AssertLines('move c up', ['a', 'c', 'b'],
    MoveLinesUp(L(['a', 'b', 'c']), 2, 2));
end;

procedure TEditorActionsTest.MoveDown;
begin
  AssertLines('move a down', ['b', 'a', 'c'],
    MoveLinesDown(L(['a', 'b', 'c']), 0, 0));
end;

procedure TEditorActionsTest.SortAsc;
begin
  AssertLines('sort asc', ['a', 'b', 'c'],
    SortLines(L(['b', 'a', 'c']), True, True));
end;

procedure TEditorActionsTest.SortDesc;
begin
  AssertLines('sort desc', ['c', 'b', 'a'],
    SortLines(L(['b', 'a', 'c']), False, True));
end;

procedure TEditorActionsTest.Dedup;
begin
  AssertLines('dedup', ['a', 'b', 'c'],
    RemoveDuplicateLines(L(['a', 'b', 'a', 'c', 'b'])));
end;

procedure TEditorActionsTest.CommentToggleOn;
begin
  AssertLines('comment', ['//x', '//y'],
    ToggleLineComment(L(['x', 'y']), 0, 1, '//'));
end;

procedure TEditorActionsTest.CommentToggleOff;
begin
  AssertLines('uncomment', ['x', 'y'],
    ToggleLineComment(L(['//x', '//y']), 0, 1, '//'));
end;

procedure TEditorActionsTest.Indent;
begin
  AssertLines('indent', ['    a', '    b'],
    IndentLines(L(['a', 'b']), 0, 1, '    '));
end;

procedure TEditorActionsTest.Outdent;
begin
  AssertLines('outdent 4sp', ['a', 'b'],
    OutdentLines(L(['    a', '    b']), 0, 1, 4));
end;

procedure TEditorActionsTest.TrimTrailing;
begin
  AssertEquals('trim', 'a'#10'b'#10'c',
    TrimTrailingWhitespacePerLine('a  '#10'b'#9#10'c'));
end;

procedure TEditorActionsTest.CaseOps;
begin
  AssertEquals('upper', 'HELLO', CaseUpper('Hello'));
  AssertEquals('lower', 'hello', CaseLower('HeLLo'));
end;

procedure TEditorActionsTest.CaseTitleVector;
begin
  AssertEquals('title', 'Hello World Foo', CaseTitle('hello WORLD foo'));
end;

initialization
  RegisterTest(TEditorActionsTest);

end.
