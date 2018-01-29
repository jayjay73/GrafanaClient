unit Unit2;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
    LResources, ExtCtrls, ComCtrls;

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
        property DataSourceName: string read fDataSourceName write fDataSourceName;
        property URL: string read fURL write fURL;
        property user: string read fuser write fuser;
        property pass: string read fpass write fpass;
        property DB: string read fDB write fDB;
        property query: string read fquery write fquery;
        property epoch: string read fepoch write fepoch;
    end;

    TConfiguration = class(TComponent)
    private
        fLastDataSource: string;
    protected
        procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    published
        property lastDataSource: string read fLastDataSource write fLastDataSource;
    end;

    { TForm2 }

    TForm2 = class(TForm)
        Button1: TButton;
        Button2: TButton;
        Button3: TButton;
        Button4: TButton;
        Label5: TLabel;

        LabeledEdit1: TLabeledEdit;
        LabeledEdit2: TLabeledEdit;
        LabeledEdit3: TLabeledEdit;
        LabeledEdit4: TLabeledEdit;
        LabeledEdit5: TLabeledEdit;
        LabeledEdit6: TLabeledEdit;
        ListView1: TListView;
        Memo1: TMemo;
        procedure Button1Click(Sender: TObject);
        procedure Button3Click(Sender: TObject);
        procedure Button4Click(Sender: TObject);
        procedure Button4MouseEnter(Sender: TObject);
        procedure Button4MouseLeave(Sender: TObject);
        procedure FormCreate(Sender: TObject);
        procedure LabeledEdit_Exit(Sender: TObject);
        procedure ListView1Edited(Sender: TObject; Item: TListItem; var AValue: string);
        procedure ListView1Editing(Sender: TObject; Item: TListItem; var AllowEdit: boolean);
        procedure ListView1Exit(Sender: TObject);
        procedure ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: boolean);
        procedure OnFindClass(Reader: TReader; const AClassName: string; var ComponentClass: TComponentClass);
    private
        mouseOverMinusBtn: boolean;
        inItemEdit: boolean;
        lastSelectedDataSource: TListItem;
        procedure keepEditing(Data: PtrInt);
    public

    end;

var
    Form2: TForm2;
    Config: TConfiguration;

implementation

{$R *.lfm}

function StreamToString(AStream: TStream): string;
begin
    AStream.Position := 0;
    SetLength(Result, AStream.Size);
    if Result <> '' then
        AStream.Read(Result[1], length(Result));
end;

procedure LoadConfig;
var
    AStream: TFileStream;
begin
    if (not Assigned(Config)) then
    begin
        if FileExists('gcConfig.txt') then
        begin
            try
                AStream := TFileStream.Create('gcConfig.txt', fmOpenRead);
                ReadComponentFromTextStream(AStream, TComponent(Config), @Form2.OnFindClass, Form2);
            finally
                AStream.Free;
            end;
        end
        else
        begin
            Config := TConfiguration.Create(Form2);
        end;
    end;
end;

procedure TConfiguration.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
    i: integer;
begin
    if Root = self then
        for i := 0 to ComponentCount - 1 do
            if Components[i].GetParentComponent = nil then
                Proc(Components[i]);
end;

{ TForm2 }

procedure TForm2.FormCreate(Sender: TObject);
var
    i: integer;
    tempItem: TListItem;
begin
    for i := 0 to Config.ComponentCount - 1 do
    begin
        tempItem := Form2.ListView1.items.Add;
        tempItem.Caption := Config.Components[i].Name;
    end;
    mouseOverMinusBtn := False;
end;

procedure TForm2.LabeledEdit_Exit(Sender: TObject);
begin
    memo1.Lines.add('Edit1 onExit: ');
    if Assigned(ListView1.lastSelected) then
    begin
        memo1.Lines.add('write to this: ' + ListView1.lastSelected.Caption);
        TConfigItemDatasource(Config.FindComponent(ListView1.lastSelected.Caption)).URL := TLabeledEdit(Sender).Text;
    end;

end;

procedure TForm2.keepEditing(Data: PtrInt);
begin
    if not inItemEdit then
    begin
        TListItem(Data).Focused := True;
        TListItem(Data).Selected := True;
        ListView1.SetFocus;
        TListItem(Data).EditCaption;
    end;
end;

procedure TForm2.Button1Click(Sender: TObject);
var
    AStream: TFileStream;
begin
    try
        AStream := TFileStream.Create('gcConfig.txt', fmCreate);
        WriteComponentAsTextToStream(AStream, Config);
        //SaveStreamAsString(AStream);
        Memo1.Lines.Add(StreamToString(AStream));
    finally
        AStream.Free;
    end;
end;

procedure TForm2.Button3Click(Sender: TObject);
var
    Item: TListItem;
begin
    Item := ListView1.Items.Add;
    Item.Caption := '<new>';
    Item.Focused := True;
    Item.Selected := True;
    ListView1.SetFocus;
    Item.EditCaption;
end;

procedure TForm2.Button4Click(Sender: TObject);
var
    tmpItem: TListItem = nil;
    tmpConfigItem: TConfigItemDatasource = nil;
begin
    tmpItem := ListView1.Selected;
    if Assigned(tmpItem) then
    begin
        tmpConfigItem := TConfigItemDatasource(Config.FindComponent(tmpItem.Caption));
        Config.RemoveComponent(tmpConfigItem);
        ListView1.Items.Delete(tmpItem.Index);
    end;
end;

procedure TForm2.Button4MouseEnter(Sender: TObject);
begin
    mouseOverMinusBtn := True;
