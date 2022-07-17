## PebblApp::Keysym module

require 'pebbl_app/gtk_framework'


module PebblApp

  ## Definitions for key codes used in Gdk
  ##
  ## Constants gnerated after symbol names and keycode values
  ## /usr/local/include/gtk-3.0/gdk/gdkkeysyms.h for gtk3 version
  ## 3.24.33 in FreeBSD ports
  ##
  ## @see Keysym.key_code
  ## @see Keysym.modifier_mask
  module Keysym

    ## rather than hard-coding the full symbols list in this file,
    ## each key code will be autoloaded on first reference to a
    ## corresponding key symbol.
    ##
    ## e.g on reference to PebblApp:Keysym::Key_Tab Ruby will autoload
    ## the constant's definition from the file ./keysym/key_Tab.rb
    ##
    ## Each constant's value will be defined in each ./keysym/key_*.rb file
    ## with a brief documentation string denoting the Gdk key name for
    ## the constant.
    ##
    ## Known limitations with this methodology:
    ##
    ## - The containing filesystem must be able to handle at least 2278
    ##   files in a directory
    ##
    ## - This may result in a generally more maintainble source
    ##   file here, for the module providing these key code definitions.
    ##   In any side effects to the Ruby application environment: It may
    ##   be less actually efficient to store and dereference the initial
    ##   autoload definition for any key code's constant, in lieu of
    ##   storing every 32-bit integer for the key code of each key,
    ##   without autoload.
    ##
    ## The approach used here has been applied mainly in the interest of
    ## maintainability for this source file.
    ##
    ## The implementation of this module may be subject to change, in
    ## some later revision of this framework. Whether by this approach,
    ## or definiing all of the key codes in this file, the definition of
    ## each constant value within PebblApp::Keysym.constants.grep(/^Key_/)
    ## should remain consistent.
    ##
    ## If an application may require any alternate methodology for
    ## initialization of key code constants, the set of constants
    ## /^Key_/ defined in this module PebblApp::Keysym can be parsed
    ## for any alternate representation.
    ##
    %w(VoidSymbol BackSpace Tab Linefeed Clear Return Pause Scroll_Lock
       Sys_Req Escape Delete Multi_key Codeinput SingleCandidate
       MultipleCandidate PreviousCandidate Kanji Muhenkan Henkan_Mode
       Henkan Romaji Hiragana Katakana Hiragana_Katakana Zenkaku Hankaku
       Zenkaku_Hankaku Touroku Massyo Kana_Lock Kana_Shift Eisu_Shift
       Eisu_toggle Kanji_Bangou Zen_Koho Mae_Koho Home Left Up Right Down
       Prior Page_Up Next Page_Down End Begin Select Print Execute Insert
       Undo Redo Menu Find Cancel Help Break Mode_switch script_switch
       Num_Lock KP_Space KP_Tab KP_Enter KP_F1 KP_F2 KP_F3 KP_F4 KP_Home
       KP_Left KP_Up KP_Right KP_Down KP_Prior KP_Page_Up KP_Next
       KP_Page_Down KP_End KP_Begin KP_Insert KP_Delete KP_Equal
       KP_Multiply KP_Add KP_Separator KP_Subtract KP_Decimal KP_Divide
       KP_0 KP_1 KP_2 KP_3 KP_4 KP_5 KP_6 KP_7 KP_8 KP_9 F1 F2 F3 F4 F5
       F6 F7 F8 F9 F10 F11 L1 F12 L2 F13 L3 F14 L4 F15 L5 F16 L6 F17 L7
       F18 L8 F19 L9 F20 L10 F21 R1 F22 R2 F23 R3 F24 R4 F25 R5 F26 R6
       F27 R7 F28 R8 F29 R9 F30 R10 F31 R11 F32 R12 F33 R13 F34 R14 F35
       R15 Shift_L Shift_R Control_L Control_R Caps_Lock Shift_Lock
       Meta_L Meta_R Alt_L Alt_R Super_L Super_R Hyper_L Hyper_R ISO_Lock
       ISO_Level2_Latch ISO_Level3_Shift ISO_Level3_Latch ISO_Level3_Lock
       ISO_Level5_Shift ISO_Level5_Latch ISO_Level5_Lock ISO_Group_Shift
       ISO_Group_Latch ISO_Group_Lock ISO_Next_Group ISO_Next_Group_Lock
       ISO_Prev_Group ISO_Prev_Group_Lock ISO_First_Group
       ISO_First_Group_Lock ISO_Last_Group ISO_Last_Group_Lock
       ISO_Left_Tab ISO_Move_Line_Up ISO_Move_Line_Down
       ISO_Partial_Line_Up ISO_Partial_Line_Down ISO_Partial_Space_Left
       ISO_Partial_Space_Right ISO_Set_Margin_Left ISO_Set_Margin_Right
       ISO_Release_Margin_Left ISO_Release_Margin_Right
       ISO_Release_Both_Margins ISO_Fast_Cursor_Left
       ISO_Fast_Cursor_Right ISO_Fast_Cursor_Up ISO_Fast_Cursor_Down
       ISO_Continuous_Underline ISO_Discontinuous_Underline ISO_Emphasize
       ISO_Center_Object ISO_Enter dead_grave dead_acute dead_circumflex
       dead_tilde dead_perispomeni dead_macron dead_breve dead_abovedot
       dead_diaeresis dead_abovering dead_doubleacute dead_caron
       dead_cedilla dead_ogonek dead_iota dead_voiced_sound
       dead_semivoiced_sound dead_belowdot dead_hook dead_horn
       dead_stroke dead_abovecomma dead_psili dead_abovereversedcomma
       dead_dasia dead_doublegrave dead_belowring dead_belowmacron
       dead_belowcircumflex dead_belowtilde dead_belowbreve
       dead_belowdiaeresis dead_invertedbreve dead_belowcomma
       dead_currency dead_lowline dead_aboveverticalline
       dead_belowverticalline dead_longsolidusoverlay dead_a dead_A
       dead_e dead_E dead_i dead_I dead_o dead_O dead_u dead_U
       dead_small_schwa dead_capital_schwa dead_greek
       First_Virtual_Screen Prev_Virtual_Screen Next_Virtual_Screen
       Last_Virtual_Screen Terminate_Server AccessX_Enable
       AccessX_Feedback_Enable RepeatKeys_Enable SlowKeys_Enable
       BounceKeys_Enable StickyKeys_Enable MouseKeys_Enable
       MouseKeys_Accel_Enable Overlay1_Enable Overlay2_Enable
       AudibleBell_Enable Pointer_Left Pointer_Right Pointer_Up
       Pointer_Down Pointer_UpLeft Pointer_UpRight Pointer_DownLeft
       Pointer_DownRight Pointer_Button_Dflt Pointer_Button1
       Pointer_Button2 Pointer_Button3 Pointer_Button4 Pointer_Button5
       Pointer_DblClick_Dflt Pointer_DblClick1 Pointer_DblClick2
       Pointer_DblClick3 Pointer_DblClick4 Pointer_DblClick5
       Pointer_Drag_Dflt Pointer_Drag1 Pointer_Drag2 Pointer_Drag3
       Pointer_Drag4 Pointer_Drag5 Pointer_EnableKeys Pointer_Accelerate
       Pointer_DfltBtnNext Pointer_DfltBtnPrev ch Ch CH c_h C_h C_H
       3270_Duplicate 3270_FieldMark 3270_Right2 3270_Left2 3270_BackTab
       3270_EraseEOF 3270_EraseInput 3270_Reset 3270_Quit 3270_PA1
       3270_PA2 3270_PA3 3270_Test 3270_Attn 3270_CursorBlink
       3270_AltCursor 3270_Key_Click 3270_Jump 3270_Ident 3270_Rule
       3270_Copy 3270_Play 3270_Setup 3270_Record 3270_ChangeScreen
       3270_DeleteWord 3270_ExSelect 3270_CursorSelect 3270_PrintScreen
       3270_Enter space exclam quotedbl numbersign dollar percent
       ampersand apostrophe quoteright parenleft parenright asterisk plus
       comma minus period slash 0 1 2 3 4 5 6 7 8 9 colon semicolon less
       equal greater question at A B C D E F G H I J K L M N O P Q R S T
       U V W X Y Z bracketleft backslash bracketright asciicircum
       underscore grave quoteleft a b c d e f g h i j k l m n o p q r s t
       u v w x y z braceleft bar braceright asciitilde nobreakspace
       exclamdown cent sterling currency yen brokenbar section diaeresis
       copyright ordfeminine guillemotleft notsign hyphen registered
       macron degree plusminus twosuperior threesuperior acute mu
       paragraph periodcentered cedilla onesuperior masculine
       guillemotright onequarter onehalf threequarters questiondown
       Agrave Aacute Acircumflex Atilde Adiaeresis Aring AE Ccedilla
       Egrave Eacute Ecircumflex Ediaeresis Igrave Iacute Icircumflex
       Idiaeresis ETH Eth Ntilde Ograve Oacute Ocircumflex Otilde
       Odiaeresis multiply Oslash Ooblique Ugrave Uacute Ucircumflex
       Udiaeresis Yacute THORN Thorn ssharp agrave aacute acircumflex
       atilde adiaeresis aring ae ccedilla egrave eacute ecircumflex
       ediaeresis igrave iacute icircumflex idiaeresis eth ntilde ograve
       oacute ocircumflex otilde odiaeresis division oslash ooblique
       ugrave uacute ucircumflex udiaeresis yacute thorn ydiaeresis
       Aogonek breve Lstroke Lcaron Sacute Scaron Scedilla Tcaron Zacute
       Zcaron Zabovedot aogonek ogonek lstroke lcaron sacute caron scaron
       scedilla tcaron zacute doubleacute zcaron zabovedot Racute Abreve
       Lacute Cacute Ccaron Eogonek Ecaron Dcaron Dstroke Nacute Ncaron
       Odoubleacute Rcaron Uring Udoubleacute Tcedilla racute abreve
       lacute cacute ccaron eogonek ecaron dcaron dstroke nacute ncaron
       odoubleacute rcaron uring udoubleacute tcedilla abovedot Hstroke
       Hcircumflex Iabovedot Gbreve Jcircumflex hstroke hcircumflex
       idotless gbreve jcircumflex Cabovedot Ccircumflex Gabovedot
       Gcircumflex Ubreve Scircumflex cabovedot ccircumflex gabovedot
       gcircumflex ubreve scircumflex kra kappa Rcedilla Itilde Lcedilla
       Emacron Gcedilla Tslash rcedilla itilde lcedilla emacron gcedilla
       tslash ENG eng Amacron Iogonek Eabovedot Imacron Ncedilla Omacron
       Kcedilla Uogonek Utilde Umacron amacron iogonek eabovedot imacron
       ncedilla omacron kcedilla uogonek utilde umacron Wcircumflex
       wcircumflex Ycircumflex ycircumflex Babovedot babovedot Dabovedot
       dabovedot Fabovedot fabovedot Mabovedot mabovedot Pabovedot
       pabovedot Sabovedot sabovedot Tabovedot tabovedot Wgrave wgrave
       Wacute wacute Wdiaeresis wdiaeresis Ygrave ygrave OE oe Ydiaeresis
       overline kana_fullstop kana_openingbracket kana_closingbracket
       kana_comma kana_conjunctive kana_middledot kana_WO kana_a kana_i
       kana_u kana_e kana_o kana_ya kana_yu kana_yo kana_tsu kana_tu
       prolongedsound kana_A kana_I kana_U kana_E kana_O kana_KA kana_KI
       kana_KU kana_KE kana_KO kana_SA kana_SHI kana_SU kana_SE kana_SO
       kana_TA kana_CHI kana_TI kana_TSU kana_TU kana_TE kana_TO kana_NA
       kana_NI kana_NU kana_NE kana_NO kana_HA kana_HI kana_FU kana_HU
       kana_HE kana_HO kana_MA kana_MI kana_MU kana_ME kana_MO kana_YA
       kana_YU kana_YO kana_RA kana_RI kana_RU kana_RE kana_RO kana_WA
       kana_N voicedsound semivoicedsound kana_switch Farsi_0 Farsi_1
       Farsi_2 Farsi_3 Farsi_4 Farsi_5 Farsi_6 Farsi_7 Farsi_8 Farsi_9
       Arabic_percent Arabic_superscript_alef Arabic_tteh Arabic_peh
       Arabic_tcheh Arabic_ddal Arabic_rreh Arabic_comma Arabic_fullstop
       Arabic_0 Arabic_1 Arabic_2 Arabic_3 Arabic_4 Arabic_5 Arabic_6
       Arabic_7 Arabic_8 Arabic_9 Arabic_semicolon Arabic_question_mark
       Arabic_hamza Arabic_maddaonalef Arabic_hamzaonalef
       Arabic_hamzaonwaw Arabic_hamzaunderalef Arabic_hamzaonyeh
       Arabic_alef Arabic_beh Arabic_tehmarbuta Arabic_teh Arabic_theh
       Arabic_jeem Arabic_hah Arabic_khah Arabic_dal Arabic_thal
       Arabic_ra Arabic_zain Arabic_seen Arabic_sheen Arabic_sad
       Arabic_dad Arabic_tah Arabic_zah Arabic_ain Arabic_ghain
       Arabic_tatweel Arabic_feh Arabic_qaf Arabic_kaf Arabic_lam
       Arabic_meem Arabic_noon Arabic_ha Arabic_heh Arabic_waw
       Arabic_alefmaksura Arabic_yeh Arabic_fathatan Arabic_dammatan
       Arabic_kasratan Arabic_fatha Arabic_damma Arabic_kasra
       Arabic_shadda Arabic_sukun Arabic_madda_above Arabic_hamza_above
       Arabic_hamza_below Arabic_jeh Arabic_veh Arabic_keheh Arabic_gaf
       Arabic_noon_ghunna Arabic_heh_doachashmee Farsi_yeh
       Arabic_farsi_yeh Arabic_yeh_baree Arabic_heh_goal Arabic_switch
       Cyrillic_GHE_bar Cyrillic_ghe_bar Cyrillic_ZHE_descender
       Cyrillic_zhe_descender Cyrillic_KA_descender Cyrillic_ka_descender
       Cyrillic_KA_vertstroke Cyrillic_ka_vertstroke
       Cyrillic_EN_descender Cyrillic_en_descender Cyrillic_U_straight
       Cyrillic_u_straight Cyrillic_U_straight_bar
       Cyrillic_u_straight_bar Cyrillic_HA_descender
       Cyrillic_ha_descender Cyrillic_CHE_descender
       Cyrillic_che_descender Cyrillic_CHE_vertstroke
       Cyrillic_che_vertstroke Cyrillic_SHHA Cyrillic_shha Cyrillic_SCHWA
       Cyrillic_schwa Cyrillic_I_macron Cyrillic_i_macron Cyrillic_O_bar
       Cyrillic_o_bar Cyrillic_U_macron Cyrillic_u_macron Serbian_dje
       Macedonia_gje Cyrillic_io Ukrainian_ie Ukranian_je Macedonia_dse
       Ukrainian_i Ukranian_i Ukrainian_yi Ukranian_yi Cyrillic_je
       Serbian_je Cyrillic_lje Serbian_lje Cyrillic_nje Serbian_nje
       Serbian_tshe Macedonia_kje Ukrainian_ghe_with_upturn
       Byelorussian_shortu Cyrillic_dzhe Serbian_dze numerosign
       Serbian_DJE Macedonia_GJE Cyrillic_IO Ukrainian_IE Ukranian_JE
       Macedonia_DSE Ukrainian_I Ukranian_I Ukrainian_YI Ukranian_YI
       Cyrillic_JE Serbian_JE Cyrillic_LJE Serbian_LJE Cyrillic_NJE
       Serbian_NJE Serbian_TSHE Macedonia_KJE Ukrainian_GHE_WITH_UPTURN
       Byelorussian_SHORTU Cyrillic_DZHE Serbian_DZE Cyrillic_yu
       Cyrillic_a Cyrillic_be Cyrillic_tse Cyrillic_de Cyrillic_ie
       Cyrillic_ef Cyrillic_ghe Cyrillic_ha Cyrillic_i Cyrillic_shorti
       Cyrillic_ka Cyrillic_el Cyrillic_em Cyrillic_en Cyrillic_o
       Cyrillic_pe Cyrillic_ya Cyrillic_er Cyrillic_es Cyrillic_te
       Cyrillic_u Cyrillic_zhe Cyrillic_ve Cyrillic_softsign
       Cyrillic_yeru Cyrillic_ze Cyrillic_sha Cyrillic_e Cyrillic_shcha
       Cyrillic_che Cyrillic_hardsign Cyrillic_YU Cyrillic_A Cyrillic_BE
       Cyrillic_TSE Cyrillic_DE Cyrillic_IE Cyrillic_EF Cyrillic_GHE
       Cyrillic_HA Cyrillic_I Cyrillic_SHORTI Cyrillic_KA Cyrillic_EL
       Cyrillic_EM Cyrillic_EN Cyrillic_O Cyrillic_PE Cyrillic_YA
       Cyrillic_ER Cyrillic_ES Cyrillic_TE Cyrillic_U Cyrillic_ZHE
       Cyrillic_VE Cyrillic_SOFTSIGN Cyrillic_YERU Cyrillic_ZE
       Cyrillic_SHA Cyrillic_E Cyrillic_SHCHA Cyrillic_CHE
       Cyrillic_HARDSIGN Greek_ALPHAaccent Greek_EPSILONaccent
       Greek_ETAaccent Greek_IOTAaccent Greek_IOTAdieresis
       Greek_IOTAdiaeresis Greek_OMICRONaccent Greek_UPSILONaccent
       Greek_UPSILONdieresis Greek_OMEGAaccent Greek_accentdieresis
       Greek_horizbar Greek_alphaaccent Greek_epsilonaccent
       Greek_etaaccent Greek_iotaaccent Greek_iotadieresis
       Greek_iotaaccentdieresis Greek_omicronaccent Greek_upsilonaccent
       Greek_upsilondieresis Greek_upsilonaccentdieresis
       Greek_omegaaccent Greek_ALPHA Greek_BETA Greek_GAMMA Greek_DELTA
       Greek_EPSILON Greek_ZETA Greek_ETA Greek_THETA Greek_IOTA
       Greek_KAPPA Greek_LAMDA Greek_LAMBDA Greek_MU Greek_NU Greek_XI
       Greek_OMICRON Greek_PI Greek_RHO Greek_SIGMA Greek_TAU
       Greek_UPSILON Greek_PHI Greek_CHI Greek_PSI Greek_OMEGA
       Greek_alpha Greek_beta Greek_gamma Greek_delta Greek_epsilon
       Greek_zeta Greek_eta Greek_theta Greek_iota Greek_kappa
       Greek_lamda Greek_lambda Greek_mu Greek_nu Greek_xi Greek_omicron
       Greek_pi Greek_rho Greek_sigma Greek_finalsmallsigma Greek_tau
       Greek_upsilon Greek_phi Greek_chi Greek_psi Greek_omega
       Greek_switch leftradical topleftradical horizconnector topintegral
       botintegral vertconnector topleftsqbracket botleftsqbracket
       toprightsqbracket botrightsqbracket topleftparens botleftparens
       toprightparens botrightparens leftmiddlecurlybrace
       rightmiddlecurlybrace topleftsummation botleftsummation
       topvertsummationconnector botvertsummationconnector
       toprightsummation botrightsummation rightmiddlesummation
       lessthanequal notequal greaterthanequal integral therefore
       variation infinity nabla approximate similarequal ifonlyif implies
       identical radical includedin includes intersection union
       logicaland logicalor partialderivative function leftarrow uparrow
       rightarrow downarrow blank soliddiamond checkerboard ht ff cr lf
       nl vt lowrightcorner uprightcorner upleftcorner lowleftcorner
       crossinglines horizlinescan1 horizlinescan3 horizlinescan5
       horizlinescan7 horizlinescan9 leftt rightt bott topt vertbar
       emspace enspace em3space em4space digitspace punctspace thinspace
       hairspace emdash endash signifblank ellipsis doubbaselinedot
       onethird twothirds onefifth twofifths threefifths fourfifths
       onesixth fivesixths careof figdash leftanglebracket decimalpoint
       rightanglebracket marker oneeighth threeeighths fiveeighths
       seveneighths trademark signaturemark trademarkincircle
       leftopentriangle rightopentriangle emopencircle emopenrectangle
       leftsinglequotemark rightsinglequotemark leftdoublequotemark
       rightdoublequotemark prescription permille minutes seconds
       latincross hexagram filledrectbullet filledlefttribullet
       filledrighttribullet emfilledcircle emfilledrect enopencircbullet
       enopensquarebullet openrectbullet opentribulletup
       opentribulletdown openstar enfilledcircbullet enfilledsqbullet
       filledtribulletup filledtribulletdown leftpointer rightpointer
       club diamond heart maltesecross dagger doubledagger checkmark
       ballotcross musicalsharp musicalflat malesymbol femalesymbol
       telephone telephonerecorder phonographcopyright caret
       singlelowquotemark doublelowquotemark cursor leftcaret rightcaret
       downcaret upcaret overbar downtack upshoe downstile underbar jot
       quad uptack circle upstile downshoe rightshoe leftshoe lefttack
       righttack hebrew_doublelowline hebrew_aleph hebrew_bet hebrew_beth
       hebrew_gimel hebrew_gimmel hebrew_dalet hebrew_daleth hebrew_he
       hebrew_waw hebrew_zain hebrew_zayin hebrew_chet hebrew_het
       hebrew_tet hebrew_teth hebrew_yod hebrew_finalkaph hebrew_kaph
       hebrew_lamed hebrew_finalmem hebrew_mem hebrew_finalnun hebrew_nun
       hebrew_samech hebrew_samekh hebrew_ayin hebrew_finalpe hebrew_pe
       hebrew_finalzade hebrew_finalzadi hebrew_zade hebrew_zadi
       hebrew_qoph hebrew_kuf hebrew_resh hebrew_shin hebrew_taw
       hebrew_taf Hebrew_switch Thai_kokai Thai_khokhai Thai_khokhuat
       Thai_khokhwai Thai_khokhon Thai_khorakhang Thai_ngongu
       Thai_chochan Thai_choching Thai_chochang Thai_soso Thai_chochoe
       Thai_yoying Thai_dochada Thai_topatak Thai_thothan
       Thai_thonangmontho Thai_thophuthao Thai_nonen Thai_dodek
       Thai_totao Thai_thothung Thai_thothahan Thai_thothong Thai_nonu
       Thai_bobaimai Thai_popla Thai_phophung Thai_fofa Thai_phophan
       Thai_fofan Thai_phosamphao Thai_moma Thai_yoyak Thai_rorua Thai_ru
       Thai_loling Thai_lu Thai_wowaen Thai_sosala Thai_sorusi Thai_sosua
       Thai_hohip Thai_lochula Thai_oang Thai_honokhuk Thai_paiyannoi
       Thai_saraa Thai_maihanakat Thai_saraaa Thai_saraam Thai_sarai
       Thai_saraii Thai_saraue Thai_sarauee Thai_sarau Thai_sarauu
       Thai_phinthu Thai_maihanakat_maitho Thai_baht Thai_sarae
       Thai_saraae Thai_sarao Thai_saraaimaimuan Thai_saraaimaimalai
       Thai_lakkhangyao Thai_maiyamok Thai_maitaikhu Thai_maiek
       Thai_maitho Thai_maitri Thai_maichattawa Thai_thanthakhat
       Thai_nikhahit Thai_leksun Thai_leknung Thai_leksong Thai_leksam
       Thai_leksi Thai_lekha Thai_lekhok Thai_lekchet Thai_lekpaet
       Thai_lekkao Hangul Hangul_Start Hangul_End Hangul_Hanja
       Hangul_Jamo Hangul_Romaja Hangul_Codeinput Hangul_Jeonja
       Hangul_Banja Hangul_PreHanja Hangul_PostHanja
       Hangul_SingleCandidate Hangul_MultipleCandidate
       Hangul_PreviousCandidate Hangul_Special Hangul_switch
       Hangul_Kiyeog Hangul_SsangKiyeog Hangul_KiyeogSios Hangul_Nieun
       Hangul_NieunJieuj Hangul_NieunHieuh Hangul_Dikeud
       Hangul_SsangDikeud Hangul_Rieul Hangul_RieulKiyeog
       Hangul_RieulMieum Hangul_RieulPieub Hangul_RieulSios
       Hangul_RieulTieut Hangul_RieulPhieuf Hangul_RieulHieuh
       Hangul_Mieum Hangul_Pieub Hangul_SsangPieub Hangul_PieubSios
       Hangul_Sios Hangul_SsangSios Hangul_Ieung Hangul_Jieuj
       Hangul_SsangJieuj Hangul_Cieuc Hangul_Khieuq Hangul_Tieut
       Hangul_Phieuf Hangul_Hieuh Hangul_A Hangul_AE Hangul_YA Hangul_YAE
       Hangul_EO Hangul_E Hangul_YEO Hangul_YE Hangul_O Hangul_WA
       Hangul_WAE Hangul_OE Hangul_YO Hangul_U Hangul_WEO Hangul_WE
       Hangul_WI Hangul_YU Hangul_EU Hangul_YI Hangul_I Hangul_J_Kiyeog
       Hangul_J_SsangKiyeog Hangul_J_KiyeogSios Hangul_J_Nieun
       Hangul_J_NieunJieuj Hangul_J_NieunHieuh Hangul_J_Dikeud
       Hangul_J_Rieul Hangul_J_RieulKiyeog Hangul_J_RieulMieum
       Hangul_J_RieulPieub Hangul_J_RieulSios Hangul_J_RieulTieut
       Hangul_J_RieulPhieuf Hangul_J_RieulHieuh Hangul_J_Mieum
       Hangul_J_Pieub Hangul_J_PieubSios Hangul_J_Sios Hangul_J_SsangSios
       Hangul_J_Ieung Hangul_J_Jieuj Hangul_J_Cieuc Hangul_J_Khieuq
       Hangul_J_Tieut Hangul_J_Phieuf Hangul_J_Hieuh
       Hangul_RieulYeorinHieuh Hangul_SunkyeongeumMieum
       Hangul_SunkyeongeumPieub Hangul_PanSios Hangul_KkogjiDalrinIeung
       Hangul_SunkyeongeumPhieuf Hangul_YeorinHieuh Hangul_AraeA
       Hangul_AraeAE Hangul_J_PanSios Hangul_J_KkogjiDalrinIeung
       Hangul_J_YeorinHieuh Korean_Won Armenian_ligature_ew
       Armenian_full_stop Armenian_verjaket Armenian_separation_mark
       Armenian_but Armenian_hyphen Armenian_yentamna Armenian_exclam
       Armenian_amanak Armenian_accent Armenian_shesht Armenian_question
       Armenian_paruyk Armenian_AYB Armenian_ayb Armenian_BEN
       Armenian_ben Armenian_GIM Armenian_gim Armenian_DA Armenian_da
       Armenian_YECH Armenian_yech Armenian_ZA Armenian_za Armenian_E
       Armenian_e Armenian_AT Armenian_at Armenian_TO Armenian_to
       Armenian_ZHE Armenian_zhe Armenian_INI Armenian_ini Armenian_LYUN
       Armenian_lyun Armenian_KHE Armenian_khe Armenian_TSA Armenian_tsa
       Armenian_KEN Armenian_ken Armenian_HO Armenian_ho Armenian_DZA
       Armenian_dza Armenian_GHAT Armenian_ghat Armenian_TCHE
       Armenian_tche Armenian_MEN Armenian_men Armenian_HI Armenian_hi
       Armenian_NU Armenian_nu Armenian_SHA Armenian_sha Armenian_VO
       Armenian_vo Armenian_CHA Armenian_cha Armenian_PE Armenian_pe
       Armenian_JE Armenian_je Armenian_RA Armenian_ra Armenian_SE
       Armenian_se Armenian_VEV Armenian_vev Armenian_TYUN Armenian_tyun
       Armenian_RE Armenian_re Armenian_TSO Armenian_tso Armenian_VYUN
       Armenian_vyun Armenian_PYUR Armenian_pyur Armenian_KE Armenian_ke
       Armenian_O Armenian_o Armenian_FE Armenian_fe Armenian_apostrophe
       Georgian_an Georgian_ban Georgian_gan Georgian_don Georgian_en
       Georgian_vin Georgian_zen Georgian_tan Georgian_in Georgian_kan
       Georgian_las Georgian_man Georgian_nar Georgian_on Georgian_par
       Georgian_zhar Georgian_rae Georgian_san Georgian_tar Georgian_un
       Georgian_phar Georgian_khar Georgian_ghan Georgian_qar
       Georgian_shin Georgian_chin Georgian_can Georgian_jil Georgian_cil
       Georgian_char Georgian_xan Georgian_jhan Georgian_hae Georgian_he
       Georgian_hie Georgian_we Georgian_har Georgian_hoe Georgian_fi
       Xabovedot Ibreve Zstroke Gcaron Ocaron Obarred xabovedot ibreve
       zstroke gcaron ocaron obarred SCHWA schwa EZH ezh Lbelowdot
       lbelowdot Abelowdot abelowdot Ahook ahook Acircumflexacute
       acircumflexacute Acircumflexgrave acircumflexgrave Acircumflexhook
       acircumflexhook Acircumflextilde acircumflextilde
       Acircumflexbelowdot acircumflexbelowdot Abreveacute abreveacute
       Abrevegrave abrevegrave Abrevehook abrevehook Abrevetilde
       abrevetilde Abrevebelowdot abrevebelowdot Ebelowdot ebelowdot
       Ehook ehook Etilde etilde Ecircumflexacute ecircumflexacute
       Ecircumflexgrave ecircumflexgrave Ecircumflexhook ecircumflexhook
       Ecircumflextilde ecircumflextilde Ecircumflexbelowdot
       ecircumflexbelowdot Ihook ihook Ibelowdot ibelowdot Obelowdot
       obelowdot Ohook ohook Ocircumflexacute ocircumflexacute
       Ocircumflexgrave ocircumflexgrave Ocircumflexhook ocircumflexhook
       Ocircumflextilde ocircumflextilde Ocircumflexbelowdot
       ocircumflexbelowdot Ohornacute ohornacute Ohorngrave ohorngrave
       Ohornhook ohornhook Ohorntilde ohorntilde Ohornbelowdot
       ohornbelowdot Ubelowdot ubelowdot Uhook uhook Uhornacute
       uhornacute Uhorngrave uhorngrave Uhornhook uhornhook Uhorntilde
       uhorntilde Uhornbelowdot uhornbelowdot Ybelowdot ybelowdot Yhook
       yhook Ytilde ytilde Ohorn ohorn Uhorn uhorn EcuSign ColonSign
       CruzeiroSign FFrancSign LiraSign MillSign NairaSign PesetaSign
       RupeeSign WonSign NewSheqelSign DongSign EuroSign zerosuperior
       foursuperior fivesuperior sixsuperior sevensuperior eightsuperior
       ninesuperior zerosubscript onesubscript twosubscript
       threesubscript foursubscript fivesubscript sixsubscript
       sevensubscript eightsubscript ninesubscript partdifferential
       emptyset elementof notelementof containsas squareroot cuberoot
       fourthroot dintegral tintegral because approxeq notapproxeq
       notidentical stricteq braille_dot_1 braille_dot_2 braille_dot_3
       braille_dot_4 braille_dot_5 braille_dot_6 braille_dot_7
       braille_dot_8 braille_dot_9 braille_dot_10 braille_blank
       braille_dots_1 braille_dots_2 braille_dots_12 braille_dots_3
       braille_dots_13 braille_dots_23 braille_dots_123 braille_dots_4
       braille_dots_14 braille_dots_24 braille_dots_124 braille_dots_34
       braille_dots_134 braille_dots_234 braille_dots_1234 braille_dots_5
       braille_dots_15 braille_dots_25 braille_dots_125 braille_dots_35
       braille_dots_135 braille_dots_235 braille_dots_1235
       braille_dots_45 braille_dots_145 braille_dots_245
       braille_dots_1245 braille_dots_345 braille_dots_1345
       braille_dots_2345 braille_dots_12345 braille_dots_6
       braille_dots_16 braille_dots_26 braille_dots_126 braille_dots_36
       braille_dots_136 braille_dots_236 braille_dots_1236
       braille_dots_46 braille_dots_146 braille_dots_246
       braille_dots_1246 braille_dots_346 braille_dots_1346
       braille_dots_2346 braille_dots_12346 braille_dots_56
       braille_dots_156 braille_dots_256 braille_dots_1256
       braille_dots_356 braille_dots_1356 braille_dots_2356
       braille_dots_12356 braille_dots_456 braille_dots_1456
       braille_dots_2456 braille_dots_12456 braille_dots_3456
       braille_dots_13456 braille_dots_23456 braille_dots_123456
       braille_dots_7 braille_dots_17 braille_dots_27 braille_dots_127
       braille_dots_37 braille_dots_137 braille_dots_237
       braille_dots_1237 braille_dots_47 braille_dots_147
       braille_dots_247 braille_dots_1247 braille_dots_347
       braille_dots_1347 braille_dots_2347 braille_dots_12347
       braille_dots_57 braille_dots_157 braille_dots_257
       braille_dots_1257 braille_dots_357 braille_dots_1357
       braille_dots_2357 braille_dots_12357 braille_dots_457
       braille_dots_1457 braille_dots_2457 braille_dots_12457
       braille_dots_3457 braille_dots_13457 braille_dots_23457
       braille_dots_123457 braille_dots_67 braille_dots_167
       braille_dots_267 braille_dots_1267 braille_dots_367
       braille_dots_1367 braille_dots_2367 braille_dots_12367
       braille_dots_467 braille_dots_1467 braille_dots_2467
       braille_dots_12467 braille_dots_3467 braille_dots_13467
       braille_dots_23467 braille_dots_123467 braille_dots_567
       braille_dots_1567 braille_dots_2567 braille_dots_12567
       braille_dots_3567 braille_dots_13567 braille_dots_23567
       braille_dots_123567 braille_dots_4567 braille_dots_14567
       braille_dots_24567 braille_dots_124567 braille_dots_34567
       braille_dots_134567 braille_dots_234567 braille_dots_1234567
       braille_dots_8 braille_dots_18 braille_dots_28 braille_dots_128
       braille_dots_38 braille_dots_138 braille_dots_238
       braille_dots_1238 braille_dots_48 braille_dots_148
       braille_dots_248 braille_dots_1248 braille_dots_348
       braille_dots_1348 braille_dots_2348 braille_dots_12348
       braille_dots_58 braille_dots_158 braille_dots_258
       braille_dots_1258 braille_dots_358 braille_dots_1358
       braille_dots_2358 braille_dots_12358 braille_dots_458
       braille_dots_1458 braille_dots_2458 braille_dots_12458
       braille_dots_3458 braille_dots_13458 braille_dots_23458
       braille_dots_123458 braille_dots_68 braille_dots_168
       braille_dots_268 braille_dots_1268 braille_dots_368
       braille_dots_1368 braille_dots_2368 braille_dots_12368
       braille_dots_468 braille_dots_1468 braille_dots_2468
       braille_dots_12468 braille_dots_3468 braille_dots_13468
       braille_dots_23468 braille_dots_123468 braille_dots_568
       braille_dots_1568 braille_dots_2568 braille_dots_12568
       braille_dots_3568 braille_dots_13568 braille_dots_23568
       braille_dots_123568 braille_dots_4568 braille_dots_14568
       braille_dots_24568 braille_dots_124568 braille_dots_34568
       braille_dots_134568 braille_dots_234568 braille_dots_1234568
       braille_dots_78 braille_dots_178 braille_dots_278
       braille_dots_1278 braille_dots_378 braille_dots_1378
       braille_dots_2378 braille_dots_12378 braille_dots_478
       braille_dots_1478 braille_dots_2478 braille_dots_12478
       braille_dots_3478 braille_dots_13478 braille_dots_23478
       braille_dots_123478 braille_dots_578 braille_dots_1578
       braille_dots_2578 braille_dots_12578 braille_dots_3578
       braille_dots_13578 braille_dots_23578 braille_dots_123578
       braille_dots_4578 braille_dots_14578 braille_dots_24578
       braille_dots_124578 braille_dots_34578 braille_dots_134578
       braille_dots_234578 braille_dots_1234578 braille_dots_678
       braille_dots_1678 braille_dots_2678 braille_dots_12678
       braille_dots_3678 braille_dots_13678 braille_dots_23678
       braille_dots_123678 braille_dots_4678 braille_dots_14678
       braille_dots_24678 braille_dots_124678 braille_dots_34678
       braille_dots_134678 braille_dots_234678 braille_dots_1234678
       braille_dots_5678 braille_dots_15678 braille_dots_25678
       braille_dots_125678 braille_dots_35678 braille_dots_135678
       braille_dots_235678 braille_dots_1235678 braille_dots_45678
       braille_dots_145678 braille_dots_245678 braille_dots_1245678
       braille_dots_345678 braille_dots_1345678 braille_dots_2345678
       braille_dots_12345678 Sinh_ng Sinh_h2 Sinh_a Sinh_aa Sinh_ae
       Sinh_aee Sinh_i Sinh_ii Sinh_u Sinh_uu Sinh_ri Sinh_rii Sinh_lu
       Sinh_luu Sinh_e Sinh_ee Sinh_ai Sinh_o Sinh_oo Sinh_au Sinh_ka
       Sinh_kha Sinh_ga Sinh_gha Sinh_ng2 Sinh_nga Sinh_ca Sinh_cha
       Sinh_ja Sinh_jha Sinh_nya Sinh_jnya Sinh_nja Sinh_tta Sinh_ttha
       Sinh_dda Sinh_ddha Sinh_nna Sinh_ndda Sinh_tha Sinh_thha Sinh_dha
       Sinh_dhha Sinh_na Sinh_ndha Sinh_pa Sinh_pha Sinh_ba Sinh_bha
       Sinh_ma Sinh_mba Sinh_ya Sinh_ra Sinh_la Sinh_va Sinh_sha
       Sinh_ssha Sinh_sa Sinh_ha Sinh_lla Sinh_fa Sinh_al Sinh_aa2
       Sinh_ae2 Sinh_aee2 Sinh_i2 Sinh_ii2 Sinh_u2 Sinh_uu2 Sinh_ru2
       Sinh_e2 Sinh_ee2 Sinh_ai2 Sinh_o2 Sinh_oo2 Sinh_au2 Sinh_lu2
       Sinh_ruu2 Sinh_luu2 Sinh_kunddaliya ModeLock MonBrightnessUp
       MonBrightnessDown KbdLightOnOff KbdBrightnessUp KbdBrightnessDown
       Standby AudioLowerVolume AudioMute AudioRaiseVolume AudioPlay
       AudioStop AudioPrev AudioNext HomePage Mail Start Search
       AudioRecord Calculator Memo ToDoList Calendar PowerDown
       ContrastAdjust RockerUp RockerDown RockerEnter Back Forward Stop
       Refresh PowerOff WakeUp Eject ScreenSaver WWW Sleep Favorites
       AudioPause AudioMedia MyComputer VendorHome LightBulb Shop History
       OpenURL AddFavorite HotLinks BrightnessAdjust Finance Community
       AudioRewind BackForward Launch0 Launch1 Launch2 Launch3 Launch4
       Launch5 Launch6 Launch7 Launch8 Launch9 LaunchA LaunchB LaunchC
       LaunchD LaunchE LaunchF ApplicationLeft ApplicationRight Book CD
       WindowClear Close Copy Cut Display DOS Documents Excel Explorer
       Game Go iTouch LogOff Market Meeting MenuKB MenuPB MySites New
       News OfficeHome Open Option Paste Phone Reply Reload RotateWindows
       RotationPB RotationKB Save ScrollUp ScrollDown ScrollClick Send
       Spell SplitScreen Support TaskPane Terminal Tools Travel UserPB
       User1KB User2KB Video WheelButton Word Xfer ZoomIn ZoomOut Away
       Messenger WebCam MailForward Pictures Music Battery Bluetooth WLAN
       UWB AudioForward AudioRepeat AudioRandomPlay Subtitle
       AudioCycleTrack CycleAngle FrameBack FrameForward Time
       SelectButton View TopMenu Red Green Yellow Blue Suspend Hibernate
       TouchpadToggle TouchpadOn TouchpadOff AudioMicMute Keyboard WWAN
       RFKill AudioPreset Switch_VT_1 Switch_VT_2 Switch_VT_3 Switch_VT_4
       Switch_VT_5 Switch_VT_6 Switch_VT_7 Switch_VT_8 Switch_VT_9
       Switch_VT_10 Switch_VT_11 Switch_VT_12 Ungrab ClearGrab Next_VMode
       Prev_VMode LogWindowTree LogGrabInfo ).each do |key|
      fname = File.join(__dir__, "keysym", "key_" + key + ".rb")
      const = ("Key_" + key).to_sym
      autoload(const, fname)
    end


    class << self

      ## return an integer value for a named key code in Gdk
      ##
      ## This is a convenience method for operation on Gdk key code
      ## definitions in this module.
      ##
      ## The `key` argument may be provided as a string, symbol, or
      ## integer.
      ##
      ## If provided as a string or symbol, the string "Key_" will be
      ## added as a suiffix to the literal string representation of the
      ## provided key name. The resulting constant name must denote a
      ## constant in the module Keysym. If a matching constant is found,
      ## the integer value of that constant will be returned. Else, an
      ## ArgumentError will be raised.
      ##
      ## If provided as an integer, the value itself will be returned
      ##
      ## If provided as nil or false, the integer 0 will returned.
      ##
      ## @return [Integer] the 32-bit unsigned integer representation of
      ## the named key
      ##
      ## @see modifier_mask for computing the key modifier mask for a
      ## GTK accelerator definition, using a method of a similar syntax
      ## and semantics
      ##
      ## @see Gtk::Widget.add_accelerator
      ##
      ## @see PebblApp::AccelMixin
      def key_code(key)
        case key
        when String, Symbol
          name = ("Key_" + key.to_s).to_sym
          if Keysym.const_defined?(name)
            return Keysym.const_get(name)
          else
            raise ArgumentError.new("Key not found: #{key}")
          end
        when Integer
          return key
        else
          raise ArgumentError.new("Unable to parse key name: #{key}")
        end
      end

      ## return an integer value for a named key modifier mask
      ##
      ## This is a convenience method for operation on Gdk::ModifierType
      ## values, producing an integer return value.
      ##
      ## The `mask` argument may be provided as a string, symbol,
      ## Gdk::ModifierType, integer, an array of any value of the
      ## previous types, or either of the literal values nil or false.
      ##
      ## If an array, the integer return value will provide a bitwise
      ## 'or' mask for the set of modifier keys named in the array.
      ##
      ## If provided as a string or symbol, the string "_MASK" will be
      ## added as a suffix to the uppcased string representation of the
      ## provided mask. The resulting name must denote a constant in the
      ## module Gdk::ModifierType. If a matching constant is found, the
      ## integer value of that constant will be returned. Else, an
      ## ArgumentError will be raised.
      ##
      ## If provided as a Gdk::ModifierType, the integer value of that
      ## modifier type will be returned.
      ##
      ## If provided as an integer, the value itself will be returned.
      ##
      ## If provided as nil or false, the integer 0 will returned.
      ##
      ## Examples
      ## ~~~~
      ## PebblApp::Keysym.modifier_mask([:mod1, :control])
      ## => 12
      ##
      ## PebblApp::Keysym.modifier_mask("MOD1")
      ## => 8
      ##
      ## PebblApp::Keysym.modifier_mask(:control)
      ## => 4
      ##
      ## PebblApp::Keysym.modifier_mask(false)
      ## => 0
      ##
      ## PebblApp::Keysym.modifier_mask(12)
      ## => 12
      ## ~~~~
      ##
      ## @return [Integer] the bitwise numeric representation of the
      ##  modifier mask
      ##
      ## @see key_code for computing a numeric key code of a named key
      def modifier_mask(mask)
        case mask
        when NilClass, FalseClass
          return 0
        when String, Symbol
          name = mask.to_s.upcase + "_MASK"
          if Gdk::ModifierType.const_defined?(name)
            return Gdk::ModifierType.const_get(name).to_i
          else
            raise ArgumentError.new("Modifier not found: #{name}")
          end
        when Gdk::ModifierType
          return mask.to_i
        when Integer
          return mask
        when Array
          value = 0
          mask.each do |key|
            value = modifier_mask(key) | value
          end
          return value
        else
          raise ArgumentError.new("Unable to parse modifier name: #{mask}")
        end
      end

    end ## class << Keysym
  end ## Keysym
end ## PebblApp
