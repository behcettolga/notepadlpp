// SPDX-License-Identifier: MPL-2.0
unit uMainForm;

{$mode objfpc}{$H+}

{ Main window: menu bar + tabbed editor host. UI-layer (ARCHITECTURE §4).
  M1 scope: New/Open/Save/Save As/Reload/Recent/Close, multi-tab editing with
  line numbers and EControl syntax highlighting. Status bar + full UX are M3. }

interface

uses
  Classes, SysUtils, StrUtils, Forms, Controls, ExtCtrls, Menus, ComCtrls, Dialogs,
  uDocumentManager, uLexers, uTabManager, uDocument, uEncoding, uEditorActions,
  uFindDialog, uFindResultsPanel, uFindInFilesDialog, uFindInFiles, uSearchResults,
  uJsonTool, uXmlTool, uConvertersDlg, uCsvViewer;

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
    FStatus: TStatusBar;
    FConvDlg: TConvertersDlg;
    FCsvViewer: TCsvViewer;
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
    procedure BuildStatusBar;
    procedure UpdateStatus(Sender: TObject);
    procedure StatusMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ApplyLineAction(AWholeDoc: Boolean; AAction: Integer);
    procedure DoEditAction(Sender: TObject);
    procedure SetEncoding(Sender: TObject);
    procedure SetEol(Sender: TObject);
    procedure DoJsonPretty(Sender: TObject);
    procedure DoJsonMinify(Sender: TObject);
    procedure DoJsonValidate(Sender: TObject);
    procedure DoXmlFormat(Sender: TObject);
    procedure DoXmlValidate(Sender: TObject);
    procedure DoCsvView(Sender: TObject);
    procedure DoConverters(Sender: TObject);
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

  // Status bar first (alBottom) so it claims the bottom before alClient fills.
  BuildStatusBar;

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
  FTabs.OnCaretMove := @UpdateStatus;

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
  fileMenu, editMenu, searchMenu, toolsMenu, sep: TMenuItem;
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

  editMenu := TMenuItem.Create(FMenu);
  editMenu.Caption := '&Edit';
  FMenu.Items.Add(editMenu);
  // Tag encodes the action id consumed by DoEditAction.
  AddItem(editMenu, '&Duplicate Line', @DoEditAction, 'Ctrl+D').Tag := 1;
  AddItem(editMenu, 'De&lete Line', @DoEditAction, 'Ctrl+Shift+L').Tag := 2;
  AddItem(editMenu, 'Move Line &Up', @DoEditAction, 'Ctrl+Shift+Up').Tag := 3;
  AddItem(editMenu, 'Move Line Dow&n', @DoEditAction, 'Ctrl+Shift+Down').Tag := 4;
  sep := TMenuItem.Create(FMenu); sep.Caption := '-'; editMenu.Add(sep);
  AddItem(editMenu, '&Sort Lines (Asc)', @DoEditAction).Tag := 5;
  AddItem(editMenu, 'Sort Lines (&Desc)', @DoEditAction).Tag := 6;
  AddItem(editMenu, '&Remove Duplicate Lines', @DoEditAction).Tag := 7;
  AddItem(editMenu, '&Trim Trailing Whitespace', @DoEditAction).Tag := 8;
  sep := TMenuItem.Create(FMenu); sep.Caption := '-'; editMenu.Add(sep);
  AddItem(editMenu, 'UPPER&CASE', @DoEditAction).Tag := 9;
  AddItem(editMenu, 'lo&wercase', @DoEditAction).Tag := 10;
  AddItem(editMenu, 'Title &Case', @DoEditAction).Tag := 11;
  sep := TMenuItem.Create(FMenu); sep.Caption := '-'; editMenu.Add(sep);
  AddItem(editMenu, 'Toggle Bloc&k Comment (//)', @DoEditAction, 'Ctrl+/').Tag := 12;
  AddItem(editMenu, '&Indent', @DoEditAction).Tag := 13;
  AddItem(editMenu, '&Outdent', @DoEditAction).Tag := 14;

  searchMenu := TMenuItem.Create(FMenu);
  searchMenu.Caption := '&Search';
  FMenu.Items.Add(searchMenu);
  AddItem(searchMenu, '&Find...', @DoFindReplace, 'Ctrl+F');
  AddItem(searchMenu, '&Replace...', @DoFindReplace, 'Ctrl+H');
  AddItem(searchMenu, 'Find in &Files...', @DoFindInFiles, 'Ctrl+Shift+F');

  toolsMenu := TMenuItem.Create(FMenu);
  toolsMenu.Caption := '&Tools';
  FMenu.Items.Add(toolsMenu);
  AddItem(toolsMenu, 'JSON: &Pretty-print', @DoJsonPretty);
  AddItem(toolsMenu, 'JSON: &Minify', @DoJsonMinify);
  AddItem(toolsMenu, 'JSON: &Validate', @DoJsonValidate);
  sep := TMenuItem.Create(FMenu); sep.Caption := '-'; toolsMenu.Add(sep);
  AddItem(toolsMenu, 'XML: &Format', @DoXmlFormat);
  AddItem(toolsMenu, 'XML: V&alidate', @DoXmlValidate);
  sep := TMenuItem.Create(FMenu); sep.Caption := '-'; toolsMenu.Add(sep);
  AddItem(toolsMenu, 'View as &CSV Grid...', @DoCsvView);
  AddItem(toolsMenu, '&Converters...', @DoConverters);
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

