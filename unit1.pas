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
        procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
        procedure PaintBox1Paint(Sender: TObject);

    private
        { private declarations }
    public
        { public declarations }
    end;

    ENeedleNotFoundException = class(Exception);

var
    Form1: TForm1;
    S, needle, s2, s3, dtime, timecolumn, valuename: string;
    jData, jd2, jd3: TJSONData;
    jObject, jo2, jo3: TJSONObject;
    jArray, ja2, ja3: TJSONArray;
    R: TStrings;
    jElem, je2, je3: TJSONEnum;
    i: integer;
    dvalue, maxv, minv, xstep, yscale, lastDValue: double;
    dArray: array of double;
    x, y, w, h, numDatapoints: integer;

implementation

{$R *.lfm}

function URLEncode(s: string): string;
var
    i: integer;
    Source: PAnsiChar;
begin
    Result := '';
    Source := PAnsiChar(s);
    for i := 1 to length(Source) do
    begin
        if not (Source[i - 1] in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '~', '.', ':', '/']) then
            Result := Result + '%' + inttohex(Ord(Source[i - 1]), 2)
        else
            Result := Result + Source[i - 1];
    end;
end;

{ TForm1 }

procedure TForm1.OKButtonClick(Sender: TObject);
begin
    R := TStringList.Create;
    R.Delimiter := '&';

    R.values['db'] := Edit2.Text;
    R.values['q'] := URLEncode(Edit3.Text);
    R.values['epoch'] := Edit4.Text;

    Memo1.Lines.Add(R.DelimitedText);

    with TFPHttpClient.Create(nil) do
        try
            AllowRedirect := True;
            AddHeader('Content-Type', 'application/json');
            AddHeader('Accept', 'application/json');
            //S := FormPost('http://play.grafana.org/api/datasources/proxy/1/render', R.DelimitedText);
            S := Get(Edit1.Text + '?' + R.DelimitedText);
        finally
            Free;
        end;
    jData := GetJSON(S);
    //Memo1.Lines.Add(jData.FormatJSON());
    //jd2 := jData.GetPath('results[0].series[0].values');

    //jd3:= jData.GetPath('results[0].series[5].columns');
    jd3:= jData.GetPath('results[0].series[0].columns');
    ja3:= TJSONArray(jd3);
    for je3 in ja3 do
    begin
        //Memo1.Lines.Add(je3.Value.AsString);
        if (je3.Value.AsString = 'time') then
        begin
             //Memo1.Lines.Add(je3.Key);
             timecolumn:= je3.Key;
        end
        else valuename:= je3.Value.AsString;
    end;
    Memo1.Lines.Add(timecolumn);
    Memo1.Lines.Add(valuename);

    //jd2 := jData.GetPath('results[0].series[5].values');
    jd2 := jData.GetPath('results[0].series[0].values');
    jArray := TJSONArray(jd2);

    Memo1.Lines.Add(DateTimeToStr(Now));
    lastDValue := 0;
    i := 0;
    for jElem in jArray do
    begin
        dtime := jElem.Value.GetPath('[0]').AsString;
        if (jElem.Value.GetPath('[1]').IsNull) then
            dvalue := lastDValue
        else
        begin
            dvalue := jElem.Value.GetPath('[1]').AsFloat;
            lastDValue := dvalue;
        end;
        SetLength(dArray, i + 1);
        dArray[i] := dvalue;
        maxv := MaxValue(dArray);
        minv := MinValue(dArray);
        //Memo1.Lines.Add(i.toString + ': ' + dvalue.ToString);
        i := i + 1;
    end;
    numDatapoints := i - 1;
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
    DoubleBuffered:= True;
end;

procedure TForm1.CancelButtonClick(Sender: TObject);
begin
    Memo1.Clear;
    PaintBox1.Invalidate;
    PaintBox1.Canvas.Clear;
    //Memo1.Lines.Add(PaintBox1.Canvas.Width.ToString);
    //Memo1.Lines.Add(PaintBox1.Canvas.Height.ToString);
    //Memo1.Lines.Add(PaintBox1.ClientWidth.ToString);
    //Memo1.Lines.Add(PaintBox1.ClientHeight.ToString);
end;

procedure TForm1.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X, Y: integer);
begin

    PaintBox1.Canvas.LineTo(random(200), random(200));
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
var
    n, w, h: integer;
    yoffset: double;
begin
    PaintBox1.Canvas.Clear;
    if (numDatapoints > 0) then
    begin
        w := PaintBox1.ClientWidth;
        h := PaintBox1.ClientHeight;
        xstep := w / numDatapoints;
        yscale := h / (maxv - minv);
        yoffset:= 0 - minv;

        Memo1.Lines.Add('w: ' + w.ToString + ' h: ' + h.ToString);
        Memo1.Lines.Add('xstep: ' + xstep.ToString);
        Memo1.Lines.Add('yscale: ' + yscale.ToString);
        Memo1.Lines.Add('yoffset: ' + yoffset.ToString);

        PaintBox1.Canvas.MoveTo(0, h - Round(yoffset * yscale));
        PaintBox1.Canvas.LineTo(w, h - Round(yoffset * yscale));

        for i := 0 to numDatapoints do
        begin // paint lines between datapoints
            x := Round(i * xstep);
            y := Round((dArray[i] + yoffset) * yscale);
            if (i = 0) then
            begin
                PaintBox1.Canvas.MoveTo(x, h - y);
            end
            else
            begin
                PaintBox1.Canvas.LineTo(x, h - y);
                //Memo1.Lines.Add('i: ' + i.ToString + '  x: ' + x.ToString + '  y: ' + y.ToString);
            end;
        end;
    end;
end;

end.
