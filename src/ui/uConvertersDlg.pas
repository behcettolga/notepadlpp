// SPDX-License-Identifier: MPL-2.0
unit uConvertersDlg;

{$mode objfpc}{$H+}

{ Converters dialog. UI layer (ARCHITECTURE §4). Input memo -> operation -> output
  memo, driving uConverters. Resourceless code-built form. }

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls,
  uConverters;

type

  { TConvertersDlg }

  TConvertersDlg = class(TForm)
  private
    edIn: TMemo;
    edOut: TMemo;
    edFromBase: TEdit;
    edToBase: TEdit;
    procedure SetOut(const S: string);
    procedure B64Enc(Sender: TObject);
    procedure B64Dec(Sender: TObject);
    procedure UrlEnc(Sender: TObject);
    procedure UrlDec(Sender: TObject);
    procedure DoMD5(Sender: TObject);
    procedure DoSHA1(Sender: TObject);
    procedure DoSHA256(Sender: TObject);
    procedure DoUuid(Sender: TObject);
    procedure DoBaseConv(Sender: TObject);
    procedure BuildUI;
  public
    constructor CreateNewDlg(AOwner: TComponent);
    procedure SetInput(const S: string);
  end;

implementation

constructor TConvertersDlg.CreateNewDlg(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Converters';
  Width := 560; Height := 460;
  Position := poScreenCenter;
  BuildUI;
end;

procedure TConvertersDlg.BuildUI;

  function MkBtn(const C: string; ALeft, ATop, AWidth: Integer;
    AOnClick: TNotifyEvent): TButton;
  begin
    Result := TButton.Create(Self);
    Result.Parent := Self;
    Result.Left := ALeft; Result.Top := ATop; Result.Width := AWidth; Result.Height := 26;
    Result.Caption := C; Result.OnClick := AOnClick;
  end;

  function MkLabel(const C: string; ALeft, ATop: Integer): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self; Result.Left := ALeft; Result.Top := ATop; Result.Caption := C;
  end;

begin
  MkLabel('Input:', 12, 10);
  edIn := TMemo.Create(Self);
  edIn.Parent := Self; edIn.Left := 12; edIn.Top := 28; edIn.Width := 536; edIn.Height := 110;
  edIn.ScrollBars := ssAutoBoth; edIn.Anchors := [akLeft, akTop, akRight];

  MkBtn('Base64 Enc', 12, 146, 92, @B64Enc);
  MkBtn('Base64 Dec', 110, 146, 92, @B64Dec);
  MkBtn('URL Enc', 208, 146, 80, @UrlEnc);
  MkBtn('URL Dec', 294, 146, 80, @UrlDec);
  MkBtn('UUID', 380, 146, 70, @DoUuid);

  MkBtn('MD5', 12, 178, 70, @DoMD5);
  MkBtn('SHA-1', 88, 178, 70, @DoSHA1);
  MkBtn('SHA-256', 164, 178, 80, @DoSHA256);

  MkLabel('Base:', 260, 184);
  edFromBase := TEdit.Create(Self);
  edFromBase.Parent := Self; edFromBase.Left := 300; edFromBase.Top := 180;
  edFromBase.Width := 40; edFromBase.Text := '16';
  MkLabel('->', 346, 184);
  edToBase := TEdit.Create(Self);
  edToBase.Parent := Self; edToBase.Left := 366; edToBase.Top := 180;
  edToBase.Width := 40; edToBase.Text := '10';
  MkBtn('Convert', 412, 178, 80, @DoBaseConv);

  MkLabel('Output:', 12, 214);
  edOut := TMemo.Create(Self);
  edOut.Parent := Self; edOut.Left := 12; edOut.Top := 232; edOut.Width := 536; edOut.Height := 210;
  edOut.ScrollBars := ssAutoBoth; edOut.ReadOnly := True;
  edOut.Anchors := [akLeft, akTop, akRight, akBottom];
end;

procedure TConvertersDlg.SetInput(const S: string);
begin
  edIn.Text := S;
end;

procedure TConvertersDlg.SetOut(const S: string);
begin
  edOut.Text := S;
end;

procedure TConvertersDlg.B64Enc(Sender: TObject);
begin SetOut(Base64Encode(edIn.Text)); end;

procedure TConvertersDlg.B64Dec(Sender: TObject);
begin SetOut(Base64Decode(edIn.Text)); end;

procedure TConvertersDlg.UrlEnc(Sender: TObject);
begin SetOut(UrlEncode(edIn.Text)); end;

procedure TConvertersDlg.UrlDec(Sender: TObject);
begin SetOut(UrlDecode(edIn.Text)); end;

procedure TConvertersDlg.DoMD5(Sender: TObject);
begin SetOut(HashMD5(edIn.Text)); end;

procedure TConvertersDlg.DoSHA1(Sender: TObject);
begin SetOut(HashSHA1(edIn.Text)); end;

procedure TConvertersDlg.DoSHA256(Sender: TObject);
begin SetOut(HashSHA256(edIn.Text)); end;

procedure TConvertersDlg.DoUuid(Sender: TObject);
begin SetOut(NewUuid); end;

procedure TConvertersDlg.DoBaseConv(Sender: TObject);
var fb, tb: Integer; res: string;
begin
  fb := StrToIntDef(edFromBase.Text, 0);
  tb := StrToIntDef(edToBase.Text, 0);
  res := ConvertBase(Trim(edIn.Text), fb, tb);
  if res = '' then
    SetOut('(invalid input or base — bases must be 2..36)')
  else
    SetOut(res);
end;

end.
