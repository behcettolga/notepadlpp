// SPDX-License-Identifier: MPL-2.0
unit uTabManager;

{$mode objfpc}{$H+}

{ Tab control <-> DocumentManager wiring (ARCHITECTURE §4). UI-layer unit: it may
  depend on everything. Owns one TATSynEdit + one EControl adapter per open
  document, all sharing a single lexer library. Keeps the visual tabs in step with
  the document model. }

interface

uses
  Classes, SysUtils, Types, Math, Controls, ComCtrls,
  ATSynEdit, ATSynEdit_Carets, ATSynEdit_Adapter_EControl,
  uDocument, uDocumentManager, uLexers, uEditorFactory, uEncoding, uTheme;

type

  { TEditorTab — the visual + editing objects backing one document. }
  TEditorTab = class
  public
    Sheet: TTabSheet;
    Editor: TATSynEdit;
    Adapter: TATAdapterEControl;
    Doc: TDocument;
  end;

  { TTabManager }

  TTabManager = class
  private
    FPages: TPageControl;
    FDocs: TDocumentManager;
    FLexers: TLexerLibrary;
    FTabs: TList;          // of TEditorTab
    FLoading: Boolean;     // guard: programmatic editor text changes
    FTheme: TEditorTheme;  // applied to every editor, incl. tabs opened later
    FOnState: TNotifyEvent;
    FOnCaretMove: TNotifyEvent;
    function MakeTab(ADoc: TDocument): TEditorTab;
    function FindTab(ADoc: TDocument): TEditorTab;
    procedure EditorChanged(Sender: TObject);
    procedure EditorCaretMoved(Sender: TObject);
    procedure LoadDocIntoEditor(ATab: TEditorTab);
    procedure ApplyLexer(ATab: TEditorTab);
    procedure RaiseState;
  public
    constructor Create(APages: TPageControl; ADocs: TDocumentManager;
      ALexers: TLexerLibrary);
    destructor Destroy; override;
    function ActiveTab: TEditorTab;
    procedure SyncActiveEditorToDoc;
    procedure NewTab;
    procedure OpenFileInTab(const AFileName: string);
    procedure CloseActiveTab;
    procedure ReloadActive;
    procedure RefreshActiveLexer;
    procedure GotoLineCol(ALine, ACol: Integer);
    procedure UpdateCaption(ATab: TEditorTab);
    procedure PageChanged;
    // theming: SetTheme repaints all open editors and is remembered for new tabs
    procedure SetTheme(const ATheme: TEditorTheme);
    function CurrentThemeName: string;
    // session enumeration helpers (UI may depend on core/uSession)
    function TabCount: Integer;
    function TabAt(AIndex: Integer): TEditorTab;
    function ActiveIndex: Integer;
    procedure ActivateIndex(AIndex: Integer);
    procedure SetCaret(ATab: TEditorTab; ALine, ACol: Integer);
    procedure GetCaret(ATab: TEditorTab; out ALine, ACol: Integer);
    // status-bar / edit-action helpers operating on the active editor
    function ActiveTextLF: string;
    procedure SetActiveTextLF(const ATextLF: string);
    function ActiveSelLineRange(out AFrom, ATo: Integer): Boolean;
    function ActiveLexerName: string;
    function ActiveCaretInfo(out ALine, ACol, ASelChars, ATotalLines: Integer): Boolean;
    property OnState: TNotifyEvent read FOnState write FOnState;
    property OnCaretMove: TNotifyEvent read FOnCaretMove write FOnCaretMove;
  end;

implementation

constructor TTabManager.Create(APages: TPageControl; ADocs: TDocumentManager;
  ALexers: TLexerLibrary);
begin
  inherited Create;
  FPages := APages;
  FDocs := ADocs;
  FLexers := ALexers;
  FTabs := TList.Create;
  FLoading := False;
  FTheme := LightTheme;
end;

destructor TTabManager.Destroy;
var i: Integer;
begin
  for i := 0 to FTabs.Count - 1 do
    TEditorTab(FTabs[i]).Free;
  FTabs.Free;
  inherited Destroy;
end;

function TTabManager.FindTab(ADoc: TDocument): TEditorTab;
var i: Integer;
begin
  for i := 0 to FTabs.Count - 1 do
    if TEditorTab(FTabs[i]).Doc = ADoc then
      Exit(TEditorTab(FTabs[i]));
  Result := nil;
end;

