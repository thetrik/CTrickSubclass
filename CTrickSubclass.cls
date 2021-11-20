VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "CTrickSubclass"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
' //
' // CTrickSubclass.cls - class for window subclassing
' // © The trick, 2015-2021
' // Version 3.0
' //

Option Explicit
Option Base 0

Private Const MODULE_NAME               As String = "CTrickSubclass"
Private Const MODULE_VERSION            As String = "3.0"
Private Const ERR_NOT_INITIALIZED       As String = "Object isn't initialized"
Private Const E_NOT_VALID_STATE         As Long = &H8007139F
Private Const PAGE_EXECUTE_READWRITE    As Long = &H40&
Private Const CC_STDCALL                As Long = 4
Private Const INVALID_HANDLE_VALUE      As Long = -1
Private Const FILE_MAP_WRITE            As Long = &H2
Private Const FILE_MAP_READ             As Long = &H4
Private Const FILE_MAP_EXECUTE          As Long = &H20

Private Type tThreadParams

    ' // + ------------------------------------
    cResetNotifierObject        As IUnknown     ' // To uninitialize thread use this object instance
                                                ' // When ref counter reaches to zero it uninitializes code
                                                ' // It should avoid problems with End/Stop button
                                                ' // because the runtime always releases object variables
                                                ' // so we'll have the chance to uninitialize resources
    pVtbl                       As Long
    dwRefCounter                As Long
    ' // +-------------------------------------
    
    hWnd                        As Long         ' // Window handle
    lPaused                     As Long         ' // Paused subclassing
    pHostObject                 As Long         ' // Weak reference
    
    pfnAPIs(3)                  As Long
    
    pfnSubclassProc             As Long
    
    lIUnknownVTbl(2)            As Long

End Type

Private Declare Function MapViewOfFile Lib "kernel32" ( _
                         ByVal hFileMappingObject As Long, _
                         ByVal dwDesiredAccess As Long, _
                         ByVal dwFileOffsetHigh As Long, _
                         ByVal dwFileOffsetLow As Long, _
                         ByVal dwNumberOfBytesToMap As Long) As Long
Private Declare Function UnmapViewOfFile Lib "kernel32" ( _
                         ByVal lpBaseAddress As Long) As Long
Private Declare Function CreateFileMapping Lib "kernel32" _
                         Alias "CreateFileMappingW" ( _
                         ByVal hFile As Long, _
                         ByRef lpFileMappingAttributes As Any, _
                         ByVal flProtect As Long, _
                         ByVal dwMaximumSizeHigh As Long, _
                         ByVal dwMaximumSizeLow As Long, _
                         ByVal lpName As Long) As Long
Private Declare Function GetProcAddress Lib "kernel32" ( _
                         ByVal hModule As Long, _
                         ByVal lpProcName As String) As Long
Private Declare Function LoadLibrary Lib "kernel32" _
                         Alias "LoadLibraryW" ( _
                         ByVal lpModuleName As Long) As Long
Private Declare Function GetModuleHandle Lib "kernel32" _
                         Alias "GetModuleHandleW" ( _
                         ByVal lpModuleName As Long) As Long
Private Declare Function CloseHandle Lib "kernel32" ( _
                         ByVal hObject As Long) As Long
Private Declare Function DispCallFunc Lib "oleaut32.dll" ( _
                         ByRef pvInstance As Any, _
                         ByVal oVft As Long, _
                         ByVal cc As Long, _
                         ByVal vtReturn As VbVarType, _
                         ByVal cActuals As Long, _
                         ByRef prgvt As Any, _
                         ByRef prgpvarg As Any, _
                         ByRef pvargResult As Variant) As Long
Private Declare Function InterlockedIncrement Lib "kernel32" ( _
                         ByRef lpAddend As Any) As Long
Private Declare Function InterlockedDecrement Lib "kernel32" ( _
                         ByRef lpAddend As Any) As Long
Private Declare Function GetCurrentProcessId Lib "kernel32" () As Long
Private Declare Function PutMem4 Lib "msvbvm60" ( _
                         ByRef pDst As Any, _
                         ByVal lValue As Long) As Long
Private Declare Function GetMem4 Lib "msvbvm60" ( _
                         ByRef pSrc As Any, _
                         ByRef pDst As Any) As Long
