Dim objShell, objFSO, objFile, objFolder
Dim day, month, year, backupFolder, folder, localFolder

' Set folder name
folder = "SISE" ' Enclose SISE in double quotes

' Set log file path
logFilePath = "G:\Backups\ReportesSabanasSise\script_log.txt"

' Create objects
Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Get current date in the format YYYYMMDD
Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
Set colItems = objWMIService.ExecQuery("Select * From Win32_LocalTime")
For Each objItem in colItems
    day = Right("0" & objItem.Day, 2)
    month = Right("0" & objItem.Month, 2)
    year = objItem.Year
Next

' Create backup folder
backupFolder = "G:\Backups\ReportesSabanasSise\" & folder & day & month & year
If Not objFSO.FolderExists(backupFolder) Then
    objFSO.CreateFolder(backupFolder)
End If

' Log message function
Sub LogMessage(message)
    Dim logFile
    Set logFile = objFSO.OpenTextFile(logFilePath, 8, True) ' 8 appends to existing file
    logFile.WriteLine Now & " - " & message
    logFile.Close
End Sub

' Log script start
LogMessage "Script started."

' Execute batch files in a specific order
ExecuteBatchFile "G:\Backups\ReportesSabanasSise\1-GeneraMigracionPostulados.bat"
ExecuteBatchFile "G:\Backups\ReportesSabanasSise\2-GeneraMigracionOferentes.bat"
ExecuteBatchFile "G:\Backups\ReportesSabanasSise\3-generaComplementarias.bat"
ExecuteBatchFile "G:\Backups\ReportesSabanasSise\4-GeneraMigracionDireccionamientosNuevo.bat"
ExecuteBatchFile "G:\Backups\ReportesSabanasSise\5-GeneraMigracionEmpresas.bat"
ExecuteBatchFile "G:\Backups\ReportesSabanasSise\6-GeneraMigracionColocados.bat"
ExecuteBatchFile "G:\Backups\ReportesSabanasSise\7-GeneraFechaCorte.bat"
ExecuteBatchFile "G:\Backups\ReportesSabanasSise\8-GeneraMigracionVacantes.bat"
ExecuteBatchFile "G:\Backups\ReportesSabanasSise\9-GeneraMigracionParametrizacion.bat"
ExecuteBatchFile "G:\Backups\ReportesSabanasSise\10-GeneraSabanasIndicadores.bat"

' Log message about batch file execution
LogMessage "Batch files executed successfully."

' Copy txt files to the backup folder
CopyTxtFiles backupFolder

' Log message about copying files
LogMessage "TXT files copied to the backup folder."

' Display messages
WScript.Echo "ok Log_errores"
WScript.Echo "ok"

' Log script end
LogMessage "Script completed."

Sub ExecuteBatchFile(batchFileName)
    ' Execute batch file
    objShell.Run batchFileName, 1, True
End Sub

Sub CopyTxtFiles(destinationFolder)
    ' Copy txt files to the backup folder
    Dim sourceFolder, txtFile
    sourceFolder = "G:\Backups\ReportesSabanasSise\" ' Replace with the actual path of txt files

    If objFSO.FolderExists(sourceFolder) Then
        Set sourceFolderObj = objFSO.GetFolder(sourceFolder)
        For Each txtFile In sourceFolderObj.Files
            If LCase(objFSO.GetExtensionName(txtFile.Path)) = "txt" Then
                objFSO.CopyFile txtFile.Path, destinationFolder & "\", True
            End If
        Next
    End If
End Sub