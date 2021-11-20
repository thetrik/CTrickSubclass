;
; CTrickSubclass assembly code
; By The trick 2021
; FASM compiler
;

format binary
use32

include "win32wx.inc"

struct tThreadParams
    pResetNotifierObject	   dd ?  ; When this object ref counter reaches zero it uninitializes all
    pVtbl			   dd ?
    dwRefCounter		   dd ?

    hWnd			   dd ?
    lPaused			   dd ?
    pHostObject 		   dd ?

    pfnRemoveWindowSubclass	   dd ?
    pfnDefSubclassProc		   dd ?
    pfnvbaRaiseEvent		   dd ?
    pfnEbMode			   dd ?

    pfnSubclassProc		   dd ?

    pfnQI			   dd ?  ; CResetNotifier virtual functions table
    pfnAddRef			   dd ?
    pfnRelease			   dd ?

ends

virtual at 0
  call initialize   ; disable removing proc
end virtual

proc initialize uses esi, pParams

    mov esi, [pParams]
    call @f
    @@:
    pop ecx

    lea eax, [ecx + subclass_proc - @b]
    mov [esi + tThreadParams.pfnSubclassProc], eax

    lea eax, [ecx + CResetNotifier_QueryInterface - @b]
    mov [esi + tThreadParams.pfnQI], eax

    lea eax, [ecx + CResetNotifier_AddRef - @b]
    mov [esi + tThreadParams.pfnAddRef], eax

    lea eax, [ecx + CResetNotifier_Release - @b]
    mov [esi + tThreadParams.pfnRelease], eax

    lea eax, [esi + tThreadParams.pfnQI]
    mov [esi + tThreadParams.pVtbl], eax

    lea eax, [esi + tThreadParams.pVtbl]
    mov [esi + tThreadParams.pResetNotifierObject], eax

    mov [esi + tThreadParams.dwRefCounter], 1

    mov eax, 1

    ret

endp

proc uninitialize uses esi, pParams

    mov esi, [pParams]

    .if [esi + tThreadParams.hWnd]

	stdcall [esi + tThreadParams.pfnRemoveWindowSubclass], [esi + tThreadParams.hWnd], [esi + tThreadParams.pfnSubclassProc], esi
	mov [esi + tThreadParams.hWnd], 0

    .endif

    ret

endp

proc subclass_proc uses esi edi, hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData

   mov esi, [uIdSubclass]

   .if [esi + tThreadParams.pHostObject]
       .if [esi + tThreadParams.lPaused] = 0

	   call [esi + tThreadParams.pfnEbMode]

	   .if eax = 0
	       stdcall uninitialize, esi
	       jmp .def_call
	   .elseif eax = 2
	       jmp .def_call
	   .endif

	   sub esp, 0x08
	   xor eax, eax

	   mov [esp], eax ; lRet
	   mov word [esp + 0x04], -1 ; bDefCall

	   ccall [esi + tThreadParams.pfnvbaRaiseEvent], [esi + tThreadParams.pHostObject], 1, 6, 0x400b, eax, addr esp + 0x58, eax, \
												  0x4003, eax, addr esp + 0x44, eax, \
												  3, eax, [lParam], eax, \
												  3, eax, [wParam], eax, \
												  3, eax, [uMsg], eax, \
												  3, eax, [hWnd], eax

	   add esp, 0x08

	   .if word [esp - 0x04]
	       jmp .def_call
	   .else
	       mov eax, [esp - 0x08]
	       ret
	   .endif

       .else
	   jmp .def_call
       .endif
   .else
       stdcall uninitialize, esi
     .def_call:
       stdcall [esi + tThreadParams.pfnDefSubclassProc], [hWnd], [uMsg], [wParam], [lParam]
   .endif

   ret

endp

CResetNotifier_QueryInterface:

    mov eax, [esp + 0x04]
    mov ecx, [esp + 0x0c]
    mov [ecx], eax
    stdcall CResetNotifier_AddRef, eax
    xor eax, eax
    ret 0x0c

CResetNotifier_AddRef:

    mov eax, [esp + 0x04]
    inc dword [eax + 0x04]
    mov eax, [eax + 0x04]
    ret 0x04

CResetNotifier_Release:

    mov eax, [esp + 0x04]
    dec dword [eax + 0x04]

    .if ZERO?

	push eax
	sub eax, 4
	stdcall uninitialize, eax
	pop eax

    .endif

    mov eax, [eax + 0x04]

    ret 0x04