end;

procedure TForm2.Button4MouseLeave(Sender: TObject);
begin
    mouseOverMinusBtn := False;
end;

procedure TForm2.ListView1Edited(Sender: TObject; Item: TListItem; var aValue: string);
var
    i: integer;
    entryOK: boolean = True;
    duplicate: boolean = False;
    defaultvalue: boolean = False;
    empty: boolean = False;
    tmpConfItem: TConfigItemDatasource;
begin
    for i := 0 to ListView1.Items.Count - 1 do
    begin
        if ListView1.Items[i] = Item then
            continue;
        if SameText(ListView1.Items[i].Caption, aValue) then
        begin
            aValue := Item.Caption;
            entryOK := False;
            duplicate := True;
        end;
        if aValue = '<new>' then
        begin
            entryOK := False;
            defaultvalue := True;
        end;
        if aValue = '' then
        begin
            aValue := Item.Caption;
            entryOK := False;
            empty := True;
        end;
    end;
    if (defaultvalue and not mouseOverMinusBtn) or duplicate or empty then
    begin
        Application.QueueAsyncCall(@keepEditing, PtrInt(item));
        inItemEdit := False;
        Exit;
    end;
    if not mouseOverMinusBtn then
    begin
        if Assigned(Config.FindComponent(aValue)) then
        begin
            inItemEdit := False;
            Exit;
        end;
        memo1.Lines.add('create: ' + aValue);
        tmpConfItem := TConfigItemDatasource.Create(Config);
        tmpConfItem.Name := aValue;
        tmpConfItem := TConfigItemDatasource(Config.FindComponent(Item.Caption));
        if Assigned(tmpConfItem) then
            Config.RemoveComponent(tmpConfItem);
        LabeledEdit1.Enabled := True;
        LabeledEdit2.Enabled := True;
        LabeledEdit4.Enabled := True;
        LabeledEdit5.Enabled := True;
        LabeledEdit3.Enabled := True;
        LabeledEdit6.Enabled := True;
    end;
    inItemEdit := False;
end;

procedure TForm2.ListView1Editing(Sender: TObject; Item: TListItem; var AllowEdit: boolean);
begin
    inItemEdit := True;
end;

procedure TForm2.ListView1Exit(Sender: TObject);
begin
    lastSelectedDataSource := ListView1.Selected;
end;

procedure TForm2.ListView1SelectItem(Sender: TObject; Item: TListItem; Selected: boolean);
var
    tmpConfItem: TConfigItemDatasource;
begin
    memo1.Lines.add('ListView onSelect: ' + Item.Caption);
    if Selected then
    begin
        tmpConfItem := TConfigItemDatasource(Config.FindComponent(Item.Caption));
        if Assigned(tmpConfItem) then
        begin
            LabeledEdit1.Enabled := True;
            LabeledEdit1.Text := tmpConfItem.URL;
            LabeledEdit2.Enabled := True;
            LabeledEdit2.Text := tmpConfItem.user;
            LabeledEdit4.Enabled := True;
            LabeledEdit4.Text := tmpConfItem.pass;
            LabeledEdit5.Enabled := True;
            LabeledEdit5.Text := tmpConfItem.DB;
            LabeledEdit3.Enabled := True;
            LabeledEdit3.Text := tmpConfItem.query;
            LabeledEdit6.Enabled := True;
            LabeledEdit6.Text := tmpConfItem.epoch;
        end
        else
        begin
            // exit on <new>
            if not (Item.Caption = '<new>') and not (Item.Caption = '') then
            begin
                memo1.Lines.add('create: ' + Item.Caption);
                tmpConfItem := TConfigItemDatasource.Create(Config);
                tmpConfItem.Name := Item.Caption;
            end;
        end;
    end
    else
    begin
        tmpConfItem := TConfigItemDatasource(Config.FindComponent(Item.Caption));
        memo1.Lines.add('write in LV select: ' + Item.Caption);
        memo1.Lines.add('write in LV select: ' + LabeledEdit1.Text);
        if Assigned(tmpConfItem) then
        begin
            TConfigItemDatasource(Config.FindComponent(Item.Caption)).URL := LabeledEdit1.Text;
            tmpConfItem.user := LabeledEdit2.Text;
            tmpConfItem.pass := LabeledEdit4.Text;
            tmpConfItem.DB := LabeledEdit5.Text;
            tmpConfItem.query := LabeledEdit3.Text;
            tmpConfItem.epoch := LabeledEdit6.Text;
        end
        else
            memo1.Lines.add('no item!');

        LabeledEdit1.Clear;
        LabeledEdit1.Enabled := False;
        LabeledEdit2.Clear;
        LabeledEdit2.Enabled := False;
        LabeledEdit3.Clear;
        LabeledEdit3.Enabled := False;
        LabeledEdit4.Clear;
        LabeledEdit4.Enabled := False;
        LabeledEdit5.Clear;
        LabeledEdit5.Enabled := False;
        LabeledEdit6.Clear;
        LabeledEdit6.Enabled := False;
    end;
end;

procedure TForm2.OnFindClass(Reader: TReader; const AClassName: string; var ComponentClass: TComponentClass);
begin
    if CompareText(AClassName, 'TConfiguration') = 0 then
        ComponentClass := TConfiguration
    else
        if CompareText(AClassName, 'TConfigItemDatasource') = 0 then
            ComponentClass := TConfigItemDatasource;
end;

initialization
    begin
        LoadConfig;
    end;

end.