function TTabManager.MakeTab(ADoc: TDocument): TEditorTab;
begin
  Result := TEditorTab.Create;
  Result.Doc := ADoc;
  Result.Sheet := FPages.AddTabSheet;
  Result.Editor := CreateEditor(Result.Sheet);
  Result.Editor.Parent := Result.Sheet;
  Result.Editor.Align := alClient;
  Result.Editor.OnChange := @EditorChanged;
  Result.Editor.OnChangeCaretPos := @EditorCaretMoved;
  Result.Adapter := TATAdapterEControl.Create(Result.Sheet);
  Result.Adapter.AddEditor(Result.Editor);
  ApplyTheme(Result.Editor, FTheme); // keep new tabs consistent with the active theme
  FTabs.Add(Result);
  UpdateCaption(Result);
  FPages.ActivePage := Result.Sheet;
end;

procedure TTabManager.EditorChanged(Sender: TObject);
var t: TEditorTab;
begin
  if FLoading then Exit;
  t := ActiveTab;
  if (t <> nil) and (t.Editor = Sender) then
  begin
    t.Doc.Modified := True;
    UpdateCaption(t);
    RaiseState;
  end;
end;

procedure TTabManager.ApplyLexer(ATab: TEditorTab);
begin
  if (FLexers = nil) or (not FLexers.Loaded) then Exit;
  if ATab.Doc.Untitled then
    ATab.Adapter.Lexer := nil
  else
    ATab.Adapter.Lexer := FLexers.LexerForFileName(ATab.Doc.FilePath);
end;

procedure TTabManager.LoadDocIntoEditor(ATab: TEditorTab);
begin
  ApplyLexer(ATab); // set the lexer first so the text-set parses with it attached
  FLoading := True;
  try
    ATab.Editor.Text := ATab.Doc.TextLF;
    ATab.Editor.Update(True);
  finally
    FLoading := False;
  end;
  UpdateCaption(ATab);
end;

procedure TTabManager.UpdateCaption(ATab: TEditorTab);
var s: string;
begin
  s := ATab.Doc.DisplayName;
  if ATab.Doc.Modified then
    s := '*' + s;
  ATab.Sheet.Caption := s;
end;

function TTabManager.ActiveTab: TEditorTab;
var i: Integer;
begin
  Result := nil;
  if FPages.ActivePage = nil then Exit;
  for i := 0 to FTabs.Count - 1 do
    if TEditorTab(FTabs[i]).Sheet = FPages.ActivePage then
      Exit(TEditorTab(FTabs[i]));
end;

procedure TTabManager.SyncActiveEditorToDoc;
var t: TEditorTab;
begin
  t := ActiveTab;
  if t = nil then Exit;
  t.Doc.TextLF := EncodingService.NormalizeToLF(t.Editor.Text);
end;

procedure TTabManager.NewTab;
begin
  MakeTab(FDocs.NewDocument);
  RaiseState;
end;

procedure TTabManager.OpenFileInTab(const AFileName: string);
var
  existingIdx: Integer;
  doc: TDocument;
  tab: TEditorTab;
begin
  existingIdx := FDocs.IndexOfPath(AFileName);
  if existingIdx >= 0 then
  begin
    tab := FindTab(FDocs.Docs[existingIdx]);
    if tab <> nil then
      FPages.ActivePage := tab.Sheet;
    RaiseState;
    Exit;
  end;
  doc := FDocs.OpenFile(AFileName);   // loads from disk
  tab := MakeTab(doc);
  LoadDocIntoEditor(tab);
  RaiseState;
end;

procedure TTabManager.CloseActiveTab;
var
  t: TEditorTab;
  i: Integer;
begin
  t := ActiveTab;
  if t = nil then Exit;
  // remove from document manager (by identity)
  for i := 0 to FDocs.Count - 1 do
    if FDocs.Docs[i] = t.Doc then
    begin
      FDocs.Close(i);
      Break;
    end;
  FTabs.Remove(t);
  t.Sheet.Free;   // frees editor + adapter (owned by the sheet)
  t.Free;
  RaiseState;
end;

procedure TTabManager.ReloadActive;
var t: TEditorTab;
begin
  t := ActiveTab;
  if (t = nil) or t.Doc.Untitled then Exit;
  t.Doc.Reload;
  LoadDocIntoEditor(t);
  RaiseState;
end;

procedure TTabManager.RefreshActiveLexer;
var t: TEditorTab;
begin
  t := ActiveTab;
  if t = nil then Exit;
  ApplyLexer(t);
  UpdateCaption(t);
end;

procedure TTabManager.GotoLineCol(ALine, ACol: Integer);
var t: TEditorTab;
begin
  t := ActiveTab;
  if t = nil then Exit;
  if ALine < 1 then ALine := 1;
  if ACol < 1 then ACol := 1;
  // ATSynEdit coords are 0-based (col, line)
  t.Editor.DoGotoPos(
    Point(ACol - 1, ALine - 1),
    Point(-1, -1),
    10, 5,
    True,
    TATEditorActionIfFolded.Unfold,
    False, False);
  if t.Editor.CanSetFocus then
    t.Editor.SetFocus;
