unit mainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Menus, Vcl.StdCtrls, RegExpr,
  Vcl.ComCtrls;

type
  TfrmMain = class(TForm)
    menuMain: TMainMenu;
    menuFile: TMenuItem;
    fileOpen: TMenuItem;
    fileSpace: TMenuItem;
    fileExit: TMenuItem;
    gbContent: TGroupBox;
    odMain: TOpenDialog;
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
  odMain.Execute;
  if FileExists(odMain.FileName) then
    richEdt.Lines.LoadFromFile(odMain.FileName);
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
    '(\binstanceof\b)|(\bclone\b)|(\bnew\b)|(\band\b)|(\bx?or\b)',//type operator etc
    '`.*?`', //exucution operator
    '[\@\[\,\~]',// error control,acces to element of array, comma,tilde
    '\([ ]*?((int(eger)?)|(float)|(double)|(real)|(bool(ean)?)|(string)|'+
      '(array)|(object)|(unset)|(binary))[ ]*?\)', // type casting
    '([\-\+\&\|])(\1|\=)?', //- -- -= + ++ += & && &= | || |=
    '[\^\/\%\.]\=?', // ^ ^= / /= % %/= . .=
    '!\={0,2}',//! != !==
    '\*\*?\=?', // * ** *= **=
    '(\<\>)|(\=\>\>?)|(\<\<\=)|((\<|\>)(\5|\=)?)',//< << <= <<= <> > >> => <= =>>
    '[^\-\+\*\/\%\.\&\|\^\<\>\!\=]\={1,3}([^\>\=$])' // = == ===
  );

  CUT_EXPR = '(?m)((\"|\'').*?\2)|((\/\/|\#).*?$)|((\<\?php))|(\?\>)|'+
    '((\/\*).*?(\*\/))'; //comments, "" <?php ?>
  IF_EXPR = '(\b(if)\b)';
  ELSEIF_EXPR = '(\b(elseif)\b)';
  ELSE_IF_EXPR = '(\b(else\s+if)\b)';
  TERN_OP_EXPR = '(\?)';
  CLSD_BRACKET_EXPR = '(\})';
  OPND_BRACKET_EXPR = '(\{)';
var
  i, quantityOfOperators,quantityOfConditionals, maxInterior: Integer;
  phpCode: String;

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

function MaxOfArray(arr: TArray):Integer;
var
  i,max: Integer;
begin
  max:=0;
  for i := 0 to Length(arr)-1 do
    if arr[i]>max then
      max := arr[i];
  Result := max;
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
begin
  if (match = '}')and(stack.level <> 0) then
    dec(stack.level)
  else begin
    inc(stack.level);
    stack.maxOfStack := stack.level;
  end;
end;

begin
  regExp := TRegExpr.Create;
  regExp.Expression := '('+IF_EXPR+'|'+ELSEIF_EXPR+').*?'+OPND_BRACKET_EXPR+'|'+
    CLSD_BRACKET_EXPR;
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

function MaxIfInterior(str: String):Integer;
var
  interiorsOfIf: TArray;
begin
  interiorsOfIf := FindIfInterior(str);

  if (Length(interiorsOfIf) <> 0) then
    Result := maxOfArray(interiorsOfIf) - 1
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
  phpCode := StrReplace(richEdt.Lines.Text, CUT_EXPR, '');

  quantityOfOperators:=0;
  for i := 0 to OPER_EXPR_QUANTITY - 1 do
    inc(quantityOfOperators, QuantityOfSubStr(phpCode,OPERATOR_EXPR[i]));

  quantityOfConditionals := QuantityOfSubStr(phpCode,
    TERN_OP_EXPR+'|'+IF_EXPR+'|'+ELSEIF_EXPR);

  maxInterior := MaxIfInterior(phpCode);

  UpdateMetrics(quantityOfConditionals,quantityOfOperators,maxInterior);
end;

end.
