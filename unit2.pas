unit Unit2;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
    LResources, Math;

type

    TConfigItemDatasource = class(TComponent)
    private
        fDataSourceName: string;
        fURL: string;
        fuser: string;
        fpass: string;
        fDB: string;
        fquery: string;
        fepoch: string;
    published
        property DataSourceName: string Read fDataSourceName Write fDataSourceName;
        property URL: string Read fURL Write fURL;
        property user: string Read fuser Write fuser;
        property pass: string Read fpass Write fpass;
        property DB: string Read fDB Write fDB;
        property query: string Read fquery Write fquery;
        property epoch: string Read fepoch Write fepoch;
    end;

    TConfiguration = class (TComponent)
        procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
        //destructor Destroy; override;
    end;

    { TForm2 }

    TForm2 = class(TForm)
        Button1: TButton;
        Button2: TButton;
        Edit1: TEdit;
        Edit2: TEdit;
        Edit3: TEdit;
        Edit4: TEdit;
        Edit6: TEdit;
        Edit7: TEdit;
        Label1: TLabel;
        Label2: TLabel;
        Label3: TLabel;
        Label4: TLabel;
        Label5: TLabel;
        Label6: TLabel;
        Label7: TLabel;
        Config: TConfiguration;
        Memo1: TMemo;
        procedure Button1Click(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure OnFindClass(Reader: TReader; const AClassName: string; var ComponentClass: TComponentClass);
    private

    public

    end;

var
    Form2: TForm2;

implementation

{$R *.lfm}

function StreamToString(AStream: TStream): string;
begin
  AStream.Position:=0;
  SetLength(Result,AStream.Size);
  if Result<>'' then
    AStream.Read(Result[1],length(Result));
end;

procedure TConfiguration.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  i: Integer;
begin
  if Root = self then
    for i:=0 to ComponentCount-1 do
      if Components[i].GetParentComponent = nil then
        Proc(Components[i]);
end;

//destructor TConfiguration.Destroy;
//var
//  i: integer;
//begin
//  for i:=0 to ComponentCount-1 do
//    begin
//         Components[i].free;
//    end;
//  inherited Destroy;
//end;

{ TForm2 }

procedure TForm2.Button1Click(Sender: TObject);
var
    tempConfigItem: TConfigItemDatasource = nil;
    AStream: TFileStream;
begin
     if (not Assigned(Config)) then
     begin
         Config:= TConfiguration.Create(Form2);
     end;
     if (not Assigned(tempConfigItem)) then
     begin
         tempConfigItem:= TConfigItemDatasource.Create(Config);
         tempConfigItem.DataSourceName:= 'datasource1';
         tempConfigItem.URL:= Edit1.Text;
         tempConfigItem.user:= Edit6.Text;
         tempConfigItem.pass:= Edit7.Text;
         tempConfigItem.DB:= Edit2.Text;
         tempConfigItem.query:= Edit3.Text;
         tempConfigItem.epoch:= Edit4.Text;
         //tempConfigItem.SetSubComponent(true);
     end;

     //Config.InsertComponent(tempConfigItem);
     //tempConfigItem.SetParentComponent(Config);

     Memo1.Lines.Add(IntToStr(Config.ComponentCount));


     AStream:=TFileStream.Create('gcConfig.txt', fmOpenWrite);
  try
    WriteComponentAsTextToStream(AStream, Config);
    //SaveStreamAsString(AStream);
    Memo1.lines.Add(StreamToString(AStream));
  finally
    AStream.Free;
  end;
end;

procedure TForm2.FormCreate(Sender: TObject);
var
    tempConfigItem: TConfigItemDatasource = nil;
    AStream: TFileStream;
begin
     if (not Assigned(Config)) then
     begin
         AStream:=TFileStream.Create('gcConfig.txt', fmOpenRead);
         ReadComponentFromTextStream(AStream, TComponent(Config), @OnFindClass, Form2);
     end;
     memo1.lines.add(TConfigItemDatasource(Config.Components[1]).datasourceName);
end;

procedure TForm2.OnFindClass(Reader: TReader; const AClassName: string; var ComponentClass: TComponentClass);
begin
  if CompareText(AClassName,'TConfiguration')=0 then
    ComponentClass:=TConfiguration
  else if CompareText(AClassName,'TConfigItemDatasource')=0 then
    ComponentClass:=TConfigItemDatasource;
end;

end.

