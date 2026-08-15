--[[
    Text shown to players, picked by Config.Locale.

    Add your own by copying a block and giving it a key, then setting
    Config.Locale to that key. Anything missing falls back to English rather
    than showing a blank label.

    'speaking' and 'radio' are drawn in the world with the GTA text font, so
    keep those two plain - the font has no emoji and no non latin alphabets.
    Config.Label and Config.RadioLabel override them if you would rather set the
    text directly.
]]

Locales = {
    en = {
        speaking     = 'Speaking...',
        radio        = 'Radio',
        toggle_on    = 'Speaker labels are now on.',
        toggle_off   = 'Speaker labels are now off.',
        toggle_cmd   = 'Show or hide the labels above talking players',
        list_title   = 'Speaking',
        player       = 'Player',
        admin_hidden = '%s is now hidden from the speaker display.',
        admin_shown  = '%s is shown on the speaker display again.'
    },

    de = {
        speaking     = 'Spricht...',
        radio        = 'Funk',
        toggle_on    = 'Sprecher-Anzeige ist jetzt an.',
        toggle_off   = 'Sprecher-Anzeige ist jetzt aus.',
        toggle_cmd   = 'Anzeige über sprechenden Spielern ein- oder ausblenden',
        list_title   = 'Spricht',
        player       = 'Spieler',
        admin_hidden = '%s wird nicht mehr in der Sprecher-Anzeige gezeigt.',
        admin_shown  = '%s wird wieder in der Sprecher-Anzeige gezeigt.'
    },

    es = {
        speaking     = 'Hablando...',
        radio        = 'Radio',
        toggle_on    = 'Las etiquetas de voz están activadas.',
        toggle_off   = 'Las etiquetas de voz están desactivadas.',
        toggle_cmd   = 'Mostrar u ocultar las etiquetas sobre quien habla',
        list_title   = 'Hablando',
        player       = 'Jugador',
        admin_hidden = '%s ya no aparece en la lista de voz.',
        admin_shown  = '%s vuelve a aparecer en la lista de voz.'
    },

    fr = {
        speaking     = 'Parle...',
        radio        = 'Radio',
        toggle_on    = 'Les etiquettes vocales sont activees.',
        toggle_off   = 'Les etiquettes vocales sont desactivees.',
        toggle_cmd   = 'Afficher ou masquer les etiquettes au-dessus des joueurs qui parlent',
        list_title   = 'Parle',
        player       = 'Joueur',
        admin_hidden = '%s n apparait plus dans l affichage vocal.',
        admin_shown  = '%s apparait de nouveau dans l affichage vocal.'
    },

    nl = {
        speaking     = 'Spreekt...',
        radio        = 'Radio',
        toggle_on    = 'Spreker-labels staan nu aan.',
        toggle_off   = 'Spreker-labels staan nu uit.',
        toggle_cmd   = 'Labels boven sprekende spelers aan- of uitzetten',
        list_title   = 'Spreekt',
        player       = 'Speler',
        admin_hidden = '%s wordt niet meer getoond bij de spreker-weergave.',
        admin_shown  = '%s wordt weer getoond bij de spreker-weergave.'
    },

    pt = {
        speaking     = 'Falando...',
        radio        = 'Radio',
        toggle_on    = 'As etiquetas de voz estao ativadas.',
        toggle_off   = 'As etiquetas de voz estao desativadas.',
        toggle_cmd   = 'Mostrar ou ocultar as etiquetas sobre quem esta falando',
        list_title   = 'Falando',
        player       = 'Jogador',
        admin_hidden = '%s nao aparece mais na exibicao de voz.',
        admin_shown  = '%s aparece novamente na exibicao de voz.'
    }
}