end;

procedure TTabManager.PageChanged;
var
  t: TEditorTab;
  i: Integer;
begin
  t := ActiveTab;
  if t = nil then Exit;
  for i := 0 to FDocs.Count - 1 do
    if FDocs.Docs[i] = t.Doc then
    begin
      FDocs.ActiveIndex := i;
      Break;
    end;
  RaiseState;
end;

procedure TTabManager.SetTheme(const ATheme: TEditorTheme);
var i: Integer;
begin
  FTheme := ATheme;
  for i := 0 to FTabs.Count - 1 do
    ApplyTheme(TEditorTab(FTabs[i]).Editor, FTheme);
end;

function TTabManager.CurrentThemeName: string;
begin
  Result := FTheme.Name;
end;

function TTabManager.TabCount: Integer;
begin
  Result := FTabs.Count;
end;

function TTabManager.TabAt(AIndex: Integer): TEditorTab;
begin
  if (AIndex >= 0) and (AIndex < FTabs.Count) then
    Result := TEditorTab(FTabs[AIndex])
  else
    Result := nil;
end;

function TTabManager.ActiveIndex: Integer;
var i: Integer;
begin
  Result := -1;
  if FPages.ActivePage = nil then Exit;
  for i := 0 to FTabs.Count - 1 do
    if TEditorTab(FTabs[i]).Sheet = FPages.ActivePage then
      Exit(i);
end;

procedure TTabManager.ActivateIndex(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < FTabs.Count) then
  begin
    FPages.ActivePage := TEditorTab(FTabs[AIndex]).Sheet;
    PageChanged;
  end;
end;

procedure TTabManager.SetCaret(ATab: TEditorTab; ALine, ACol: Integer);
begin
  if ATab = nil then Exit;
  if ALine < 0 then ALine := 0;
  if ACol < 0 then ACol := 0;
  ATab.Editor.DoGotoPos(
    Point(ACol, ALine),
    Point(-1, -1),
    10, 5,
    True,
    TATEditorActionIfFolded.Unfold,
    False, False);
end;

procedure TTabManager.GetCaret(ATab: TEditorTab; out ALine, ACol: Integer);
var c: TATCaretItem;
begin
  ALine := 0; ACol := 0;
  if (ATab = nil) or (ATab.Editor.Carets.Count = 0) then Exit;
  c := ATab.Editor.Carets[0];
  ALine := c.PosY;
  ACol := c.PosX;
end;

procedure TTabManager.RaiseState;
begin
  if Assigned(FOnState) then
    FOnState(Self);
end;

procedure TTabManager.EditorCaretMoved(Sender: TObject);
begin
  if Assigned(FOnCaretMove) then
    FOnCaretMove(Self);
end;

function TTabManager.ActiveTextLF: string;
var t: TEditorTab;
begin
  Result := '';
  t := ActiveTab;
  if t <> nil then
    Result := EncodingService.NormalizeToLF(t.Editor.Text);
end;

procedure TTabManager.SetActiveTextLF(const ATextLF: string);
var t: TEditorTab;
begin
  t := ActiveTab;
  if t = nil then Exit;
  t.Editor.Text := ATextLF; // OnChange fires -> doc marked modified
end;

function TTabManager.ActiveSelLineRange(out AFrom, ATo: Integer): Boolean;
var t: TEditorTab; c: TATCaretItem;
begin
  AFrom := 0; ATo := 0;
  t := ActiveTab;
  if (t = nil) or (t.Editor.Carets.Count = 0) then Exit(False);
  c := t.Editor.Carets[0];
  if c.EndY < 0 then
  begin
    AFrom := c.PosY; ATo := c.PosY;
  end
  else
  begin
    AFrom := Min(c.PosY, c.EndY);
    ATo := Max(c.PosY, c.EndY);
  end;
  Result := True;
end;

function TTabManager.ActiveLexerName: string;
var t: TEditorTab;
begin
  t := ActiveTab;
  if (t <> nil) and (t.Adapter.Lexer <> nil) then
    Result := t.Adapter.Lexer.LexerName
  else
    Result := 'Plain text';
end;

function TTabManager.ActiveCaretInfo(out ALine, ACol, ASelChars,
  ATotalLines: Integer): Boolean;
var t: TEditorTab; c: TATCaretItem;
begin
  ALine := 1; ACol := 1; ASelChars := 0; ATotalLines := 0;
  t := ActiveTab;
  if (t = nil) or (t.Editor.Carets.Count = 0) then Exit(False);
  c := t.Editor.Carets[0];
  ALine := c.PosY + 1;
  ACol := c.PosX + 1;
  ASelChars := Length(t.Editor.TextSelected);
  ATotalLines := t.Editor.Strings.Count;
  Result := True;
end;

end.
