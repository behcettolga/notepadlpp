// SPDX-License-Identifier: MPL-2.0
unit uMainForm;

{$mode objfpc}{$H+}

{ Main window: menu bar + tabbed editor host. UI-layer (ARCHITECTURE §4).
  M1 scope: New/Open/Save/Save As/Reload/Recent/Close, multi-tab editing with
  line numbers and EControl syntax highlighting. Status bar + full UX are M3. }

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, ExtCtrls, Menus, ComCtrls, Dialogs,
  uDocumentManager, uLexers, uTabManager, uDocument, uFindDialog,
  uFindResultsPanel, uFindInFilesDialog, uFindInFiles, uSearchResults;

const
  MaxRecent = 10;

type

  { TMainForm }

  { TMainForm is built entirely in code (no .lfm), so it is created resourceless
    via CreateNew — avoids any LFM-resource lookup. }
  TMainForm = class(TForm)
  private
    FDocs: TDocumentManager;
    FLexers: TLexerLibrary;
    FPages: TPageControl;
    FTabs: TTabManager;
    FMenu: TMainMenu;
    FRecentMenu: TMenuItem;
    FRecent: TStringList;
    FFindDlg: TFindDialog;
    FResultsHost: TPanel;
    FResults: TFindResultsPanel;
    FFifDlg: TFindInFilesDialog;
    FFifData: TSearchResults;
    FFifThread: TFindInFilesThread;
    FFifPattern: string;
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure OpenCommandLineFiles;
    procedure BuildMenu;
    function AddItem(AParent: TMenuItem; const ACaption: string;
      AOnClick: TNotifyEvent; const AShortcut: string = ''): TMenuItem;
    procedure DoNew(Sender: TObject);
    procedure DoOpen(Sender: TObject);
    procedure DoSave(Sender: TObject);
    procedure DoSaveAs(Sender: TObject);
    procedure DoReload(Sender: TObject);
    procedure DoCloseTab(Sender: TObject);
    procedure DoExit(Sender: TObject);
    procedure DoFindReplace(Sender: TObject);
    procedure DoFindInFiles(Sender: TObject);
    procedure RunFindInFiles(const AParams: TFindInFilesParams);
    procedure FifDone(Sender: TObject);
    procedure JumpToResult(const AFileName: string; ALine, ACol: Integer);
    procedure DoRecentClick(Sender: TObject);
    procedure PagesChange(Sender: TObject);
    procedure TabsState(Sender: TObject);
    function SaveActive(ASaveAs: Boolean): Boolean;
    procedure AddRecent(const AFileName: string);
    procedure RebuildRecentMenu;
    procedure UpdateTitle;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  MainForm: TMainForm;

implementation

uses
  LCLType, LCLProc;

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner); // resourceless: UI is built below in code
  OnDestroy := @FormDestroy;
  OnCloseQuery := @FormCloseQuery;

  Caption := 'NotepadL++';
  Width := 1000;
  Height := 680;
  Position := poScreenCenter;

  FRecent := TStringList.Create;

  FDocs := TDocumentManager.Create;

  FLexers := TLexerLibrary.Create;
  FLexers.LoadFromFile(DefaultLexerLibFile); // silent if missing; editor still works

  // Find-in-Files results dock at the bottom (hidden until first search)
  FResultsHost := TPanel.Create(Self);
  FResultsHost.Parent := Self;
  FResultsHost.Align := alBottom;
  FResultsHost.Height := 170;
  FResultsHost.BevelOuter := bvNone;
  FResultsHost.Visible := False;
  FResults := TFindResultsPanel.Create(FResultsHost);
  FResults.OnJump := @JumpToResult;

  FPages := TPageControl.Create(Self);
  FPages.Parent := Self;
  FPages.Align := alClient;
  FPages.OnChange := @PagesChange;

  FTabs := TTabManager.Create(FPages, FDocs, FLexers);
  FTabs.OnState := @TabsState;

  BuildMenu;

  OpenCommandLineFiles; // opens files passed as arguments; else one empty tab
  UpdateTitle;
end;

procedure TMainForm.OpenCommandLineFiles;
var
  i, opened: Integer;
  fn: string;
