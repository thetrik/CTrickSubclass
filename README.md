# CTrickSubclass
 

## Class for safe subclassing windows

Hello everyone!

This class allows to do subclassing very easy. It fires the event **WndProc** upon receiving a message by a window. The event has ***lRet*** output parameter where you can specify the message return value but you should set ***bDefCall*** parameter to False in order to bypass default procedure. By the default ***bDefCall*** equals True that means the default procedure calls always. To subclass a window you should call **Hook** method and pass its handle. You can pause / resume handling by calling corresponding **PauseSubclass** / **ResumeSubclass** methods. **CallDef** method allows to call the default window procedure at any time.

## How does this work?

The class uses an assembly thunk to transmit "a flat" call to a VB object event. The assembly thunk also solves the Stop button / End statement problems so the class is quite stable i think. Additionally it stops event firing when a project is in step-by-step debugging mode.

Thank you all for attention!

Best Regards,

The trick.