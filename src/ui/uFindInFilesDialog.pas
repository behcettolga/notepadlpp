// SPDX-License-Identifier: MPL-2.0
unit uFindInFilesDialog;

{$mode objfpc}{$H+}

{ Find-in-Files dialog. UI layer (ARCHITECTURE §4). Collects pattern, root
  directory, file masks, recursion and search options, then hands a
  TFindInFilesParams to the caller via OnExecute (the main form runs the search
  on a worker thread and fills the results panel). Resourceless code-built form. }

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs,
  uSearchEngine, uFindInFiles;

type
  TFifExecuteEvent = procedure(const AParams: TFindInFilesParams) of object;

  { TFindInFilesDialog }

  TFindInFilesDialog = class(TForm)
  private
    edPattern: TEdit;
    edDir: TEdit;
    edMasks: TEdit;
    chkRecursive: TCheckBox;
    chkCase: TCheckBox;
    chkWord: TCheckBox;
    chkRegex: TCheckBox;
    FOnExecute: TFifExecuteEvent;
    procedure DoBrowse(Sender: TObject);
    procedure DoFindAll(Sender: TObject);
    procedure BuildUI;
  public
    constructor CreateNewDlg(AOwner: TComponent);
    procedure ShowWithDir(const ADir: string);
    property OnExecute: TFifExecuteEvent read FOnExecute write FOnExecute;
  end;

implementation

constructor TFindInFilesDialog.CreateNewDlg(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Find in Files';
  Width := 520;
  Height := 230;
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  BuildUI;
end;

procedure TFindInFilesDialog.BuildUI;

  function MkLabel(const C: string; T: Integer): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self; Result.Left := 12; Result.Top := T + 3; Result.Caption := C;
  end;

  function MkEdit(T, W: Integer): TEdit;
  begin
    Result := TEdit.Create(Self);
    Result.Parent := Self; Result.Left := 90; Result.Top := T; Result.Width := W;
  end;

  function MkCheck(const C: string; L, T: Integer): TCheckBox;
  begin
    Result := TCheckBox.Create(Self);
    Result.Parent := Self; Result.Left := L; Result.Top := T; Result.Width := 150;
    Result.Caption := C;
  end;

var
  btnBrowse, btnFind: TButton;
begin
  MkLabel('Find:', 12);     edPattern := MkEdit(10, 410);
  MkLabel('Directory:', 42); edDir := MkEdit(40, 320);
  btnBrowse := TButton.Create(Self);
  btnBrowse.Parent := Self; btnBrowse.Left := 420; btnBrowse.Top := 39;
  btnBrowse.Width := 80; btnBrowse.Caption := 'Browse...'; btnBrowse.OnClick := @DoBrowse;

  MkLabel('Masks:', 72);    edMasks := MkEdit(70, 410);
  edMasks.Text := '*.*';

  chkRecursive := MkCheck('Recurse subdirectories', 12, 102); chkRecursive.Checked := True;
  chkCase  := MkCheck('Match case', 280, 102);
  chkWord  := MkCheck('Whole word', 12, 126);
  chkRegex := MkCheck('Regular expression', 280, 126);

  btnFind := TButton.Create(Self);
  btnFind.Parent := Self; btnFind.Left := 400; btnFind.Top := 160;
  btnFind.Width := 100; btnFind.Height := 28; btnFind.Caption := 'Find All';
  btnFind.OnClick := @DoFindAll;
end;

procedure TFindInFilesDialog.DoBrowse(Sender: TObject);
var dlg: TSelectDirectoryDialog;
begin
  dlg := TSelectDirectoryDialog.Create(Self);
  try
    if DirectoryExists(edDir.Text) then dlg.InitialDir := edDir.Text;
    if dlg.Execute then edDir.Text := dlg.FileName;
  finally
    dlg.Free;
  end;
end;

procedure TFindInFilesDialog.DoFindAll(Sender: TObject);
var P: TFindInFilesParams;
begin
  if (edPattern.Text = '') or (not DirectoryExists(edDir.Text)) then Exit;
  P.Root := edDir.Text;
  P.Masks := edMasks.Text;
  P.Recursive := chkRecursive.Checked;
  P.Pattern := edPattern.Text;
  P.Options := [];
  if chkCase.Checked then Include(P.Options, soMatchCase);
  if chkWord.Checked then Include(P.Options, soWholeWord);
  if chkRegex.Checked then Include(P.Options, soRegex);
  if Assigned(FOnExecute) then FOnExecute(P);
end;

procedure TFindInFilesDialog.ShowWithDir(const ADir: string);
begin
  if (edDir.Text = '') and (ADir <> '') then edDir.Text := ADir;
  Show;
  edPattern.SetFocus;
end;

end.
