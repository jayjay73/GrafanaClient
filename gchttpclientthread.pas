unit gcHTTPClientThread;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, fphttpclient, HTTPDefs, DateUtils;

type
    TSyncRequestParamsEvent = procedure(var request: string; var refresh: integer; var user, pass: string) of object;
    TSyncResponseDataEvent = procedure(response: string; cookies: TStrings) of object;

    TWebGetThread = class(TThread)
    private
        fRequest: string;
        fRefresh: integer;
        fAnswer: string;
        fUser, fPass: string;
        fCookieJar: TStrings;
        getNewRequest: boolean;
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
        property CookieJar: TStrings read fCookieJar write fCookieJar;
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
        end
        else
            instanceVar.getNewRequest := True;
end;

constructor TWebGetThread.Create(CreateSuspended: boolean);
begin
    inherited Create(CreateSuspended);
    FreeOnTerminate := False;
    fRefresh := 0;
    getNewRequest := True;
end;

procedure TWebGetThread.DoSyncRequestParams;
begin
    if Assigned(FSynchRequestParams) then
        FSynchRequestParams(fRequest, fRefresh, fUser, fPass);
    getNewRequest := False;
end;

procedure TWebGetThread.DoSyncResponseData;
begin
    if Assigned(FSynchResponseData) then
        FSynchResponseData(fAnswer, fCookieJar);
end;

procedure TWebGetThread.Execute;
//var
begin
    // get Request parameters

    while (not Terminated) do
    begin
        if (getNewRequest) then
            // next line produces call trace
            Synchronize(@DoSyncRequestParams);
        // make http call
        HttpClient := TFPHttpClient.Create(nil);
        try
            HttpClient.AllowRedirect := True;
            HttpClient.UserName := fUser;
            HttpClient.Password := fPass;
            HttpClient.AddHeader('Content-Type', 'application/json');
            HttpClient.AddHeader('Accept', 'application/json');
            fAnswer := HttpClient.Get(fRequest);
            fCookieJar:= TStringList.Create;
            fCookieJar.Text:= HttpClient.Cookies.Text;

        finally
            HttpClient.Free;
        end;
        // copy back result
        Synchronize(@DoSyncResponseData);
        if (fRefresh = 0) then
            Terminate;
        timeAtLastRequest := Now;
        while (not Terminated and not getNewRequest) do
        begin
            if (MilliSecondsBetween(timeAtLastRequest, Now) > fRefresh) then
                break;
            Sleep(100);
        end;
    end;
end;

end.

