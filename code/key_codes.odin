package main

import "vendor:glfw"

Mod_Code :: enum {
    First,
    Shift,
    Ctrl,
    Alt,
    Super, 
    CapsLock,
    NumLock,
    Last,
    Unknown,
}

Button_Code :: enum {
    First,
    Left,
    Right,
    Middle,
    Num4,
    Num5,
    Num6,
    Num7,
    Num8,
    Last,
    Unknown,
}

Key_Code :: enum {
    First       ,
    Space       ,
    Apostrophe  ,
    Comma       ,
    Minus       ,
    Period      ,
    Slash       ,
    Num0        ,
    Num1        ,
    Num2        ,
    Num3        ,
    Num4        ,
    Num5        ,
    Num6        ,
    Num7        ,
    Num8        ,
    Num9        ,
    Semicolon   ,
    Equal       ,
    A           ,
    B           ,
    C           ,
    D           ,
    E           ,
    F           ,
    G           ,
    H           ,
    I           ,
    J           ,
    K           ,
    L           ,
    M           ,
    N           ,
    O           ,
    P           ,
    Q           ,
    R           ,
    S           ,
    T           ,
    U           ,
    V           ,
    W           ,
    X           ,
    Y           ,
    Z           ,
    LeftBracket ,
    Backslash   ,
    Grave       ,
    World1      ,
    World2      ,
    Escape      ,
    Enter       ,
    Tab         ,
    Backspace   ,
    Insert      ,
    Delete      ,
    Right       ,
    Left        ,
    Down        ,
    Up          ,
    PageUp      ,
    PageDown    ,
    Home        ,
    End         ,
    CapsLock    ,
    NumLock     ,
    PrintScreen ,
    Pause       ,
    F1          ,
    F2          ,
    F3          ,
    F4          ,
    F5          ,
    F6          ,
    F7          ,
    F8          ,
    F9          ,
    F10         ,
    F11         ,
    F12         ,
    F13         ,
    F14         ,
    F15         ,
    F16         ,
    F17         ,
    F18         ,
    F19         ,
    F20         ,
    F21         ,
    F22         ,
    F23         ,
    F24         ,
    F25         ,
    Kp0         ,
    Kp1         ,
    Kp2         ,
    Kp3         ,
    Kp4         ,
    Kp5         ,
    Kp6         ,
    Kp7         ,
    Kp8         ,
    Kp9         ,
    KpDecimal   ,
    KpDivide    ,
    KpMultiply  ,
    KpSubtract  ,
    KpAdd       ,
    KpEnter     ,
    KpEqual     ,
    LeftShift   ,
    LeftCtrl    ,
    LeftAlt     ,
    LeftSuper   ,
    Menu        ,
    Last        ,
    Unknown     ,
} 

button_code_from_glfw :: #force_inline proc(glfw_button: i32) -> Button_Code {
    switch glfw_button  {
        case glfw.MOUSE_BUTTON_1: return .Left
        case glfw.MOUSE_BUTTON_2: return .Right
        case glfw.MOUSE_BUTTON_3: return .Middle
        case glfw.MOUSE_BUTTON_4: return .Num4
        case glfw.MOUSE_BUTTON_5: return .Num5
        case glfw.MOUSE_BUTTON_6: return .Num6
        case glfw.MOUSE_BUTTON_7: return .Num7
        case glfw.MOUSE_BUTTON_8: return .Num8
    }
    return .Unknown
}

mod_code_from_glfw :: #force_inline proc(glfw_mod: i32) -> Mod_Code {
    switch glfw_mod {
        case glfw.MOD_SHIFT: return .Shift
        case glfw.MOD_CONTROL: return .Ctrl
        case glfw.MOD_ALT: return .Alt
        case glfw.MOD_SUPER: return .Super
        case glfw.MOD_CAPS_LOCK: return .CapsLock
        case glfw.MOD_NUM_LOCK: return .NumLock
    }
    return .Unknown
}