Private Declare Function SetWindowSubclass Lib "Comctl32" ( _
                         ByVal hWnd As Long, _
                         ByVal pfnSubclass As Long, _
                         ByVal uIdSubclass As Long, _
                         ByRef dwRefData As Any) As Long
Private Declare Function RemoveWindowSubclass Lib "Comctl32" ( _
                         ByVal hWnd As Long, _
                         ByVal pfnSubclass As Long, _
                         ByVal uIdSubclass As Long) As Long
Private Declare Function DefSubclassProc Lib "Comctl32" ( _
                         ByVal hWnd As Long, _
                         ByVal uMsg As Long, _
                         ByVal wParam As Long, _
                         ByVal lParam As Long) As Long

Private Declare Sub memcpy Lib "kernel32" _
                    Alias "RtlMoveMemory" ( _
                    ByRef Destination As Any, _
                    ByRef Source As Any, _
                    ByVal Length As Long)
                    
Public Event WndProc( _
             ByVal hWnd As OLE_HANDLE, _
             ByVal lMsg As Long, _
             ByVal wParam As Long, _
             ByVal lParam As Long, _
             ByRef lRet As Long, _
             ByRef bDefCall As Boolean)

Private m_tParams   As tThreadParams
Private m_bIsInit   As Boolean
Private m_pCode     As Long
Private m_hMapping  As Long

Public Property Get hWnd() As OLE_HANDLE

    Const FUNCTION_NAME As String = "hWnd_get"
    
    If m_bIsInit Then
        hWnd = m_tParams.hWnd
    Else
        Err.Raise E_NOT_VALID_STATE, MODULE_NAME & "::" & FUNCTION_NAME, ERR_NOT_INITIALIZED
    End If
    
End Property

Public Property Get IsSubclassed() As Boolean

    Const FUNCTION_NAME As String = "IsSubclassed_get"
    
    If m_bIsInit Then
        IsSubclassed = m_tParams.hWnd
    Else
        Err.Raise E_NOT_VALID_STATE, MODULE_NAME & "::" & FUNCTION_NAME, ERR_NOT_INITIALIZED
    End If
    
End Property

Public Function PauseSubclass() As Boolean

    Const FUNCTION_NAME As String = "PauseSubclass"
    
    If m_bIsInit Then
        If m_tParams.lPaused = 0 Then
            PauseSubclass = True
            m_tParams.lPaused = 1
        End If
    Else
        Err.Raise E_NOT_VALID_STATE, MODULE_NAME & "::" & FUNCTION_NAME, ERR_NOT_INITIALIZED
    End If
    
End Function

Public Function ResumeSubclass() As Boolean

    Const FUNCTION_NAME As String = "ResumeSubclass"
    
    If m_bIsInit Then
        If m_tParams.lPaused Then
            ResumeSubclass = True
            m_tParams.lPaused = 0
        End If
    Else
        Err.Raise E_NOT_VALID_STATE, MODULE_NAME & "::" & FUNCTION_NAME, ERR_NOT_INITIALIZED
    End If
    
End Function

Public Property Get IsPaused() As Boolean

    Const FUNCTION_NAME As String = "IsPaused_get"
    
    If m_bIsInit Then
        IsPaused = m_tParams.lPaused
    Else
        Err.Raise E_NOT_VALID_STATE, MODULE_NAME & "::" & FUNCTION_NAME, ERR_NOT_INITIALIZED
    End If
    
End Property

Public Sub Hook( _
           ByVal hWnd As OLE_HANDLE)
           
    Const FUNCTION_NAME As String = "Hook"
 
    If m_bIsInit Then
        
        If m_tParams.hWnd Then
            Unhook
        End If
        
        m_tParams.hWnd = 0
        
        If SetWindowSubclass(hWnd, m_tParams.pfnSubclassProc, VarPtr(m_tParams), ByVal 0&) = 0 Then
            Err.Raise 7, MODULE_NAME & "::" & FUNCTION_NAME, "SetWindowSubclass failed"
        End If
        
        m_tParams.hWnd = hWnd
        
    Else
        Err.Raise E_NOT_VALID_STATE, MODULE_NAME & "::" & FUNCTION_NAME, ERR_NOT_INITIALIZED
    End If
    
End Sub

