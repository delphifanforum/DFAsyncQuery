# DFAsyncQuery - Background Database Queries for Delphi

![Delphi Supported Versions](https://img.shields.io/badge/Delphi-10.4%2B-blue)
![License](https://img.shields.io/github/license/YourUsername/DFAsyncQuery)

A thread-based asynchronous database query component for modern Delphi applications. This library allows you to execute database queries in the background without freezing the UI, making your applications more responsive.

## Features

- **Non-blocking UI**: Execute database queries in background threads
- **Thread safety**: Proper synchronization and thread management
- **Modern design**: Optimized for recent Delphi versions (10.4+)
- **Memory safety**: Automatic cleanup and resource management
- **Error handling**: Comprehensive exception management
- **Easy integration**: Simple API for existing applications

## Installation

1. Download or clone this repository
2. Add the `DFAsyncQuery.pas` unit to your project
3. Add `DFAsyncQuery` to your uses clause

## Usage Examples

### Basic Usage

```pascal
procedure TForm1.SearchButtonClick(Sender: TObject);
var
  QueryThread: TDFQueryThread;
begin
  // Create and execute a query thread
  QueryThread := DFQueryManager.CreateQueryThread(
    ADOConnection1.ConnectionString,
    'SELECT * FROM Customers WHERE LastName LIKE :LastName',
    CreateParameters('LastName', '%' + edtSearch.Text + '%'),
    DBGrid1,
    ADOQuery1,
    Self
  );
  
  // The thread automatically starts and updates the UI when complete
end;

// Helper function to create parameters
function TForm1.CreateParameters(const ParamName, ParamValue: string): TParameters;
begin
  ADOQuery1.Parameters.Clear;
  ADOQuery1.Parameters.CreateParameter(ParamName, ftString, pdInput, 50, ParamValue);
  Result := ADOQuery1.Parameters;
end;
```

### Multiple Concurrent Queries

```pascal
procedure TForm1.ExecuteMultipleQueries(Sender: TObject);
begin
  // Execute first query
  DFQueryManager.CreateQueryThread(
    ADOConnection1.ConnectionString,
    'SELECT * FROM Customers',
    nil,
    DBGrid1,
    ADOQuery1,
    Self
  );
  
  // Execute second query simultaneously
  DFQueryManager.CreateQueryThread(
    ADOConnection1.ConnectionString,
    'SELECT * FROM Orders',
    nil,
    DBGrid2,
    ADOQuery2,
    Self
  );
end;
```

### Thread Management

```pascal
procedure TForm1.FormDestroy(Sender: TObject);
begin
  // Clean up any running threads when closing the form
  DFQueryManager.CleanupThreads;
end;

procedure TForm1.btnCancelQueryClick(Sender: TObject);
begin
  // Cancel all active queries
  DFQueryManager.CleanupThreads;
  
  // Show current thread count
  ShowMessage('Active Threads: ' + IntToStr(DFQueryManager.ThreadCount));
end;
```

## API Reference

### TDFQueryThread

The main thread class for executing asynchronous queries.

#### Properties
- `ID`: Unique identifier for the thread
- `HasError`: Whether an error occurred during execution
- `ExceptionMessage`: Error message if HasError is true

### TDFQueryManager

Singleton manager that handles thread creation and lifecycle management.

#### Methods
- `CreateQueryThread`: Creates and starts a new query thread
- `CleanupThreads`: Terminates all running threads
- `RemoveThread`: Removes a specific thread by ID
- `ThreadCount`: Returns the number of active threads

## Advanced Usage

### Custom Error Handling

You can implement custom error handling by checking the thread's HasError property:

```pascal
procedure TForm1.ExecuteQueryWithErrorHandling;
var
  QueryThread: TDFQueryThread;
begin
  QueryThread := DFQueryManager.CreateQueryThread(
    ADOConnection1.ConnectionString,
    'SELECT * FROM NonExistentTable', // This will cause an error
    nil,
    DBGrid1,
    ADOQuery1,
    Self
  );
  
  // The thread will automatically show an error dialog,
  // but you can also implement custom error tracking or logging
end;
```

### Progress Indication

The component automatically handles cursor changes (hourglass during queries), but you can implement additional progress indication:

```pascal
procedure TForm1.btnSearchClick(Sender: TObject);
begin
  // Show progress panel
  pnlProgress.Visible := True;
  
  // Execute query
  DFQueryManager.CreateQueryThread(
    ADOConnection1.ConnectionString,
    'SELECT * FROM LargeTable',
    nil,
    DBGrid1,
    ADOQuery1,
    Self
  );
  
  // You'll need to handle hiding the progress panel when the query completes
  // This could be done using a custom event or timer
end;
```

## Requirements

- Delphi 10.4 or later
- VCL application
- ADO database components

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