begin
  opened := 0;
  for i := 1 to ParamCount do
  begin
    fn := ParamStr(i);
    if (fn <> '') and (fn[1] <> '-') and FileExists(fn) then
    begin
      FTabs.OpenFileInTab(ExpandFileName(fn));
      AddRecent(ExpandFileName(fn));
      Inc(opened);
    end;
  end;
  if opened = 0 then
    FTabs.NewTab; // start with one empty document
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if FFifThread <> nil then
  begin
    FFifThread.CancelSearch;
    FFifThread.WaitFor;
    FreeAndNil(FFifThread);
  end;
  FFifData.Free;
  FResults.Free;
  FTabs.Free;
  FLexers.Free;
  FDocs.Free;
  FRecent.Free;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FDocs.HasModified then
    CanClose := MessageDlg('NotepadL++',
      'There are unsaved changes. Close anyway?',
      mtConfirmation, [mbYes, mbNo], 0) = mrYes
  else
    CanClose := True;
end;

function TMainForm.AddItem(AParent: TMenuItem; const ACaption: string;
  AOnClick: TNotifyEvent; const AShortcut: string): TMenuItem;
begin
  Result := TMenuItem.Create(FMenu);
  Result.Caption := ACaption;
  Result.OnClick := AOnClick;
  if AShortcut <> '' then
    Result.ShortCut := TextToShortCut(AShortcut);
  AParent.Add(Result);
end;

procedure TMainForm.BuildMenu;
var
  fileMenu, searchMenu, sep: TMenuItem;
begin
  FMenu := TMainMenu.Create(Self);
  Self.Menu := FMenu;

  fileMenu := TMenuItem.Create(FMenu);
  fileMenu.Caption := '&File';
  FMenu.Items.Add(fileMenu);

  AddItem(fileMenu, '&New', @DoNew, 'Ctrl+N');
  AddItem(fileMenu, '&Open...', @DoOpen, 'Ctrl+O');
  AddItem(fileMenu, '&Save', @DoSave, 'Ctrl+S');
  AddItem(fileMenu, 'Save &As...', @DoSaveAs, 'Ctrl+Shift+S');
  AddItem(fileMenu, '&Reload from Disk', @DoReload);

  sep := TMenuItem.Create(FMenu); sep.Caption := '-'; fileMenu.Add(sep);

  FRecentMenu := TMenuItem.Create(FMenu);
  FRecentMenu.Caption := 'Recent Files';
  fileMenu.Add(FRecentMenu);
  RebuildRecentMenu;

  sep := TMenuItem.Create(FMenu); sep.Caption := '-'; fileMenu.Add(sep);

  AddItem(fileMenu, '&Close Tab', @DoCloseTab, 'Ctrl+W');
  AddItem(fileMenu, 'E&xit', @DoExit, 'Ctrl+Q');

  searchMenu := TMenuItem.Create(FMenu);
  searchMenu.Caption := '&Search';
  FMenu.Items.Add(searchMenu);
  AddItem(searchMenu, '&Find...', @DoFindReplace, 'Ctrl+F');
  AddItem(searchMenu, '&Replace...', @DoFindReplace, 'Ctrl+H');
  AddItem(searchMenu, 'Find in &Files...', @DoFindInFiles, 'Ctrl+Shift+F');
end;

procedure TMainForm.DoNew(Sender: TObject);
begin
  FTabs.NewTab;
  UpdateTitle;
end;

procedure TMainForm.DoOpen(Sender: TObject);
var
  dlg: TOpenDialog;
begin
  dlg := TOpenDialog.Create(Self);
  try
    dlg.Options := dlg.Options + [ofFileMustExist];
    if dlg.Execute then
    begin
      FTabs.OpenFileInTab(dlg.FileName);
      AddRecent(dlg.FileName);
      UpdateTitle;
    end;
  finally
    dlg.Free;
  end;
end;

function TMainForm.SaveActive(ASaveAs: Boolean): Boolean;
var
  tab: TEditorTab;
  dlg: TSaveDialog;
begin
  Result := False;
  tab := FTabs.ActiveTab;
  if tab = nil then Exit;

  FTabs.SyncActiveEditorToDoc; // editor text -> doc.TextLF

  if ASaveAs or tab.Doc.Untitled then
  begin
    dlg := TSaveDialog.Create(Self);
    try
      dlg.Options := dlg.Options + [ofOverwritePrompt];
      if not tab.Doc.Untitled then
        dlg.FileName := tab.Doc.FilePath;
      if not dlg.Execute then Exit;
      tab.Doc.SaveToFile(dlg.FileName);
      AddRecent(dlg.FileName);
      FTabs.RefreshActiveLexer; // filename now known -> apply lexer + caption
    finally
      dlg.Free;
    end;
  end
  else
    tab.Doc.Save;

  FTabs.UpdateCaption(tab);
  UpdateTitle;
  Result := True;
end;

procedure TMainForm.DoSave(Sender: TObject);
begin
  SaveActive(False);
end;

procedure TMainForm.DoSaveAs(Sender: TObject);
begin
  SaveActive(True);