Public Sub Unhook()

    Const FUNCTION_NAME As String = "Unhook"
 
    If m_bIsInit Then
        
        If m_tParams.hWnd Then
        
            If RemoveWindowSubclass(m_tParams.hWnd, m_tParams.pfnSubclassProc, VarPtr(m_tParams)) = 0 Then
                Err.Raise 7, MODULE_NAME & "::" & FUNCTION_NAME, "RemoveWindowSubclass failed"
            End If
            
            m_tParams.hWnd = 0
            
        End If
        
    Else
        Err.Raise E_NOT_VALID_STATE, MODULE_NAME & "::" & FUNCTION_NAME, ERR_NOT_INITIALIZED
    End If
    
End Sub

Public Function CallDef( _
                ByVal hWnd As OLE_HANDLE, _
                ByVal lMsg As Long, _
                ByVal wParam As Long, _
                ByVal lParam As Long, _
                ByRef bStatus As Boolean) As Long
                
    Const FUNCTION_NAME As String = "CallDef"
    
    If m_bIsInit Then
        If m_tParams.hWnd = 0 Then
            Exit Function
        Else
        
            CallDef = DefSubclassProc(hWnd, lMsg, wParam, lParam)
            bStatus = True
            
        End If
    Else
        Err.Raise E_NOT_VALID_STATE, MODULE_NAME & "::" & FUNCTION_NAME, ERR_NOT_INITIALIZED
    End If
    
End Function

