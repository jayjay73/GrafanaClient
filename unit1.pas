unit Unit1;

//{$mode delphi}
{$mode objfpc}{$H+}

interface

uses
    Math, Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
    ExtCtrls, Menus, fphttpclient, fpjson, jsonparser, HTTPDefs, DateUtils;

{ WebGetThread }

type
    TWebGetThread = class(TThread)
    private
        R: TStrings;
        S: string;
        HTTPClient: TFPHttpClient;
        fRefresh: integer;
        timeAtLAstRequest: TDateTime;
        procedure DoSyncGetRequestParams;
        procedure DoSyncCopyResponseData;
    protected
        procedure Execute; override;
    public
        constructor Create(CreateSuspended: boolean);
        class procedure CreateOrRecycle(var instanceVar: TWebGetThread);
        property Refresh: integer read fRefresh write fRefresh;
    end;

{ TForm1 }

type
    TForm1 = class(TForm)
        Edit5: TEdit;
        Label5: TLabel;
        StopButton: TButton;
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
        procedure Edit5Exit(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure OKButtonClick(Sender: TObject);
        procedure CancelButtonClick(Sender: TObject);
        procedure PaintBox1Paint(Sender: TObject);
        procedure StopButtonClick(Sender: TObject);

    private
        { private declarations }
    public
        { public declarations }
    end;

var
    Form1: TForm1;
    S, needle, s2, s3, dtime, timecolumn, valuename: string;
    jData, jd2, jd3: TJSONData;
    jObject, jo2, jo3: TJSONObject;
    jArray, ja2, ja3: TJSONArray;
    jElem, je2, je3: TJSONEnum;
    i: integer;
    dvalue, maxv, minv, xstep, yscale, lastDValue: double;
    dArray: array of double;
    x, y, w, h, numDatapoints: integer;
    WebGetThread: TWebGetThread = nil;
    dataRefresh: integer;

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

{ WebGetThread}

class procedure TWebGetThread.CreateOrRecycle(var instanceVar: TWebGetThread);
begin
    if (instanceVar = nil) then
        instanceVar := TWebGetThread.Create(False)
    else
    if (instanceVar.Finished) then
    begin
        instanceVar.Free;
        instanceVar := TWebGetThread.Create(False);
    end;
end;

constructor TWebGetThread.Create(CreateSuspended: boolean);
begin
    inherited Create(CreateSuspended);
    FreeOnTerminate := False;
    fRefresh := 0;
end;

// this method is executed by the main thread and can therefore access all GUI elements.
procedure TWebGetThread.DoSyncGetRequestParams;
begin
    // get request params from main thread
    R := TStringList.Create;
    R.Delimiter := '&';
    R.values['db'] := Form1.Edit2.Text;
    R.values['q'] := URLEncode(Form1.Edit3.Text);
    R.values['epoch'] := Form1.Edit4.Text;
    Form1.Memo1.Lines.Add(R.DelimitedText);
    Refresh := dataRefresh * 1000;
end;

procedure TWebGetThread.DoSyncCopyResponseData;
begin
    // pass data to main thread
    jData := GetJSON(S);
    //Memo1.Lines.Add(jData.FormatJSON());
    //jd2 := jData.GetPath('results[0].series[0].values');

    //jd3:= jData.GetPath('results[0].series[5].columns');
    jd3 := jData.GetPath('results[0].series[0].columns');
    ja3 := TJSONArray(jd3);
    for je3 in ja3 do
    begin
        //Memo1.Lines.Add(je3.Value.AsString);
        if (je3.Value.AsString = 'time') then
        begin
            //Memo1.Lines.Add(je3.Key);
            timecolumn := je3.Key;
        end
        else
            valuename := je3.Value.AsString;
    end;
    Form1.Memo1.Lines.Add(timecolumn);
    Form1.Memo1.Lines.Add(valuename);

    //jd2 := jData.GetPath('results[0].series[5].values');
    jd2 := jData.GetPath('results[0].series[0].values');
    jArray := TJSONArray(jd2);

    Form1.Memo1.Lines.Add(DateTimeToStr(Now));
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
    Form1.Memo1.Lines.Add('Datapoints: ' + numDatapoints.ToString);
    Form1.Memo1.Lines.Add('min value: ' + minv.ToString);
    Form1.Memo1.Lines.Add('max value: ' + maxv.ToString);
    //Memo1.Lines.Add(jArray.FormatJSON);
    Form1.Memo1.Lines.Add(DateTimeToStr(Now));

    Form1.PaintBox1.Invalidate;

end;

procedure TWebGetThread.Execute;
//var
begin
    // get Request parameters
    Synchronize(@DoSyncGetRequestParams);
    while (not Terminated) do
    begin
        // make http call
        HttpClient := TFPHttpClient.Create(nil);
        try
            HttpClient.AllowRedirect := True;
            HttpClient.AddHeader('Content-Type', 'application/json');
            HttpClient.AddHeader('Accept', 'application/json');
            //S := HttpClient.FormPost('http://play.grafana.org/api/datasources/proxy/1/render', R.DelimitedText);
            S := HttpClient.Get(Form1.Edit1.Text + '?' + R.DelimitedText);
        finally
            HttpClient.Free;
        end;
        // copy back result
        Synchronize(@DoSyncCopyResponseData);
        if (fRefresh = 0) then
            Terminate;
        timeAtLastRequest := Now;
        while (not Terminated) do
        begin
            if (MilliSecondsBetween(timeAtLastRequest, Now) > fRefresh) then
                break;
            Sleep(100);
        end;
    end;
end;

{ TForm1 }

procedure TForm1.OKButtonClick(Sender: TObject);
begin
    TWebGetThread.CreateOrRecycle(WebGetThread);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
    Memo1.ScrollBars := ssVertical;
    DoubleBuffered := True;
end;

procedure TForm1.Edit5Exit(Sender: TObject);
begin
    dataRefresh := StrToInt(Edit5.Text);
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
        yoffset := 0 - minv;

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

procedure TForm1.StopButtonClick(Sender: TObject);
begin
    if (WebGetThread <> nil) then
        WebGetThread.Terminate;
end;

end.
