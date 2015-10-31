unit mainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus, Vcl.StdCtrls, RegExpr,
  Vcl.ComCtrls;

type
  TfrmMain = class(TForm)
    menu: TMainMenu;
    menuFile: TMenuItem;
    fileOpen: TMenuItem;
    fileSpace: TMenuItem;
    fileExit: TMenuItem;
    gbContent: TGroupBox;
    openDialog: TOpenDialog;
    gbMetr: TGroupBox;
    lblLPC: TLabel;
    edtLPC: TEdit;
    lblAPC: TLabel;
    edtAPC: TEdit;
    lblMI: TLabel;
    edtMaxInter: TEdit;
    richEdt: TRichEdit;
    procedure fileExitClick(Sender: TObject);
    procedure fileOpenClick(Sender: TObject);
    procedure richEdtChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.fileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.fileOpenClick(Sender: TObject);
begin
  openDialog.Execute;
  if FileExists(openDialog.FileName) then
    richEdt.Lines.LoadFromFile(openDialog.FileName);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  richEdt.WantTabs := true;
end;

procedure TfrmMain.richEdtChange(Sender: TObject);
type
  TArray = array of integer;
const
  OPER_EXPR_QUANTITY = 10;
  OPERATOR_EXPR: array [0..OPER_EXPR_QUANTITY-1] of string = (
    '(\.eq(ua)?l\?)|(\bdefined\?)|(\bnot\b)|(\band\b)|(\bor\b)',
    '(\[)|(\{)|(::)',
    '[\^\/\%\+\-]\=?', // ^ / % + - self and with =
    '([\&\|])(\1|\=)?', //& && &= | || |=
    '\*\*?\=?', // * ** *= **=
    '(\<\>)|(\=\>\>?)|(\<\<\=)|((\<|\>)(\5|\=)?)',//grate or less sign
    '[^\-\+\*\/\%\.\&\|\^\<\>\!\=]\={1,3}([^\>\=\~$])', // = == ===
    '[\=]?~', // ~ self and with =
    '(\.){1,3}',
    '(![\~\=]?)' // ! self and with ~ or =
  );
  CUT_EXPR = '(?m)((\"|\'').*?\2)|((\/\/|\#).*?$)|((=begin).*?(=end))';
  IF_UNLESS_EXPR = '((if)|(unless))';
  ELSIF_EXPR = '(\b(elsif)\b)';
  TERN_OP_EXPR = '(\?.+?\:)';
  TERN_QSTN_EXPR = '(\s*?\?\\s*?)';
  TERN_TWODOT_EXPR = '(\b\:\b)';
  END_WORD_EXPR = '(end)';
  THEN_WORD_EXPR = '(then)';

  END_BLOCK_EXPR = '(\b(while)\b)|(\b(until)\b)|(\b(begin)\b)|(\b(def)\b)|'+
    '(\b(class)\b)';
var
  i, quantityOfOperators,quantityOfConditionals, maxInterior: Integer;
  rubyCodeStr: String;

function QuantityOfSubStr(str, subStrExp: String): Integer;
var
  regExp: TRegExpr;
  quantity: Integer;
begin
  regExp := TRegExpr.Create;
  regExp.Expression := subStrExp;
  quantity := 0;

  if (regExp.Exec(str)) then
    repeat
      inc(quantity);
    until not (regExp.ExecNext);
  regExp.Free;

  Result := quantity;
end;

function MaxOfArray(arrayOfLegths: TArray):Integer;
var
  i,maxLength: Integer;
begin
  maxLength:=0;
  for i := 0 to Length(arrayOfLegths)-1 do
    if arrayOfLegths[i] > maxLength then
      maxLength := arrayOfLegths[i];
  Result := maxLength;
end;

function StrReplace(strForRep, beforeRep, afterRep: String): String;
var
  regExp: TRegExpr;
begin
  regExp := TRegExpr.Create;

  regExp.Expression := beforeRep;
  strForRep := regExp.Replace(strForRep, afterRep, true);

  regExp.Free;

  Result := strForRep;
end;

function FindIfInterior(str: String): TArray;
type
  TStack = record
    maxOfStack: Integer;
    level: Integer;
  end;
var
  regExp: TRegExpr;
  interOfIf: TArray;
  stack: TStack;

procedure UpdateStack(match: String ; var stack: TStack);
var
  ifIsExists, unlessIsExists: Boolean;
begin
  match:=match.Trim;
  if (match = 'end')and(stack.level <> 0) then
    dec(stack.level)
  else begin
    ifIsExists := pos('if',match)<>0;
    unlessIsExists := pos('unless',match)<>0;
    if not ((ifIsExists) and (match.Length <> 'if'.Length))or
      ((unlessIsExists) and (match.Length <> 'unless'.Length)) then
      inc(stack.level);
    if ( ifIsExists )or(match = 'elsif')or( unlessIsExists ) then
      inc(stack.maxOfStack);
  end;
end;

begin
  regExp := TRegExpr.Create;
  regExp.Expression := IF_UNLESS_EXPR+'|'+ELSIF_EXPR+'|'+THEN_WORD_EXPR+'|'+
    END_WORD_EXPR;
  stack.level := 0;
  stack.maxOfStack := 0;
  if (regExp.Exec(str)) then
    repeat
      UpdateStack(regExp.Match[0], stack);
      if stack.level = 0 then
      begin
        SetLength(interOfIf, Length(interOfIf) + 1);
        interOfIf[Length(interOfIf) - 1] := stack.maxOfStack;
        stack.maxOfStack := 0;
      end;
    until not (regExp.ExecNext);
  Result := interOfIf;
  regExp.Free;
end;

function MaxInteriorCounter(str: String):Integer;
var
  interiors: TArray;
begin
  interiors := FindIfInterior(str);
  if (Length(interiors) <> 0) then
    Result := maxOfArray(interiors) - 1
  else
    Result := 0;
end;

procedure UpdateMetrics(quantCondOper, quantAllOper, maxInter: Integer);
begin
  edtLPC.Text := quantCondOper.ToString();
  inc(quantAllOper, quantCondOper);
  edtAPC.Text := edtLPC.Text+'/' + quantAllOper.ToString();
  edtMaxInter.Text := maxInter.ToString();
end;

begin
  rubyCodeStr := StrReplace(richEdt.Lines.Text, CUT_EXPR, '');

  quantityOfOperators:=0;
  for i := 0 to OPER_EXPR_QUANTITY - 1 do
    inc(quantityOfOperators, QuantityOfSubStr(rubyCodeStr,OPERATOR_EXPR[i]));

  quantityOfConditionals := QuantityOfSubStr(rubyCodeStr,
    TERN_OP_EXPR+'|'+IF_UNLESS_EXPR+'|'+ELSIF_EXPR);

  maxInterior := MaxInteriorCounter(rubyCodeStr);

  UpdateMetrics(quantityOfConditionals,quantityOfOperators,maxInterior);
end;

end.
