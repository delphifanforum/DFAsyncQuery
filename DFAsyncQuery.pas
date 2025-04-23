unit DFAsyncQuery;

interface

uses
  System.Classes, System.SysUtils, Vcl.Forms, Vcl.Controls, Vcl.Dialogs, 
  Vcl.Grids, Vcl.DBGrids, Data.DB, Data.Win.ADODB, Winapi.Windows, 
  System.Generics.Collections;

type
  /// <summary>
  /// Thread for asynchronous database queries
  /// </summary>
  TDFQueryThread = class(TThread)
  private
    FADOQ: TADOQuery;
    FSQL: string;
    FID: Integer;
    FOriginGrid: TDBGrid;
    FOriginQuery: TADOQuery;
    FOriginForm: TForm;
    FConnString: string;
    FParameters: TParameters;
    FExceptionMessage: string;
    FHasError: Boolean;
  protected
    procedure Execute; override;
    procedure ExecUpdate;
    procedure HandleException;
  public
    constructor Create(const AConnString, ASQL: string; IDThread: Integer; 
                      AParameters: TParameters; AOriginGrid: TDBGrid; 
                      AOriginQuery: TADOQuery; AOriginForm: TForm);
    destructor Destroy; override;
    
    property ID: Integer read FID;
    property HasError: Boolean read FHasError;
    property ExceptionMessage: string read FExceptionMessage;
  end;

  /// <summary>
  /// Manager class for query thread creation and lifecycle management
  /// </summary>
  TDFQueryManager = class
  private
    FThreads: TDictionary<Integer, TDFQueryThread>;
    FLock: TCriticalSection;
    FNextID: Integer;
    
    function GetNextID: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure CleanupThreads;
    function CreateQueryThread(const AConnString, ASQL: string; 
                            AParameters: TParameters; AGrid: TDBGrid; 
                            AQuery: TADOQuery; AForm: TForm): TDFQueryThread;
    procedure RemoveThread(ThreadID: Integer);
    function ThreadCount: Integer;
  end;

var 
  DFQueryManager: TDFQueryManager;

implementation

{ TDFQueryThread }

constructor TDFQueryThread.Create(const AConnString, ASQL: string; IDThread: Integer;
  AParameters: TParameters; AOriginGrid: TDBGrid; AOriginQuery: TADOQuery; 
  AOriginForm: TForm);
begin
  inherited Create(True);  // Create suspended
  
  FreeOnTerminate := True;
  FID := IDThread;
  FOriginGrid := AOriginGrid;
  FOriginQuery := AOriginQuery;
  FOriginForm := AOriginForm;
  FSQL := ASQL;
  FConnString := AConnString;
  FHasError := False;
  
  // Clone parameters to avoid potential race conditions
  FADOQ := TADOQuery.Create(nil);
  FADOQ.ConnectionString := FConnString;
  FADOQ.SQL.Text := FSQL;
  
  if Assigned(AParameters) then
  begin
    for var i := 0 to AParameters.Count - 1 do
    begin
      FADOQ.Parameters[i].Name := AParameters[i].Name;
      FADOQ.Parameters[i].DataType := AParameters[i].DataType;
      FADOQ.Parameters[i].Value := AParameters[i].Value;
    end;
  end;
  
  // Show hourglass cursor when thread starts
  TThread.Synchronize(nil, procedure
  begin
    Screen.Cursor := crHourGlass;
  end);
end;

destructor TDFQueryThread.Destroy;
begin
  // Clean up ADO query
  if Assigned(FADOQ) then
  begin
    try
      FADOQ.Close;
    except
      // Ignore exceptions during cleanup
    end;
    FADOQ.Free;
    FADOQ := nil;
  end;

  // Remove this thread from the manager
  if Assigned(DFQueryManager) then
    DFQueryManager.RemoveThread(FID);
    
  inherited;
end;