Private Sub Class_Initialize()

    Const FUNCTION_NAME As String = "Class_Initialize"
    
    Dim hMapping    As Long
    Dim pCode       As Long
    Dim lTemp       As Long
    Dim cOp(45)     As Currency
    Dim lCodeSize   As Long
    Dim hComctl32   As Long
    Dim hMSVBVM60   As Long
    Dim hVBA6       As Long
    Dim hr          As Long
    Dim vResult     As Variant
    Dim lIndex      As Long
    Dim sAPIName    As String
    Dim bIsInIDE    As Boolean
    Dim lCount      As Long
    
    Debug.Assert MakeTrue(bIsInIDE)
    
    hComctl32 = LoadLibrary(StrPtr("comctl32"))
    hMSVBVM60 = GetModuleHandle(StrPtr("msvbvm60"))
    
    If bIsInIDE Then
        hVBA6 = GetModuleHandle(StrPtr("vba6"))
    End If
    
    ' //
    ' // The code structure
    ' //
    ' // +--------+-----------------------------------+
    ' // | offset |           description             |
    ' // +--------+-----------------------------------+
    ' // |  0x00  | Reference counter                 |
    ' // |  0x04  | Mapping address of first instance |
    ' // |  0x08  | The asm code starts here          |
    ' // |  ....  |                                   |
    ' // +--------+-----------------------------------+
    ' //
    
    lCodeSize = (UBound(cOp) + 1) * 8 + 8
    
    cOp(0) = -172700121577779.7803@:  cOp(1) = 700803790855680.8192@:   cOp(2) = 32381283757.4281@:       cOp(3) = 8880706099704.8576@
    cOp(4) = 522461228120781.6192@:   cOp(5) = 508377703192199.1681@:   cOp(6) = -857365021913051.7204@:  cOp(7) = 443382.3494@
    cOp(8) = -441089100593967.8792@:  cOp(9) = 846995906805189.8372@:   cOp(10) = 620186570542432.3336@:  cOp(11) = 626874291154953.5999@
    cOp(12) = 20596.508@:             cOp(13) = -190689950864645.9042@: cOp(14) = 147676186889862.127@:   cOp(15) = -900719925218220.0576@
    cOp(16) = 15230408694.5918@:      cOp(17) = -6489317565906.8672@:   cOp(18) = 619989648405870.2934@:  cOp(19) = -147748414298680.988@
    cOp(20) = 849688782354884.2759@:  cOp(21) = 259535074382164.2883@:  cOp(22) = 583666403534889.1494@:  cOp(23) = -4953584075692.6977@
    cOp(24) = 850260259709754.0725@:  cOp(25) = 147436517215347.0992@:  cOp(26) = 491014245965020.6288@:  cOp(27) = 576460779796930.9778@
    cOp(28) = 82199524659143.1821@:   cOp(29) = -7165954328048.4288@:   cOp(30) = 783753342645325.5286@:  cOp(31) = -27796037319571.7501@
    cOp(32) = -842766526041578.1888@: cOp(33) = 178420980956634.426@:   cOp(34) = 620312248530782.8992@:  cOp(35) = 147436592801036.2344@
    cOp(36) = 850252832242876.1599@:  cOp(37) = -441089059744232.268@:  cOp(38) = 551550672246059.8296@:  cOp(39) = 166280520433.9748@
    cOp(40) = -843072447184994.304@:  cOp(41) = 465081571739304.8644@:  cOp(42) = 29843883910475.0084@:   cOp(43) = -169242102482309.7089@
    cOp(44) = 641312586460930.458@:   cOp(45) = 2043492.7755@:
        
    With m_tParams
        
        If bIsInIDE Then
            lCount = UBound(.pfnAPIs) + 1
        Else
            lCount = UBound(.pfnAPIs)
        End If
        
        For lIndex = 0 To lCount - 1
            
            Select Case lIndex
            
            Case 0:     sAPIName = "RemoveWindowSubclass"
            Case 1:     sAPIName = "DefSubclassProc"
            Case 2:     sAPIName = "__vbaRaiseEvent"
            Case 3:     sAPIName = "EbMode"
           
            End Select
            
            If lIndex < 2 Then
                .pfnAPIs(lIndex) = GetProcAddress(hComctl32, sAPIName)
            ElseIf lIndex < 3 Then
                .pfnAPIs(lIndex) = GetProcAddress(hMSVBVM60, sAPIName)
            Else
                .pfnAPIs(lIndex) = GetProcAddress(hVBA6, sAPIName)
            End If
            
            If .pfnAPIs(lIndex) = 0 Then
                Err.Raise 453, MODULE_NAME & "::" & FUNCTION_NAME
            End If
            
        Next
        
        .pHostObject = ObjPtr(Me)
        
    End With
    
    hMapping = CreateFileMapping(INVALID_HANDLE_VALUE, ByVal 0&, PAGE_EXECUTE_READWRITE, 0, lCodeSize, _
                                 StrPtr(MODULE_NAME & "#" & MODULE_VERSION & "_" & CStr(GetCurrentProcessId())))
    If hMapping = 0 Then
        Err.Raise 7, MODULE_NAME & "::" & FUNCTION_NAME, "CreateFileMapping failed"
    End If
    
    pCode = MapViewOfFile(hMapping, FILE_MAP_READ Or FILE_MAP_WRITE Or FILE_MAP_EXECUTE, 0, 0, 0)
    If pCode = 0 Then
        CloseHandle hMapping
        Err.Raise 7, MODULE_NAME & "::" & FUNCTION_NAME, "MapViewOfFile failed"
    End If
    
    ' // Increment ref counter
    If InterlockedIncrement(ByVal pCode) = 1 Then
        ' // Put the address for the first instance
        PutMem4 ByVal pCode + 4, pCode
    Else
        
        ' // There is already mapped region. Use previous mapping instead current one
        lTemp = pCode
        GetMem4 ByVal pCode + 4, pCode
        UnmapViewOfFile lTemp
        CloseHandle hMapping
        hMapping = 0
        
    End If
    
    ' // Copy asm code
    memcpy ByVal pCode + 8, cOp(0), lCodeSize - 4
    
    ' // Run initialization
    hr = DispCallFunc(ByVal 0&, pCode + 8, CC_STDCALL, vbLong, 1, vbLong, VarPtr(CVar(VarPtr(m_tParams))), vResult)
    
    If hr < 0 Or vResult = 0 Then
        
        CloseHandle hMapping
        
        If InterlockedDecrement(ByVal pCode) = 0 Then
            UnmapViewOfFile pCode
        End If
        
        If hr < 0 Then
            Err.Raise hr, MODULE_NAME & "::" & FUNCTION_NAME, "DispCallFunc failed"
        Else
            Err.Raise 5, MODULE_NAME & "::" & FUNCTION_NAME, "Initialization failed"
        End If
        
    End If
    
    m_pCode = pCode
    m_hMapping = hMapping
    m_bIsInit = True
    
End Sub

Private Sub Class_Terminate()

    If m_bIsInit Then
        
        Set m_tParams.cResetNotifierObject = Nothing
        
        ' // Check if it's a last instance
        If InterlockedDecrement(ByVal m_pCode) = 0 Then
            UnmapViewOfFile m_pCode
        End If
        
        If m_hMapping Then
            CloseHandle m_hMapping
        End If
        
    End If
        
End Sub

Private Function MakeTrue( _
                 ByRef bValue As Boolean) As Boolean
    bValue = True
    MakeTrue = True
End Function

