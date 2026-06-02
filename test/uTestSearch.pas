// SPDX-License-Identifier: MPL-2.0
unit uTestSearch;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  uSearchEngine;

type

  { TSearchEngineTest — explicit vectors for plain/case/word/regex find, count,
    wrap, and replace-all. }

  TSearchEngineTest = class(TTestCase)
  published
    procedure PlainCaseInsensitive;
    procedure PlainCaseSensitive;
    procedure WholeWord;
    procedure CountAll;
    procedure FindNextFromPos;
    procedure FindNextWrap;
    procedure NoMatch;
    procedure RegexDigits;
    procedure RegexCaseInsensitive;
    procedure ReplaceAllPlain;
    procedure ReplaceAllCount;
    procedure RegexReplaceWithGroup;
    procedure EmptyPatternSafe;
  end;

implementation

procedure TSearchEngineTest.PlainCaseInsensitive;
var m: TSearchMatch;
begin
  // "Foo foo FOO", find "foo" case-insensitive -> first at pos 1
  AssertTrue('found', FindNext('Foo foo FOO', 'foo', 1, [], False, m));
  AssertEquals('start', 1, m.Start);
  AssertEquals('len', 3, m.Length);
end;

procedure TSearchEngineTest.PlainCaseSensitive;
var m: TSearchMatch;
begin
  // case-sensitive "foo" -> skips "Foo", matches at pos 5
  AssertTrue('found', FindNext('Foo foo FOO', 'foo', 1, [soMatchCase], False, m));
  AssertEquals('start', 5, m.Start);
end;

procedure TSearchEngineTest.WholeWord;
var m: TSearchMatch;
begin
  // "cat catalog cat" find whole-word "cat": pos 1 and 13, not inside "catalog"
  AssertTrue('found', FindNext('cat catalog cat', 'cat', 1, [soWholeWord], False, m));
  AssertEquals('first whole word', 1, m.Start);
  AssertTrue('next whole word', FindNext('cat catalog cat', 'cat', 2, [soWholeWord], False, m));
  AssertEquals('skips catalog', 13, m.Start);
end;

procedure TSearchEngineTest.CountAll;
begin
  AssertEquals('count ci', 3, CountMatches('Foo foo FOO', 'foo', []));
  AssertEquals('count cs', 1, CountMatches('Foo foo FOO', 'foo', [soMatchCase]));
  AssertEquals('count word', 2, CountMatches('cat catalog cat', 'cat', [soWholeWord]));
end;

procedure TSearchEngineTest.FindNextFromPos;
var m: TSearchMatch;
begin
  AssertTrue('found from 2', FindNext('abcabc', 'abc', 2, [], False, m));
  AssertEquals('second occurrence', 4, m.Start);
end;

procedure TSearchEngineTest.FindNextWrap;
var m: TSearchMatch;
begin
  // from past the end, no wrap -> not found; with wrap -> first match
  AssertFalse('no wrap past end', FindNext('abcabc', 'abc', 5, [], False, m));
  AssertTrue('wrap finds first', FindNext('abcabc', 'abc', 5, [], True, m));
  AssertEquals('wrapped to 1', 1, m.Start);
end;

procedure TSearchEngineTest.NoMatch;
var m: TSearchMatch;
begin
  AssertFalse('absent', FindNext('hello', 'xyz', 1, [], True, m));
end;

procedure TSearchEngineTest.RegexDigits;
var m: TSearchMatch;
begin
  AssertTrue('regex found', FindNext('abc123def', '\d+', 1, [soRegex], False, m));
  AssertEquals('start', 4, m.Start);
  AssertEquals('len', 3, m.Length);
end;

procedure TSearchEngineTest.RegexCaseInsensitive;
begin
  AssertEquals('ci regex count', 2, CountMatches('Hello hello', 'hello', [soRegex]));
  AssertEquals('cs regex count', 1, CountMatches('Hello hello', 'hello', [soRegex, soMatchCase]));
end;

procedure TSearchEngineTest.ReplaceAllPlain;
var n: Integer;
begin
  AssertEquals('replaced text', 'X X X',
    ReplaceAll('a a a', 'a', 'X', [], n));
  AssertEquals('count', 3, n);
end;

procedure TSearchEngineTest.ReplaceAllCount;
var n: Integer; s: string;
begin
  s := ReplaceAll('one two one', 'one', 'three', [], n);
  AssertEquals('text', 'three two three', s);
  AssertEquals('n', 2, n);
end;

procedure TSearchEngineTest.RegexReplaceWithGroup;
var n: Integer; s: string;
begin
  // swap "key=value" -> "value=key" using groups
  s := ReplaceAll('a=1', '(\w+)=(\w+)', '$2=$1', [soRegex], n);
  AssertEquals('grouped replace', '1=a', s);
  AssertEquals('n', 1, n);
end;

procedure TSearchEngineTest.EmptyPatternSafe;
var n: Integer;
begin
  AssertEquals('count empty', 0, CountMatches('abc', '', []));
  AssertEquals('replace empty no-op', 'abc', ReplaceAll('abc', '', 'X', [], n));
  AssertEquals('n zero', 0, n);
end;

initialization
  RegisterTest(TSearchEngineTest);

end.
