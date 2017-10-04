unit Unit1;

{$mode delphi}

interface

uses
  Math, Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Menus, Grids, fphttpclient, fpjson, jsonparser, HTTPDefs;

{ TForm1 }

type
  TForm1 = class(TForm)
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Memo1: TMemo;
    OKButton: TButton;
    CancelButton: TButton;
    PaintBox1: TPaintBox;
    procedure FormCreate(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure PaintBox1Click(Sender: TObject);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure PaintBox1Paint(Sender: TObject);

  private
    { private declarations }
  public
    { public declarations }
  end;
  ENeedleNotFoundException = class(Exception);

var
  Form1: TForm1;
  S, needle, s2, s3, dtime : String;
  jData, jd2, jd3 : TJSONData;
  jObject, jo2, jo3 : TJSONObject;
  jArray, ja2, ja3 : TJSONArray;
  R: TStrings;
  jElem: TJSONEnum;
  i: Integer;
  dvalue, maxv, minv, xstep, yscale, lastDValue : Double;
  dArray : Array of Double;
  x, y, w, h, numDatapoints: Integer;

implementation

{$R *.lfm}

function URLEncode(s: string): string;
var
  i: integer;
  source: PAnsiChar;
begin
  result := '';
  source := pansichar(s);
  for i := 1 to length(source) do
    if not (source[i - 1] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '~', '.', ':', '/']) then
      result := result + '%' + inttohex(ord(source[i - 1]), 2)
    else
      result := result + source[i - 1];
end;

{ TForm1 }

procedure TForm1.OKButtonClick(Sender: TObject);
begin
    With TFPHttpClient.Create(Nil) do
    try
      AllowRedirect:=True;
      S:=Get(Edit1.Text);
    finally
      Free;
    end;
  {Label1.Caption:= S;}
  //Memo1.Lines.Clear;
  //jData:= GetJSON(S);
  //Memo1.Lines.Add(jData.FormatJSON);

   //jObject := TJSONObject(jData);
   //jo2:= jObject.Get('dashboard', TJSONObject(GetJSON('{}')));
   //ja2:= jo2.Get('rows', TJSONArray(GetJSON('{}')));
   //jo3:= ja2.Objects[1];
   //ja3:= jo3.Get('panels', TJSONArray(GetJSON('{}')));
   //Memo1.Lines.Add(ja3.Extract(0).FormatJSON);

   needle:=  'dashboard.rows[' + Edit2.Text + '].panels[' + Edit3.Text + '].targets[' + Edit4.Text + '].target';
   try
     jData:= GetJSON(S);
     s2:= jData.GetPath(needle).asJSON;
   except
     on e: EJSON do
		   Memo1.Lines.Add(e.toString);
   end;
   s2:= s2.Trim('"');
   Memo1.Lines.Add(s2);

   //jd3:= GetJSON('{ "target" : [ ' + s2 + ' ], "from" : "-2h", until : "now", format : "json" }');
   R:= TStringList.Create;
   R.Delimiter:='&';
   //s3:= 'alias(statsd.fakesite.counters.session_start.desktop.count, ''memory'')';
   R.values['target']:= URLEncode(s2);
   R.values['from']:= '-2h';
   R.values['until']:= 'now';
   R.values['format']:= 'json';
   R.values['maxDataPoints']:= '1800';
   //s3:= 'target=alias(statsd.fakesite.counters.session_start.desktop.count%2C%20''memory'')&from=-2h&until=now&format=json';
   Memo1.Lines.Add(R.DelimitedText);

   With TFPHttpClient.Create(Nil) do
   try
     AllowRedirect:=True;
     AddHeader('Content-Type', 'application/json');
     AddHeader('Accept', 'application/json');
     S:= FormPost('http://play.grafana.org/api/datasources/proxy/1/render', R.DelimitedText);
   finally
     Free;
   end;
   jData:= GetJSON(S);
   jd2:= jData.GetPath('[0].datapoints');
   jArray:=TJSONArray(jd2);
   //jArray.(TJSONArray(jd2));

   Memo1.Lines.Add(DateTimeToStr(Now));
   lastDValue:=0;
   i:=0;
   for jElem in jArray do begin
     dtime:= jElem.Value.GetPath('[1]').AsString;
     if (jElem.Value.GetPath('[0]').IsNull) then
       dvalue:=lastDValue
     else begin
       dvalue:= jElem.Value.GetPath('[0]').AsFloat;
       lastDValue:= dvalue;
     end;
     SetLength(dArray, i+1);
     dArray[i]:= dvalue;
     maxv:= Maxvalue(dArray);
     minv:= Minvalue(dArray);

     //Memo1.Lines.Add(i.toString + ': ' + dvalue.ToString);
     i:=i+1;
   end;
   numDatapoints:= i - 1;
   Memo1.Lines.Add('Datapoints: ' + numDatapoints.ToString);
   Memo1.Lines.Add('min value: ' + minv.ToString);
   Memo1.Lines.Add('max value: ' + maxv.ToString);
   //Memo1.Lines.Add(jArray.FormatJSON);
   Memo1.Lines.Add(DateTimeToStr(Now));

   PaintBox1.Invalidate;

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Memo1.ScrollBars := ssVertical;
end;

procedure TForm1.CancelButtonClick(Sender: TObject);
begin
	Memo1.Clear;
  PaintBox1.Invalidate;
  PaintBox1.Canvas.Clear;
  {
   Memo1.Lines.Add(PaintBox1.Canvas.Width.ToString);
   Memo1.Lines.Add(PaintBox1.Canvas.Height.ToString);
   Memo1.Lines.Add(PaintBox1.ClientWidth.ToString);
   Memo1.Lines.Add(PaintBox1.ClientHeight.ToString);
  }
end;

procedure TForm1.PaintBox1Click(Sender: TObject);
Var n:Integer;

begin
  randomize;
  Memo1.Lines.Add(DateTimeToStr(Now));
  for n:=1 to 100000 do
  Begin

  	PaintBox1.Canvas.LineTo(random(200), random(200));
  end;
  Memo1.Lines.Add(DateTimeToStr(Now));
end;

procedure TForm1.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin

  PaintBox1.Canvas.LineTo(random(200), random(200));
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
Var n,w,h: Integer;
begin
  {
   PaintBox1.Canvas.Clear;
   w:= PaintBox1.ClientWidth;
   h:= PaintBox1.ClientHeight;
   for n:=1 to 1000 do
   Begin
   	PaintBox1.Canvas.LineTo(random(w), random(h));
   end;
  }

  PaintBox1.Canvas.Clear;
  if (numDatapoints > 0) then
    begin
      w:= PaintBox1.ClientWidth;
  		h:= PaintBox1.ClientHeight;
  		xstep:= w / numDatapoints;
  		yscale:= h / maxv;

      Memo1.Lines.Add('w: ' + w.ToString + ' h: ' + h.ToString );
    	Memo1.Lines.Add('xstep: ' + xstep.ToString);
  		Memo1.Lines.Add('yscale: ' + yscale.ToString);

  		for i:= 0 to numDatapoints do
    		begin
      		x:= Round(i * xstep);
      		y:= Round(dArray[i] * yscale);
        	if (i = 0) then
            PaintBox1.Canvas.MoveTo(x,h - y)
          else
      		  PaintBox1.Canvas.LineTo(x, h - y);
          //Memo1.Lines.Add('i: ' + i.ToString + '  x: ' + x.ToString + '  y: ' + y.ToString);
    		end;

    end;


end;

end.

