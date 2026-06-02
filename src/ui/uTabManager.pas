// SPDX-License-Identifier: MPL-2.0
unit uTabManager;

{$mode objfpc}{$H+}

{ Tab control <-> DocumentManager wiring (ARCHITECTURE §4). UI-layer unit: it may
  depend on everything. Owns one TATSynEdit + one EControl adapter per open
  document, all sharing a single lexer library. Keeps the visual tabs in step with
  the document model. }

interface

uses
  Classes, SysUtils, Controls, ComCtrls,
  ATSynEdit, ATSynEdit_Adapter_EControl,
  uDocument, uDocumentManager, uLexers, uEditorFactory, uEncoding;

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
    FOnState: TNotifyEvent;
    function MakeTab(ADoc: TDocument): TEditorTab;
    function FindTab(ADoc: TDocument): TEditorTab;
    procedure EditorChanged(Sender: TObject);
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
    procedure UpdateCaption(ATab: TEditorTab);
    procedure PageChanged;
    property OnState: TNotifyEvent read FOnState write FOnState;
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
  Result.Adapter := TATAdapterEControl.Create(Result.Sheet);
  Result.Adapter.AddEditor(Result.Editor);
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

procedure TTabManager.RaiseState;
begin
  if Assigned(FOnState) then
    FOnState(Self);
end;

end.