procedure TDFQueryThread.Execute;
begin
  try
    if not Terminated then
    begin
      FADOQ.Open;
      
      // Only update the UI if not terminated
      if not Terminated then
        Synchronize(ExecUpdate);
    end;
  except
    on E: Exception do
    begin
      FHasError := True;
      FExceptionMessage := E.Message;
      OutputDebugString(PChar('Error in thread ' + IntToStr(FID) + ': ' + E.Message));
      Synchronize(HandleException);
    end;
  end;
end;

procedure TDFQueryThread.ExecUpdate;
begin
  if Assigned(FOriginForm) and not Terminated and FOriginForm.HandleAllocated then
  begin
    try
      if Assigned(FOriginQuery) and FOriginQuery.HandleAllocated and 
         Assigned(FADOQ) and FADOQ.Active then
      begin
        FOriginQuery.DisableControls;
        try
          FOriginQuery.Recordset := FADOQ.Recordset;
          
          if Assigned(FOriginGrid) and FOriginGrid.HandleAllocated then
            FOriginGrid.Refresh;
        finally
          FOriginQuery.EnableControls;
        end;
      end;
    finally
      Screen.Cursor := crDefault;
    end;
  end;
end;

procedure TDFQueryThread.HandleException;
begin
  Screen.Cursor := crDefault;
  
  if Assigned(FOriginForm) and FOriginForm.HandleAllocated then
    MessageDlg('Query Error: ' + FExceptionMessage, mtError, [mbOK], 0);
end;

{ TDFQueryManager }

constructor TDFQueryManager.Create;
begin
  inherited;
  FThreads := TDictionary<Integer, TDFQueryThread>.Create;
  FLock := TCriticalSection.Create;
  FNextID := 1;
end;

destructor TDFQueryManager.Destroy;
begin
  CleanupThreads;
  
  FThreads.Free;
  FLock.Free;
  
  inherited;
end;

function TDFQueryManager.GetNextID: Integer;
begin
  FLock.Enter;
  try
    Result := FNextID;
    Inc(FNextID);
  finally
    FLock.Leave;
  end;
end;

procedure TDFQueryManager.CleanupThreads;
var
  ThreadIDs: TArray<Integer>;
  ThreadID: Integer;
begin
  FLock.Enter;
  try
    // Get all thread IDs
    ThreadIDs := FThreads.Keys.ToArray;
  finally
    FLock.Leave;
  end;
  
  // Terminate each thread
  for ThreadID in ThreadIDs do
  begin
    FLock.Enter;
    try
      if FThreads.ContainsKey(ThreadID) then
        FThreads[ThreadID].Terminate;
    finally
      FLock.Leave;
    end;
  end;
end;

function TDFQueryManager.CreateQueryThread(const AConnString, ASQL: string;
  AParameters: TParameters; AGrid: TDBGrid; AQuery: TADOQuery; 
  AForm: TForm): TDFQueryThread;
var
  NewThreadID: Integer;
  NewThread: TDFQueryThread;
begin
  NewThreadID := GetNextID;
  
  // Create new thread
  NewThread := TDFQueryThread.Create(
    AConnString, ASQL, NewThreadID, AParameters, AGrid, AQuery, AForm
  );
  
  // Add to dictionary
  FLock.Enter;
  try
    FThreads.Add(NewThreadID, NewThread);
  finally
    FLock.Leave;
  end;
  
  // Start the thread
  NewThread.Start;
  
  Result := NewThread;
end;

procedure TDFQueryManager.RemoveThread(ThreadID: Integer);
begin
  FLock.Enter;
  try
    if FThreads.ContainsKey(ThreadID) then
      FThreads.Remove(ThreadID);
  finally
    FLock.Leave;
  end;
end;

function TDFQueryManager.ThreadCount: Integer;
begin
  FLock.Enter;
  try
    Result := FThreads.Count;
  finally
    FLock.Leave;
  end;
end;

initialization
  DFQueryManager := TDFQueryManager.Create;

finalization
  if Assigned(DFQueryManager) then
  begin
    DFQueryManager.Free;
    DFQueryManager := nil;
  end;

end.