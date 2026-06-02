// SPDX-License-Identifier: MPL-2.0
unit uFindDialog;

{$mode objfpc}{$H+}

{ Find/Replace dialog for the current document. UI layer (ARCHITECTURE §4).

  Uses ATSynEdit's own TATEditorFinder for the interactive search/replace against
  the live editor — it owns the UTF-8/UnicodeString coordinate mapping, caret
  movement and wrap logic, so we don't reimplement that fragile layer. Our
  uSearchEngine remains the tested core for Find-in-Files. Both are TRegExpr-based
  (kickoff: TRegExpr, ~90% NPP parity).

  Resourceless form (built in code, CreateNew) like the main window. Non-modal so
  the user can keep editing; it always targets whatever tab is currently active. }

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls,
  ATSynEdit, ATSynEdit_Finder, uTabManager;

type

  { TFindDialog }

  TFindDialog = class(TForm)
  private
    FTabs: TTabManager;
    FFinder: TATEditorFinder;
    edFind: TEdit;
    edReplace: TEdit;
    chkCase: TCheckBox;
    chkWord: TCheckBox;
    chkRegex: TCheckBox;
    chkWrap: TCheckBox;
    lblStatus: TLabel;
    function CurrentEditor: TATSynEdit;
    function SyncFinder: Boolean;
    procedure DoFindNext(Sender: TObject);
    procedure DoReplaceOne(Sender: TObject);
    procedure DoReplaceAll(Sender: TObject);
    procedure DoCount(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BuildUI;
  public
    constructor CreateFor(AOwner: TComponent; ATabs: TTabManager);
    procedure ShowFor(AReplaceVisible: Boolean);
  end;

implementation

uses
  LCLType;

constructor TFindDialog.CreateFor(AOwner: TComponent; ATabs: TTabManager);
begin
  inherited CreateNew(AOwner);
  FTabs := ATabs;
  FFinder := TATEditorFinder.Create;
  OnDestroy := @FormDestroy;
  Caption := 'Find / Replace';
  Width := 460;
  Height := 210;
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  BuildUI;
end;

procedure TFindDialog.FormDestroy(Sender: TObject);
begin
  FFinder.Free;
end;

procedure TFindDialog.BuildUI;

  function MkLabel(const ACaption: string; ATop: Integer): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.Left := 12; Result.Top := ATop + 3;
    Result.Caption := ACaption;
  end;

  function MkEdit(ATop: Integer): TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := Self;
    Result.Left := 90; Result.Top := ATop; Result.Width := 250;
  end;

  function MkCheck(const ACaption: string; ALeft, ATop: Integer): TCheckBox;
  begin
    Result := TCheckBox.Create(Self);
    Result.Parent := Self;
    Result.Left := ALeft; Result.Top := ATop; Result.Width := 150;
    Result.Caption := ACaption;
  end;

  function MkButton(const ACaption: string; ATop: Integer; AOnClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Self;
    Result.Left := 350; Result.Top := ATop; Result.Width := 96; Result.Height := 26;
    Result.Caption := ACaption;
    Result.OnClick := AOnClick;
  end;

begin
  MkLabel('Find:', 12);
  edFind := MkEdit(10);
  MkLabel('Replace:', 42);
  edReplace := MkEdit(40);

  chkCase  := MkCheck('Match case', 12, 74);
  chkWord  := MkCheck('Whole word', 12, 96);
  chkRegex := MkCheck('Regular expression', 170, 74);
  chkWrap  := MkCheck('Wrap around', 170, 96);
  chkWrap.Checked := True;

  MkButton('Find Next', 10, @DoFindNext);
  MkButton('Replace', 40, @DoReplaceOne);
  MkButton('Replace All', 70, @DoReplaceAll);
  MkButton('Count', 100, @DoCount);

  lblStatus := TLabel.Create(Self);
  lblStatus.Parent := Self;
  lblStatus.Left := 12; lblStatus.Top := 130; lblStatus.Width := 320;
  lblStatus.Caption := '';
end;

function TFindDialog.CurrentEditor: TATSynEdit;
var t: TEditorTab;
begin
  Result := nil;
  if FTabs = nil then Exit;
  t := FTabs.ActiveTab;
  if t <> nil then Result := t.Editor;
end;

function TFindDialog.SyncFinder: Boolean;
var ed: TATSynEdit;
begin
  ed := CurrentEditor;
  Result := (ed <> nil) and (edFind.Text <> '');
  if not Result then Exit;
  FFinder.Editor := ed;
  FFinder.StrFind := UTF8Decode(edFind.Text);
  FFinder.StrReplace := UTF8Decode(edReplace.Text);
  FFinder.OptCase := chkCase.Checked;
  FFinder.OptWords := chkWord.Checked;
  FFinder.OptRegex := chkRegex.Checked;
  FFinder.OptWrapped := chkWrap.Checked;
  FFinder.OptBack := False;
  FFinder.OptFromCaret := True;
end;

procedure TFindDialog.DoFindNext(Sender: TObject);
var bChanged, ok: Boolean;
begin
  if not SyncFinder then begin lblStatus.Caption := 'Enter text to find.'; Exit; end;
  ok := FFinder.DoAction_FindOrReplace(False, False, bChanged, True);
  if ok then lblStatus.Caption := 'Found.' else lblStatus.Caption := 'Not found.';
end;

procedure TFindDialog.DoReplaceOne(Sender: TObject);
var bChanged, ok: Boolean;
begin
  if not SyncFinder then Exit;
  ok := FFinder.DoAction_FindOrReplace(True, False, bChanged, True);
  if ok then lblStatus.Caption := 'Replaced.' else lblStatus.Caption := 'Not found.';
end;

procedure TFindDialog.DoReplaceAll(Sender: TObject);
var bChanged, ok: Boolean; n: Integer;
begin
  if not SyncFinder then Exit;
  FFinder.OptFromCaret := False;
  FFinder.OptWrapped := False;
  n := 0;
  repeat
    ok := FFinder.DoAction_FindOrReplace(True, True, bChanged, False);
    if ok and bChanged then Inc(n);
  until not ok;
  lblStatus.Caption := Format('Replaced %d occurrence(s).', [n]);
end;

procedure TFindDialog.DoCount(Sender: TObject);
var n: Integer;
begin
  if not SyncFinder then Exit;
  n := FFinder.DoAction_CountAll(False);
  lblStatus.Caption := Format('%d match(es).', [n]);
end;

procedure TFindDialog.ShowFor(AReplaceVisible: Boolean);
begin
  Show;
  edFind.SetFocus;
end;

end.