procedure TMainForm.BuildStatusBar;
  procedure AddPanel(AWidth: Integer);
  begin
    with FStatus.Panels.Add do Width := AWidth;
  end;
begin
  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := False;
  AddPanel(160); // caret line/col
  AddPanel(110); // selection
  AddPanel(110); // total lines
  AddPanel(140); // encoding (clickable)
  AddPanel(70);  // EOL (clickable)
  AddPanel(160); // language
  FStatus.OnMouseDown := @StatusMouseDown;
end;

procedure TMainForm.UpdateStatus(Sender: TObject);
var
  ln, col, selc, total: Integer;
  doc: TDocument;
begin
  if (FStatus = nil) or (FTabs = nil) then Exit;
  if FTabs.ActiveCaretInfo(ln, col, selc, total) then
  begin
    FStatus.Panels[0].Text := Format('Ln %d, Col %d', [ln, col]);
    if selc > 0 then
      FStatus.Panels[1].Text := Format('Sel %d', [selc])
    else
      FStatus.Panels[1].Text := '';
    FStatus.Panels[2].Text := Format('%d lines', [total]);
  end;
  doc := FDocs.Active;
  if doc <> nil then
  begin
    FStatus.Panels[3].Text := uEncoding.EncodingName(doc.Encoding);
    FStatus.Panels[4].Text := LineEndingKindName(doc.LineEnding);
  end;
  FStatus.Panels[5].Text := FTabs.ActiveLexerName;
end;

procedure TMainForm.StatusMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  i, acc: Integer;
  panelIdx: Integer;
  pm: TPopupMenu;
  mi: TMenuItem;
  enc: TFileEncoding;
  eol: TLineEndingKind;
begin
  // determine which panel was clicked from X + accumulated widths
  acc := 0; panelIdx := -1;
  for i := 0 to FStatus.Panels.Count - 1 do
  begin
    Inc(acc, FStatus.Panels[i].Width);
    if X < acc then begin panelIdx := i; Break; end;
  end;
  if FDocs.Active = nil then Exit;

  if panelIdx = 3 then // encoding
  begin
    pm := TPopupMenu.Create(Self);
    for enc := Low(TFileEncoding) to High(TFileEncoding) do
    begin
      mi := TMenuItem.Create(pm);
      mi.Caption := uEncoding.EncodingName(enc);
      mi.Tag := Ord(enc);
      mi.OnClick := @SetEncoding;
      pm.Items.Add(mi);
    end;
    pm.PopUp;
  end
  else if panelIdx = 4 then // EOL
  begin
    pm := TPopupMenu.Create(Self);
    for eol := Low(TLineEndingKind) to High(TLineEndingKind) do
    begin
      mi := TMenuItem.Create(pm);
      mi.Caption := LineEndingKindName(eol);
      mi.Tag := Ord(eol);
      mi.OnClick := @SetEol;
      pm.Items.Add(mi);
    end;
    pm.PopUp;
  end;
end;

procedure TMainForm.SetEncoding(Sender: TObject);
var doc: TDocument;
begin
  doc := FDocs.Active;
  if doc <> nil then
  begin
    doc.Encoding := TFileEncoding((Sender as TMenuItem).Tag);
    FTabs.UpdateCaption(FTabs.ActiveTab);
    UpdateStatus(Sender);
    UpdateTitle;
  end;
end;

procedure TMainForm.SetEol(Sender: TObject);
var doc: TDocument;
begin
  doc := FDocs.Active;
  if doc <> nil then
  begin
    doc.LineEnding := TLineEndingKind((Sender as TMenuItem).Tag);
    FTabs.UpdateCaption(FTabs.ActiveTab);
    UpdateStatus(Sender);
    UpdateTitle;
  end;
end;

procedure TMainForm.ApplyLineAction(AWholeDoc: Boolean; AAction: Integer);
var
  lines: TLines;
  af, at_: Integer;
  srcText: string;
