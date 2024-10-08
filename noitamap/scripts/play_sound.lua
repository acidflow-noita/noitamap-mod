function playWhereSound()
    local xx, yy = GameGetCameraPos()
    GamePlaySound("mods/noitmap/files/audio/noitmap.bank", "noitamap/create", xx, yy)
end