key_code_from_glfw :: #force_inline proc(glfw_key: i32) -> Key_Code {
    switch glfw_key {                     
        case glfw.KEY_SPACE:                return .Space                        
        case glfw.KEY_APOSTROPHE:           return .Apostrophe                        
        case glfw.KEY_COMMA:                return .Comma                        
        case glfw.KEY_MINUS:                return .Minus                        
        case glfw.KEY_PERIOD:               return .Period                        
        case glfw.KEY_SLASH:                return .Slash                        
        case glfw.KEY_0:                    return .Num0                     
        case glfw.KEY_1:                    return .Num1                     
        case glfw.KEY_2:                    return .Num2                     
        case glfw.KEY_3:                    return .Num3                     
        case glfw.KEY_4:                    return .Num4                     
        case glfw.KEY_5:                    return .Num5                     
        case glfw.KEY_6:                    return .Num6                     
        case glfw.KEY_7:                    return .Num7                     
        case glfw.KEY_8:                    return .Num8                     
        case glfw.KEY_9:                    return .Num9                     
        case glfw.KEY_SEMICOLON:            return .Semicolon                        
        case glfw.KEY_EQUAL:                return .Equal                        
        case glfw.KEY_A:                    return .A                        
        case glfw.KEY_B:                    return .B                        
        case glfw.KEY_C:                    return .C                        
        case glfw.KEY_D:                    return .D                        
        case glfw.KEY_E:                    return .E                        
        case glfw.KEY_F:                    return .F                        
        case glfw.KEY_G:                    return .G                        
        case glfw.KEY_H:                    return .H                        
        case glfw.KEY_I:                    return .I                        
        case glfw.KEY_J:                    return .J                        
        case glfw.KEY_K:                    return .K                        
        case glfw.KEY_L:                    return .L                        
        case glfw.KEY_M:                    return .M                        
        case glfw.KEY_N:                    return .N                        
        case glfw.KEY_O:                    return .O                        
        case glfw.KEY_P:                    return .P                        
        case glfw.KEY_Q:                    return .Q                        
        case glfw.KEY_R:                    return .R                        
        case glfw.KEY_S:                    return .S                        
        case glfw.KEY_T:                    return .T                        
        case glfw.KEY_U:                    return .U                        
        case glfw.KEY_V:                    return .V                        
        case glfw.KEY_W:                    return .W                        
        case glfw.KEY_X:                    return .X                        
        case glfw.KEY_Y:                    return .Y                        
        case glfw.KEY_Z:                    return .Z                        
        case glfw.KEY_LEFT_BRACKET:         return .LeftBracket                         
        case glfw.KEY_BACKSLASH:            return .Backslash                        
        case glfw.KEY_GRAVE_ACCENT:         return .Grave                               
        case glfw.KEY_WORLD_1:              return .World1                         
        case glfw.KEY_WORLD_2:              return .World2                         
        case glfw.KEY_ESCAPE:               return .Escape                        
        case glfw.KEY_ENTER:                return .Enter                        
        case glfw.KEY_TAB:                  return .Tab                        
        case glfw.KEY_BACKSPACE:            return .Backspace                        
        case glfw.KEY_INSERT:               return .Insert                        
        case glfw.KEY_DELETE:               return .Delete                        
        case glfw.KEY_RIGHT:                return .Right                        
        case glfw.KEY_LEFT:                 return .Left                        
        case glfw.KEY_DOWN:                 return .Down                        
        case glfw.KEY_UP:                   return .Up                        
        case glfw.KEY_PAGE_UP:              return .PageUp                         
        case glfw.KEY_PAGE_DOWN:            return .PageDown                         
        case glfw.KEY_HOME:                 return .Home                        
        case glfw.KEY_END:                  return .End                        
        case glfw.KEY_CAPS_LOCK:            return .CapsLock                         
        case glfw.KEY_NUM_LOCK:             return .NumLock                         
        case glfw.KEY_PRINT_SCREEN:         return .PrintScreen                         
        case glfw.KEY_PAUSE:                return .Pause                        
        case glfw.KEY_F1:                   return .F1                        
        case glfw.KEY_F2:                   return .F2                        
        case glfw.KEY_F3:                   return .F3                        
        case glfw.KEY_F4:                   return .F4                        
        case glfw.KEY_F5:                   return .F5                        
        case glfw.KEY_F6:                   return .F6                        
        case glfw.KEY_F7:                   return .F7                        
        case glfw.KEY_F8:                   return .F8                        
        case glfw.KEY_F9:                   return .F9                        
        case glfw.KEY_F10:                  return .F10                        
        case glfw.KEY_F11:                  return .F11                        
        case glfw.KEY_F12:                  return .F12                        
        case glfw.KEY_F13:                  return .F13                        
        case glfw.KEY_F14:                  return .F14                        
        case glfw.KEY_F15:                  return .F15                        
        case glfw.KEY_F16:                  return .F16                        
        case glfw.KEY_F17:                  return .F17                        
        case glfw.KEY_F18:                  return .F18                        
        case glfw.KEY_F19:                  return .F19                        
        case glfw.KEY_F20:                  return .F20                        
        case glfw.KEY_F21:                  return .F21                        
        case glfw.KEY_F22:                  return .F22                        
        case glfw.KEY_F23:                  return .F23                        
        case glfw.KEY_F24:                  return .F24                        
        case glfw.KEY_F25:                  return .F25                        
        case glfw.KEY_KP_0:                 return .Kp0                         
        case glfw.KEY_KP_1:                 return .Kp1                         
        case glfw.KEY_KP_2:                 return .Kp2                         
        case glfw.KEY_KP_3:                 return .Kp3                         
        case glfw.KEY_KP_4:                 return .Kp4                         
        case glfw.KEY_KP_5:                 return .Kp5                         
        case glfw.KEY_KP_6:                 return .Kp6                         
        case glfw.KEY_KP_7:                 return .Kp7                         
        case glfw.KEY_KP_8:                 return .Kp8                         
        case glfw.KEY_KP_9:                 return .Kp9                         
        case glfw.KEY_KP_DECIMAL:           return .KpDecimal                         
        case glfw.KEY_KP_DIVIDE:            return .KpDivide                         
        case glfw.KEY_KP_MULTIPLY:          return .KpMultiply                         
        case glfw.KEY_KP_SUBTRACT:          return .KpSubtract                         
        case glfw.KEY_KP_ADD:               return .KpAdd                         
        case glfw.KEY_KP_ENTER:             return .KpEnter                         
        case glfw.KEY_KP_EQUAL:             return .KpEqual                         
        case glfw.KEY_LEFT_SHIFT:           return .LeftShift                         
        case glfw.KEY_LEFT_CONTROL:         return .LeftCtrl                            
        case glfw.KEY_LEFT_ALT:             return .LeftAlt                         
        case glfw.KEY_LEFT_SUPER:           return .LeftSuper                         
        case glfw.KEY_MENU:                 return .Menu    
        case glfw.KEY_UNKNOWN:              return .Unknown                      
    }
    return Key_Code.Unknown
}