end;

procedure TMainForm.DoReload(Sender: TObject);
var tab: TEditorTab;
begin
  tab := FTabs.ActiveTab;
  if (tab = nil) or tab.Doc.Untitled then Exit;
  if tab.Doc.Modified then
    if MessageDlg('NotepadL++', 'Discard unsaved changes and reload from disk?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FTabs.ReloadActive;
  UpdateTitle;
end;

procedure TMainForm.DoCloseTab(Sender: TObject);
var tab: TEditorTab;
begin
  tab := FTabs.ActiveTab;
  if tab = nil then Exit;
  if tab.Doc.Modified then
    if MessageDlg('NotepadL++', 'Close tab with unsaved changes?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  FTabs.CloseActiveTab;
  if FDocs.Count = 0 then
    FTabs.NewTab; // never leave the window with zero tabs
  UpdateTitle;
end;

procedure TMainForm.DoExit(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.DoFindReplace(Sender: TObject);
begin
  if FFindDlg = nil then
    FFindDlg := TFindDialog.CreateFor(Self, FTabs);
  FFindDlg.ShowFor(True);
end;

procedure TMainForm.DoFindInFiles(Sender: TObject);
var
  startDir: string;
  tab: TEditorTab;
begin
  if FFifDlg = nil then
  begin
    FFifDlg := TFindInFilesDialog.CreateNewDlg(Self);
    FFifDlg.OnExecute := @RunFindInFiles;
  end;
  startDir := '';
  tab := FTabs.ActiveTab;
  if (tab <> nil) and (not tab.Doc.Untitled) then
    startDir := ExtractFileDir(tab.Doc.FilePath);
  FFifDlg.ShowWithDir(startDir);
end;

procedure TMainForm.RunFindInFiles(const AParams: TFindInFilesParams);
begin
  // finish/cleanup any prior search
  if FFifThread <> nil then
  begin
    FFifThread.CancelSearch;
    FFifThread.WaitFor;
    FreeAndNil(FFifThread);
  end;
  FreeAndNil(FFifData);

  FFifData := TSearchResults.Create;
  FFifPattern := AParams.Pattern;
  FResultsHost.Visible := True;
  FFifThread := TFindInFilesThread.Create(AParams, FFifData, @FifDone);
  FFifThread.Start;
end;

procedure TMainForm.FifDone(Sender: TObject);
begin
  // runs on the main thread (Synchronize) when the worker finishes
  FResults.ShowResults(FFifData, FFifPattern);
end;

procedure TMainForm.JumpToResult(const AFileName: string; ALine, ACol: Integer);
begin
  FTabs.OpenFileInTab(AFileName);
  FTabs.GotoLineCol(ALine, ACol);
  UpdateTitle;
end;

procedure TMainForm.DoRecentClick(Sender: TObject);
var fn: string;
begin
  fn := (Sender as TMenuItem).Hint;
  if FileExists(fn) then
  begin
    FTabs.OpenFileInTab(fn);
    AddRecent(fn);
    UpdateTitle;
  end;
end;

procedure TMainForm.PagesChange(Sender: TObject);
begin
  FTabs.PageChanged;
  UpdateTitle;
end;

procedure TMainForm.TabsState(Sender: TObject);
begin
  UpdateTitle;
end;

procedure TMainForm.AddRecent(const AFileName: string);
var idx: Integer;
begin
  idx := FRecent.IndexOf(AFileName);
  if idx >= 0 then FRecent.Delete(idx);
  FRecent.Insert(0, AFileName);
  while FRecent.Count > MaxRecent do
    FRecent.Delete(FRecent.Count - 1);
  RebuildRecentMenu;
end;

procedure TMainForm.RebuildRecentMenu;
var
  i: Integer;
  mi: TMenuItem;
begin
  if FRecentMenu = nil then Exit;
  FRecentMenu.Clear;
  FRecentMenu.Enabled := FRecent.Count > 0;
  for i := 0 to FRecent.Count - 1 do
  begin
    mi := TMenuItem.Create(FMenu);
    mi.Caption := ExtractFileName(FRecent[i]) + '  (' + FRecent[i] + ')';
    mi.Hint := FRecent[i];
    mi.OnClick := @DoRecentClick;
    FRecentMenu.Add(mi);
  end;
end;

procedure TMainForm.UpdateTitle;
var tab: TEditorTab;
begin
  tab := FTabs.ActiveTab;
  if tab = nil then
    Caption := 'NotepadL++'
  else
    Caption := tab.Doc.DisplayName +
      IfThen(tab.Doc.Modified, ' *', '') + ' - NotepadL++';
end;

end.
