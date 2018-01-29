unit Unit1;

//{$mode delphi}
{$mode objfpc}{$H+}

interface

uses
    //Math,
    Classes, SysUtils, FileUtil, TAGraph, Forms, Controls, Graphics, Dialogs,
    StdCtrls, ExtCtrls, Menus, ComCtrls, fpjson, jsonparser, gcHTTPClientThread,
    TASeries, TASources, TACustomSource, DateUtils, fgl, TAIntervalSources,
    TAChartUtils, Unit2, strutils;


{ TForm1 }

type

    gcTTagsList = specialize TFPGMap<string, string>;

    gcTSeries = record
        Name: string;
        tags: gcTTagsList;
        time: array of TDateTime;
        Value: array of double;
    end;

    gcTResultData = array of array of gcTSeries;

    TInfluxDBSource = class(TUserDefinedChartSource)
    public
        reslt, series: integer;
        timecol, valuecol: integer;
        Data: gcTSeries;
    end;

    TForm1 = class(TForm)
        Chart1: TChart;
        CheckBox1: TCheckBox;
        ComboBox1: TComboBox;
        Edit1: TEdit;
        Edit5: TEdit;
        MainMenu1: TMainMenu;
        MenuItem1: TMenuItem;
        MenuItem2: TMenuItem;
        MenuItem3: TMenuItem;
        MenuItem4: TMenuItem;
        MenuItem5: TMenuItem;
        MenuItem6: TMenuItem;
        Splitter1: TSplitter;
        StaticText1: TStaticText;
        StatusBar1: TStatusBar;
        StopButton: TButton;
        Memo1: TMemo;
        OKButton: TButton;
        CancelButton: TButton;
        procedure CheckBox1Change(Sender: TObject);
        procedure ComboBox1Change(Sender: TObject);
        procedure CopyRequest(var request: string; var autorefresh: integer; var user, pass: string);
        procedure CopyResponse(response: string);
        procedure Edit5Exit(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure MenuItem2Click(Sender: TObject);
        procedure MenuItem4Click(Sender: TObject);
        procedure MenuItem5Click(Sender: TObject);
        procedure MenuItem6Click(Sender: TObject);
        procedure OKButtonClick(Sender: TObject);
        procedure CancelButtonClick(Sender: TObject);
        procedure StopButtonClick(Sender: TObject);
        procedure WebGetThreadTerminates(Sender: TObject);
        procedure GetJSONPoint(ASource: TInfluxDBSource; AIndex: integer; var AItem: TChartDataItem);

        procedure StartGraph(Sender: TObject);
        procedure StopGraph(Sender: TObject);
        procedure AutoRefreshOn(Sender: TObject);
        procedure AutoRefreshOff(Sender: TObject);


    private
        { private declarations }
        ArChart1Series: array of TLineSeries;
        ArChart1Sources: array of TInfluxDBSource;
        DateAxisSource: TDateTimeIntervalChartSource;

    public
        { public declarations }
    end;

var
    Form1: TForm1;
    S, needle, s2, s3, dtime: string;
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
    R: TStrings;

    resultData: gcTResultData;


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


procedure TForm1.FormCreate(Sender: TObject);
var
    i: integer;
begin
    Memo1.ScrollBars := ssVertical;
    DoubleBuffered := True;
    Chart1.DoubleBuffered := True;
    DateAxisSource := TDateTimeIntervalChartSource.Create(Chart1);
    Chart1.BottomAxis.Marks.Source := DateAxisSource;
    Chart1.BottomAxis.Marks.Style := smsLabel;
    for i := 0 to Config.ComponentCount - 1 do
    begin
        ComboBox1.Items.Add(Config.Components[i].Name);
    end;
    for i := 0 to ComboBox1.Items.Count - 1 do
        if ComboBox1.items[i] = Config.lastDataSource then
        begin
            ComboBox1.ItemIndex := i;
            OKButton.Enabled := True;
            MenuItem4.Enabled := True;
        end;
end;

procedure TForm1.MenuItem2Click(Sender: TObject);
begin
    Form2.ShowModal;
end;

procedure TForm1.MenuItem4Click(Sender: TObject);
begin
    StartGraph(Sender);
end;

procedure TForm1.MenuItem5Click(Sender: TObject);
begin
    StopGraph(Sender);
end;

procedure TForm1.MenuItem6Click(Sender: TObject);
begin
    if (MenuItem6.Checked) then
        AutorefreshOn(Sender)
    else
        AutorefreshOff(Sender);
end;

procedure TForm1.CheckBox1Change(Sender: TObject);
begin
    if (Checkbox1.Checked) then
        AutorefreshOn(Sender)
    else
        AutorefreshOff(Sender);
end;

procedure TForm1.ComboBox1Change(Sender: TObject);
begin
    if ComboBox1.Text = '' then
    begin
        OKButton.Enabled := False;
        MenuItem4.Enabled := False;
    end
    else
    begin
        OKButton.Enabled := True;
        MenuItem4.Enabled := True;
        Config.lastDataSource := ComboBox1.Text;
    end;
end;

procedure TForm1.CopyRequest(var request: string; var autorefresh: integer; var user, pass: string);
begin
    // get request params from main thread
    if ComboBox1.Text = '' then
        Exit;
    R := TStringList.Create;
    R.Delimiter := '&';
    R.values['db'] := TConfigItemDatasource(Config.FindComponent(ComboBox1.Text)).DB;
    R.values['q'] := URLEncode(ReplaceText(TConfigItemDatasource(Config.FindComponent(ComboBox1.Text)).query, '${interval}', Edit1.Text));
    R.values['epoch'] := TConfigItemDatasource(Config.FindComponent(ComboBox1.Text)).epoch;
    Memo1.Lines.Add(R.DelimitedText);
    request := TConfigItemDatasource(Config.FindComponent(ComboBox1.Text)).URL + '?' + R.DelimitedText;
    user := TConfigItemDatasource(Config.FindComponent(ComboBox1.Text)).user;
    pass := TConfigItemDatasource(Config.FindComponent(ComboBox1.Text)).pass;
    if CheckBox1.Checked then
        autorefresh := dataRefresh * 1000
    else
        autorefresh := 0;

end;

procedure TForm1.CopyResponse(response: string);
var
    iRes, iSer, iPoint, numResults, numSeries, numPoints: integer;
    eJson: TJSONEnum;
    timecol, valuecol: integer;
    valuename: string;
    tempDate: TDateTime;

begin
    // pass data to main thread
    Memo1.Lines.Add(DateTimeToStr(Now));

    jData := GetJSON(response);
    Memo1.Lines.Add(jData.AsJSON);

    numResults := jData.GetPath('results').Count;
    Memo1.Lines.Add('numResults: ' + numResults.toString);

    Chart1.Series.Clear;
    setLength(resultData, numResults);

    // iterate over "results" (eq. number of queries in the request)
    i := 0; // chart index: every series in every result gets a graph
    for iRes := 0 to numResults - 1 do
    begin
        numSeries := jData.GetPath('results').Items[iRes].GetPath('series').Count;
        Memo1.Lines.Add('numSeries: ' + numSeries.toString);

        SetLength(resultData[iRes], numSeries);

        // iterate over "series"
        for iSer := 0 to numSeries - 1 do
        begin
            numPoints := jData.GetPath('results').Items[iRes].GetPath('series').Items[iSer].GetPath('values').Count;
            Memo1.Lines.Add('    iRes: ' + iRes.ToString);
            Memo1.Lines.Add('    iSer: ' + iSer.toString);
            Memo1.Lines.Add('       i: ' + i.ToString);
            Memo1.Lines.Add('# Points: ' + numPoints.toString);

            SetLength(resultData[iRes][iSer].time, numPoints);
            SetLength(resultData[iRes][iSer].Value, numPoints);

            // iterate over "columns" and find out which is time (X-axis) and which is value (Y-axis)
            for eJson in TJSONArray(jData.GetPath('results').Items[iRes].GetPath('series').Items[iSer].GetPath('columns')) do
            begin
                if (eJson.Value.AsString = 'time') then
                begin
                    timecol := StrToInt(eJson.Key);
                end
                else
                begin
                    valuecol := StrToInt(eJson.Key);
                    valuename := eJson.Value.AsString;
                end;
            end;

            Memo1.Lines.Add('Time column: ' + timecol.toString);
            Memo1.Lines.Add('Value column: ' + valuecol.toString);
            Memo1.Lines.Add('Value name: ' + valuename);

            // iterate over "values"; each value is a logical point in the graph
            iPoint := 0;
            for eJson in TJSONArray(jData.GetPath('results').Items[iRes].GetPath('series').Items[iSer].GetPath('values')) do
            begin
                //Memo1.Lines.Add('point: ' + iPoint.ToString);
                tempDate := UnixToDateTime(eJson.Value.Items[timecol].AsInteger);
                //Memo1.Lines.Add('date: ' + FloatToStr(resultData[iRes][iSer].time[iPoint]));
                resultData[iRes][iSer].time[iPoint] := tempDate;

                if (not eJson.Value.Items[valuecol].IsNull) then
                begin
                    resultData[iRes][iSer].Value[iPoint] := eJson.Value.Items[valuecol].AsFloat;
                end
                else
                begin
                    Memo1.Lines.Add('date: ' + FloatToStr(resultData[iRes][iSer].time[iPoint]) + ' value: Null!');
                    resultData[iRes][iSer].Value[iPoint] := 0;
                end;

                //Memo1.Lines.Add('value: ' + FloatToStr(resultData[iRes][iSer].Value[iPoint]));

                //Memo1.Lines.Add('time: ' + FloatToStr(eJson.Value.Items[timecol].asFloat));
                //Memo1.Lines.Add('time: ' + FloatToStr(resultData[iRes][iSer].time[iPoint]));

                //Memo1.Lines.Add('data: ' + FloatToStr(eJson.Value.Items[valuecol].asFloat));
                //Memo1.Lines.Add('data: ' + FloatToStr(resultData[iRes][iSer].value[iPoint]));

                iPoint := iPoint + 1;
                //if ((iPoint mod 100) = 0) then
                //    Application.ProcessMessages;
            end;

            SetLength(ArChart1Sources, i + 1);
            //if not Assigned(ArChart1Sources[i]) then
            ArChart1Sources[i] := TInfluxDBSource.Create(Chart1);
            ArChart1Sources[i].reslt := iRes;
            ArChart1Sources[i].series := iSer;
            ArChart1Sources[i].timecol := timecol;
            ArChart1Sources[i].valuecol := valuecol;
            //ArChart1Sources[i].data:= resultData[iRes][iSer];
            ArChart1Sources[i].PointsNumber := numPoints;
            ArChart1Sources[i].OnGetChartDataItem := TGetChartDataItemEvent(@GetJSONPoint);

            SetLength(ArChart1Series, i + 1);
            //if not Assigned(ArChart1Series[i]) then
            ArChart1Series[i] := TLineSeries.Create(Chart1);
            ArChart1Series[i].Source := ArChart1Sources[i];
            ArChart1Series[i].LinePen.Color := Random($1000000);
            ArChart1Series[i].LinePen.Width := 1;
            Chart1.AddSeries(ArChart1Series[i]);
            i := i + 1;
        end;
    end;
    //Chart1.BottomAxis.Intervals.MaxLength := 100;
    //Chart1.BottomAxis.Intervals.MinLength := 100;
    //Chart1.BottomAxis.Marks.Format := '%6.8g';
    //Chart1.MarginsExternal.right := 100;
    //Chart1.Margins.right := 100;
end;

procedure TForm1.GetJSONPoint(ASource: TInfluxDBSource; AIndex: integer; var AItem: TChartDataItem);
begin
    //AItem.X := UnixToDateTime(jData.GetPath('results').Items[ASource.reslt].GetPath('series').Items[ASource.series].GetPath('values').Items[AIndex].Items[ASource.timecol].AsInteger);
    AItem.X := resultData[ASource.reslt, ASource.series].time[AIndex];
    // next line produces call trace
    //AItem.Y := jData.GetPath('results').Items[ASource.reslt].GetPath('series').Items[ASource.series].GetPath('values').Items[AIndex].Items[ASource.valuecol].AsFloat;
    AItem.Y := resultData[ASource.reslt, ASource.series].Value[AIndex];
end;

procedure TForm1.WebGetThreadTerminates(Sender: TObject);
begin
    StopButton.Enabled := False;
    MenuItem5.Enabled := False;
end;

procedure TForm1.OKButtonClick(Sender: TObject);
begin
    StartGraph(Sender);
end;

procedure TForm1.StartGraph(Sender: TObject);
begin
    dataRefresh := StrToInt(Edit5.Text);
    TWebGetThread.CreateOrRecycle(WebGetThread);
    WebGetThread.OnSyncRequestParams := @CopyRequest;
    WebGetThread.OnSynchResponseData := @CopyResponse;
    WebGetThread.OnTerminate := @WebGetThreadTerminates;
    StopButton.Enabled := True;
    MenuItem5.Enabled := True;
end;

procedure TForm1.Edit5Exit(Sender: TObject);
begin
    dataRefresh := StrToInt(Edit5.Text);
end;

procedure TForm1.CancelButtonClick(Sender: TObject);
begin
    Memo1.Clear;
end;

procedure TForm1.StopButtonClick(Sender: TObject);
begin
    StopGraph(Sender);
end;

procedure TForm1.StopGraph(Sender: TObject);
begin
    if Assigned(WebGetThread) then
        WebGetThread.Terminate;
end;

procedure TForm1.AutoRefreshOn(Sender: TObject);
begin
    MenuItem6.Checked := True;
    CheckBox1.Checked := True;
    //Edit5.Enabled := True;
    if (StrToInt(Edit5.Text) > 0) then
        StartGraph(Sender);
end;

procedure TForm1.AutoRefreshOff(Sender: TObject);
begin
    MenuItem6.Checked := False;
    CheckBox1.Checked := False;
    //Edit5.Enabled := False;
    StopGraph(Sender);
end;

end.
