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
        speaking   = 'Speaking...',
        radio      = 'Radio',
        toggle_on  = 'Speaker labels are now on.',
        toggle_off = 'Speaker labels are now off.',
        toggle_cmd = 'Show or hide the labels above talking players'
    },

    de = {
        speaking   = 'Spricht...',
        radio      = 'Funk',
        toggle_on  = 'Sprecher-Anzeige ist jetzt an.',
        toggle_off = 'Sprecher-Anzeige ist jetzt aus.',
        toggle_cmd = 'Anzeige über sprechenden Spielern ein- oder ausblenden'
    },

    es = {
        speaking   = 'Hablando...',
        radio      = 'Radio',
        toggle_on  = 'Las etiquetas de voz están activadas.',
        toggle_off = 'Las etiquetas de voz están desactivadas.',
        toggle_cmd = 'Mostrar u ocultar las etiquetas sobre quien habla'
    },

    fr = {
        speaking   = 'Parle...',
        radio      = 'Radio',
        toggle_on  = 'Les etiquettes vocales sont activees.',
        toggle_off = 'Les etiquettes vocales sont desactivees.',
        toggle_cmd = 'Afficher ou masquer les etiquettes au-dessus des joueurs qui parlent'
    },

    nl = {
        speaking   = 'Spreekt...',
        radio      = 'Radio',
        toggle_on  = 'Spreker-labels staan nu aan.',
        toggle_off = 'Spreker-labels staan nu uit.',
        toggle_cmd = 'Labels boven sprekende spelers aan- of uitzetten'
    },

    pt = {
        speaking   = 'Falando...',
        radio      = 'Radio',
        toggle_on  = 'As etiquetas de voz estao ativadas.',
        toggle_off = 'As etiquetas de voz estao desativadas.',
        toggle_cmd = 'Mostrar ou ocultar as etiquetas sobre quem esta falando'
    }
}
