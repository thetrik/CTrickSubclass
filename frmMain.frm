VERSION 5.00
Begin VB.Form frmMain 
   Caption         =   "CTrickSubclass test"
   ClientHeight    =   3345
   ClientLeft      =   120
   ClientTop       =   450
   ClientWidth     =   4560
   LinkTopic       =   "Form1"
   ScaleHeight     =   223
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   304
   StartUpPosition =   3  'Windows Default
End
Attribute VB_Name = "frmMain"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private Type POINTAPI
    x               As Long
    y               As Long
End Type

Private Type MINMAXINFO
    ptReserved      As POINTAPI
    ptMaxSize       As POINTAPI
    ptMaxPosition   As POINTAPI
    ptMinTrackSize  As POINTAPI
    ptMaxTrackSize  As POINTAPI
End Type

Private Declare Sub CopyMemory Lib "kernel32" _
                    Alias "RtlMoveMemory" ( _
                    ByRef Destination As Any, _
                    ByRef Source As Any, _
                    ByVal Length As Long)

Private Const WM_GETMINMAXINFO  As Long = &H24
Private Const WM_MOUSEWHEEL     As Long = &H20A

Private WithEvents m_cFormHook  As CTrickSubclass
Attribute m_cFormHook.VB_VarHelpID = -1
Private m_lWheelValue  As Long

Private Sub Form_Load()

    Set m_cFormHook = New CTrickSubclass
    m_cFormHook.Hook Me.hWnd
    m_lWheelValue = 100

End Sub

Private Sub Form_Paint()

    Cls
    
    Print
    Print "1. Change form size."
    Print "2. Scroll mouse wheel."
    Print "3. You can press Stop button / use End statement."
    
    Circle (ScaleWidth / 2, ScaleHeight / 2), m_lWheelValue
    
End Sub

Private Sub Form_Resize()
    Refresh
End Sub

Private Sub m_cFormHook_WndProc( _
            ByVal hWnd As OLE_HANDLE, _
            ByVal lMsg As Long, _
            ByVal wParam As Long, _
            ByVal lParam As Long, _
            ByRef lRet As Long, _
            ByRef bDefCall As Boolean)
                   
    Select Case lMsg
    
    Case WM_GETMINMAXINFO
        Dim tMinMax As MINMAXINFO

        CopyMemory tMinMax, ByVal lParam, Len(tMinMax)
        tMinMax.ptMaxTrackSize.x = 500   ' Maximum size 500õ500
        tMinMax.ptMaxTrackSize.y = 500
        tMinMax.ptMinTrackSize.x = 250   ' Minimum size 350õ350
        tMinMax.ptMinTrackSize.y = 250
        CopyMemory ByVal lParam, tMinMax, Len(tMinMax)
        
        bDefCall = False
        
    Case WM_MOUSEWHEEL
    
        Dim lDir    As Long

        lDir = (wParam And &HFFFF0000) \ &H780000

        m_lWheelValue = m_lWheelValue + lDir
        Refresh
        
    Case Else
        bDefCall = True
    End Select
    
End Sub
