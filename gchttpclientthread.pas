unit gcHTTPClientThread;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, fphttpclient, HTTPDefs, DateUtils;

type
    TSyncRequestParamsEvent = procedure(var request: string; var refresh: integer) of object;
    TSyncResponseDataEvent = procedure(response: string) of object;

    TWebGetThread = class(TThread)
    private
        fRequest: string;
        fRefresh: integer;
        fAnswer: string;
        HTTPClient: TFPHttpClient;
        FSynchRequestParams: TSyncRequestParamsEvent;
        FSynchResponseData: TSyncResponseDataEvent;
        timeAtLAstRequest: TDateTime;
        procedure DoSyncRequestParams;
        procedure DoSyncResponseData;

    protected
        procedure Execute; override;
    public
        constructor Create(CreateSuspended: boolean);
        class procedure CreateOrRecycle(var instanceVar: TWebGetThread);
        property Refresh: integer read fRefresh write fRefresh;
        property OnSyncRequestParams: TSyncRequestParamsEvent read FSynchRequestParams write FSynchRequestParams;
        property OnSynchResponseData: TSyncResponseDataEvent read FSynchResponseData write FSynchResponseData;
    end;


implementation

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

procedure TWebGetThread.DoSyncRequestParams;
begin
    if Assigned(FSynchRequestParams) then
        FSynchRequestParams(fRequest, fRefresh);
end;

procedure TWebGetThread.DoSyncResponseData;
begin
    if Assigned(FSynchResponseData) then
        FSynchResponseData(fAnswer);
end;

procedure TWebGetThread.Execute;
//var
begin
    // get Request parameters
    Synchronize(@DoSyncRequestParams);
    while (not Terminated) do
    begin
        // make http call
        HttpClient := TFPHttpClient.Create(nil);
        try
            HttpClient.AllowRedirect := True;
            HttpClient.AddHeader('Content-Type', 'application/json');
            HttpClient.AddHeader('Accept', 'application/json');
            fAnswer := HttpClient.Get(fRequest);
        finally
            HttpClient.Free;
        end;
        // copy back result
        Synchronize(@DoSyncResponseData);
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

end.