begin
  if FTabs.ActiveTab = nil then Exit;
  srcText := FTabs.ActiveTextLF;
  lines := srcText.Split([#10]);
  if not FTabs.ActiveSelLineRange(af, at_) then begin af := 0; at_ := 0; end;

  case AAction of
    1: lines := DuplicateLines(lines, af, at_);
    2: lines := DeleteLines(lines, af, at_);
    3: lines := MoveLinesUp(lines, af, at_);
    4: lines := MoveLinesDown(lines, af, at_);
    5: lines := SortLines(lines, True, True);
    6: lines := SortLines(lines, False, True);
    7: lines := RemoveDuplicateLines(lines);
    12: lines := ToggleLineComment(lines, af, at_, '//');
    13: lines := IndentLines(lines, af, at_, '    ');
    14: lines := OutdentLines(lines, af, at_, 4);
  end;
  FTabs.SetActiveTextLF(string.Join(#10, lines));
end;

procedure TMainForm.DoEditAction(Sender: TObject);
var
  actionTag: Integer;
begin
  if FTabs.ActiveTab = nil then Exit;
  actionTag := (Sender as TMenuItem).Tag;
  case actionTag of
    8:  FTabs.SetActiveTextLF(TrimTrailingWhitespacePerLine(FTabs.ActiveTextLF));
    9:  FTabs.SetActiveTextLF(CaseUpper(FTabs.ActiveTextLF));
    10: FTabs.SetActiveTextLF(CaseLower(FTabs.ActiveTextLF));
    11: FTabs.SetActiveTextLF(CaseTitle(FTabs.ActiveTextLF));
  else
    ApplyLineAction(False, actionTag);
  end;
  FTabs.UpdateCaption(FTabs.ActiveTab);
  UpdateStatus(Sender);
  UpdateTitle;
end;

procedure TMainForm.DoJsonPretty(Sender: TObject);
var err, res: string;
begin
  if FTabs.ActiveTab = nil then Exit;
  res := JsonPretty(FTabs.ActiveTextLF, err);
  if err <> '' then MessageDlg('JSON', 'Invalid JSON: ' + err, mtError, [mbOK], 0)
  else FTabs.SetActiveTextLF(res);
  UpdateStatus(Sender); UpdateTitle;
end;

procedure TMainForm.DoJsonMinify(Sender: TObject);
var err, res: string;
begin
  if FTabs.ActiveTab = nil then Exit;
  res := JsonMinify(FTabs.ActiveTextLF, err);
  if err <> '' then MessageDlg('JSON', 'Invalid JSON: ' + err, mtError, [mbOK], 0)
  else FTabs.SetActiveTextLF(res);
  UpdateStatus(Sender); UpdateTitle;
end;

procedure TMainForm.DoJsonValidate(Sender: TObject);
var err: string;
begin
  if FTabs.ActiveTab = nil then Exit;
  if JsonValidate(FTabs.ActiveTextLF, err) then
    MessageDlg('JSON', 'Valid JSON.', mtInformation, [mbOK], 0)
  else
    MessageDlg('JSON', 'Invalid JSON: ' + err, mtError, [mbOK], 0);
end;

procedure TMainForm.DoXmlFormat(Sender: TObject);
var err, res: string;
begin
  if FTabs.ActiveTab = nil then Exit;
  res := XmlFormat(FTabs.ActiveTextLF, err);
  if err <> '' then MessageDlg('XML', 'Invalid XML: ' + err, mtError, [mbOK], 0)
  else FTabs.SetActiveTextLF(res);
  UpdateStatus(Sender); UpdateTitle;
end;

procedure TMainForm.DoXmlValidate(Sender: TObject);
var err: string;
begin
  if FTabs.ActiveTab = nil then Exit;
  if XmlValidate(FTabs.ActiveTextLF, err) then
    MessageDlg('XML', 'Well-formed XML.', mtInformation, [mbOK], 0)
  else
    MessageDlg('XML', 'Not well-formed: ' + err, mtError, [mbOK], 0);
end;

procedure TMainForm.DoCsvView(Sender: TObject);
begin
  if FTabs.ActiveTab = nil then Exit;
  if FCsvViewer = nil then
    FCsvViewer := TCsvViewer.CreateNewDlg(Self);
  FCsvViewer.ShowCsv(FTabs.ActiveTextLF);
  FCsvViewer.Show;
end;

procedure TMainForm.DoConverters(Sender: TObject);
begin
  if FConvDlg = nil then
    FConvDlg := TConvertersDlg.CreateNewDlg(Self);
  FConvDlg.SetInput(FTabs.ActiveTextLF);
  FConvDlg.Show;
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
  UpdateStatus(Sender);
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
