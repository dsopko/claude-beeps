function Triumphant {
    # Option 1 - Triumphant rise and fall
    [console]::beep(1047,150); [console]::beep(880,150)
    [console]::beep(1175,150); [console]::beep(1319,150); [console]::beep(1568,200)
    [console]::beep(1319,150); [console]::beep(1175,150); [console]::beep(1047,150); [console]::beep(880,150)
    [console]::beep(659,150);  [console]::beep(523,500)
}

function BellTower {
    # Option 2 - Bell-tower turn
    [console]::beep(1047,150); [console]::beep(880,150)
    [console]::beep(988,150);  [console]::beep(1047,150); [console]::beep(880,150); [console]::beep(784,150)
    [console]::beep(659,150);  [console]::beep(523,500)
}

function Arpeggio {
    # Option 3 - Arpeggiated celebration
    [console]::beep(1047,150); [console]::beep(880,150)
    [console]::beep(659,120);  [console]::beep(784,120); [console]::beep(1047,120); [console]::beep(1319,200)
    [console]::beep(1047,150); [console]::beep(784,150)
    [console]::beep(659,150);  [console]::beep(523,500)
}

function CallResp {
    # Option 4 - Call and response
    [console]::beep(1047,150); [console]::beep(880,150)
    [console]::beep(784,200);  [console]::beep(880,200); [console]::beep(1047,200); [console]::beep(880,200)
    [console]::beep(659,150);  [console]::beep(523,500)
}
