!!
    RFO_MOUSE.BAS
    
    Ce programme est une souris TCP/IP code en RFO basic
    pour les telephones et tablettes Android
    qui se connecte a Free-DCC-PC ou la centrale D17
    
    Historique:
    2018-02-09: Ulysse Delmas-Begue: ajout avertissement passage ANA à DCC
                                     modification des input pour ne plus avoir la partie decimale
    2017-01-24: Ulysse Delmas-Begue: optimisation de la transmission des fonctions F1-F28
    2017-12-27: Ulysse Delmas-Begue: ajout des fonctions F25-F28
                                     zoom en utilisant xscale
    2017-12-27: Ulysse Delmas-Begue: passage de l'affichage de la vitesse de 0-28crans a 0-100%
                                     ajout des fonctions F5-F24
                                     adaptation automatique a la taille de l'ecran
                                     en m'inspirant fortement du code de JM Dubois
                                     http://jmdubois.free.fr/fdcc/rfo-souris.bas
    2017-12-22: Ulysse Delmas-Begue: ajout de l'accelerometre
                                     ajout de la programmation des decodeurs
                                     adresses 1-50 --> 0-99
                                     ajout de boutons pour les sorties
    2017-06-20: Ulysse Delmas-Begue: creation
    
    Notes:
    - On programme souvent en Anglais ainsi mouse signifie souris ...
    
    TBD:
    - reconnection wifi
    - interogations (AU, mode ...)
    - optimiser la transmission des fonctions auxiliaires
    
    Licence: GPLv2  
!!    


!***************** CONFIGURATION ************************

! Adresse du serveur FDCC-PC 
! ex: "192.168.0.100"
! ex: "" (Dans ce cas le programme demande a l'utilisateur d'indiquer l'adresse IP)
ip$ = "192.168.4.1"

! Port du serveur FDCC-PC 
! ex: 1234 (port par defaut de FDCC-PC)
! ex: 0 (Dans ce cas le programme demande a l'utilisateur d'indiquer le port TCP)
port = 1234

! Adresse de la locomotive 
! ex: 3
! ex: 1  (Dans ce cas la centrale fonctionne en analogique)
! ex: 0  (Dans ce cas la souris n'est assignee a aucune loco)
! ex: -1 (Dans ce cas le programme demande a l'utilisateur d'indiquer l'adresse DCC)
dcc_adr = 0

! Autorisation de la programmation des decodeurs
dcc_prog_on = 1

! Activation du wifi (desactivation si 0 pour deboguer)
use_net = 1

! Si des parametres manquent, ils sont demandes
IF(ip$ = "") THEN INPUT "Adresse IP ?", ip$
    
IF(port = 0) THEN
    INPUT "Port TCP ?", s$, "1234"
	port = val(s$)
ENDIF	

IF(dcc_adr = -1) THEN 
    INPUT "Loco ?", s$, 3
	dcc_adr = val(s$)
ENDIF	
IF(dcc_adr >= 10.0) THEN n = 2 ELSE n = 1
dcc_adr$ = left$(str$(dcc_adr), n)  



!***************** OUVERTURE DE LA LIAISON TCP/IP ************************

IF(use_net) THEN
    ! Connect to FDCC-PC server
    SOCKET.CLIENT.CONNECT ip$, port
    PRINT "Connected"

    ! Wait after server welcome message
    ! or time out after 10 seconds
    maxclock = CLOCK() + 10000
    DO
        SOCKET.CLIENT.READ.READY flag
        IF CLOCK() > maxclock
            PRINT "ERR: Pas de message de bienvenu du serveur FDCC-PC"
            END
        ENDIF
    UNTIL flag
    SOCKET.CLIENT.READ.LINE msg$
    PRINT msg$
    msg$ = "souris d17 netv1"
    SOCKET.CLIENT.WRITE.LINE msg$
    pause 1000
ENDIF   



!***************** VARIABLES DE LA SOURIS ************************

au = 1      %on demarre en AU maintenant mais sans envoyer l'ordre
old_au = 1

sens = 1
vit = 0
old_vit = 0
vit$ = "0"

fct0 = 0
DIM fct[30]
FOR i = 1 TO 30
    fct[i] = 0
NEXT i

DIM fout[6]
DIM oldfout[6]
FOR i = 1 TO 6
    fout[i] = 0
    oldfout[i] = 0
NEXT i

old_touched = 0
touched = 0

cmess$ = ""
old_cmess$ = ""
old_au_red = 0
au_red = 0
old_sens$ = "?"
old_vit$ = "?"

cv_adr=0
cv_dat=0
cv_code=0
cv_adr$=""
cv_dat$=""
cv_code$=""

fbase = 0
update_fct = 1

v_range = 100  


!***************** CREATION DE L'INTERFACE GRAPHIQUE ************************

! parametrage du graphique

!GR.OPEN 255, 255, 255, 255
GR.OPEN 255, 0, 0, 0


! calcul du zoom a appliquer aux coordonees
! Le programme a ete developpe pour fonctionner en 1024x600 paysage
! Le zoom adapte l'interface aux autres definitions
! en prenant le maximum de place mais sans modifier la geometrie 
! orienattion 0=paysage 1=portrait (non conseille: -1=auto 2=paysage_inv 3=portrait_inv)
!wdev = 1024
!hdev = 552
!orientation = 0
wdev=380
hdev=552
orientation = 1
GR.ORIENTATION orientation
GR.SCREEN w , h
zm1 = w/wdev
zm2 = h/hdev
IF(zm2<zm1) THEN zoom=zm2 ELSE zoom=zm1

!zoom = 0.5
GR.SCALE zoom, zoom    % !!!!!attention le scale ne joue pas sur le touch

GR.TEXT.ALIGN 2 %center
GR.TEXT.SIZE hdev / 20

! creation de quelques pinceaux
! (ne pas faire le stroke apres le fill car c'est fill ou stroke !)

GR.COLOR 255, 0, 255, 0, 1 %fill
GR.PAINT.GET p_paint_green

GR.COLOR 255, 255, 0, 0, 1 %fill
GR.PAINT.GET p_paint_red

GR.COLOR 255, 136, 136, 136, 1 %fill
GR.PAINT.GET p_paint_grey

GR.COLOR 255, 240, 240, 0, 1 %fill
GR.PAINT.GET p_paint_yellow

GR.COLOR 255, 0, 0, 255, 1 %fill
GR.PAINT.GET p_paint_blue

GR.COLOR 255, 255, 136, 136, 1 %fill
GR.PAINT.GET p_paint_sens_0

GR.COLOR 255, 136, 136, 255, 1 %fill
GR.PAINT.GET p_paint_sens_1

! Widgets

    ! rectangle zone de fond (POT et FCT)
    GR.COLOR 255, 91, 155, 213, 1 %fill
    GR.RECT p_rectfond, 0, 0, 290, 470

    ! rectangle zone des options
    GR.COLOR 255, 128, 155, 213, 1 %fill
    GR.RECT p_rectfond, 0, 470, 380, 600

    ! rectangle zonz des sorties
    GR.COLOR 255, 81, 135, 183, 1 %fill
    GR.RECT p_rectfond, 290, 0, 380, 470
    
    ! creation label dcc adr
    GR.COLOR 255, 0, 0, 0, 1 %fill
    !GR.TEXT.DRAW p_txtdccadr, 25, 35, "$" + dcc_adr$
    GR.TEXT.DRAW p_txtdccadr, 200, 35, "$" + dcc_adr$

    ! creation label cran
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_txtvit, 70, 35, "+0%"
    
    ! creation potentiometre
    ! glissiere
    pot_x = 70
    pot_y = 350
    pot_h = 280
    GR.COLOR 255, 192,192, 192, 1 %fill
    GR.RECT p_rectglissiere, pot_x - 20, pot_y - pot_h, pot_x + 20, pot_y
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, pot_x - 20, pot_y - pot_h, pot_x + 20, pot_y
    ! cursor
    GR.COLOR 255, 255, 0, 0, 1 %fill
    GR.RECT p_rectcursor, pot_x - 50, pot_y - 10, pot_x + 50, pot_y + 10
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_rcursor, pot_x - 50, pot_y - 10, pot_x + 50, pot_y + 10

    ! creation bouton sens
    b_sens_x = 70
    b_sens_y = 430
    b_sens_x1 = b_sens_x - 30
    b_sens_x2 = b_sens_x + 30
    b_sens_y1 = b_sens_y - 30
    b_sens_y2 = b_sens_y + 30
    GR.COLOR 255, 136, 136, 255, 1 %fill
    GR.RECT p_rectsens, b_sens_x1, b_sens_y1, b_sens_x2, b_sens_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_sens_x1, b_sens_y1, b_sens_x2, b_sens_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_txtsens, b_sens_x, b_sens_y+10, "+"

    ! creation bouton AU
    b_au_x = 50
    b_au_y = 510
    b_au_x1 = b_au_x - 30
    b_au_x2 = b_au_x + 30
    b_au_y1 = b_au_y - 30
    b_au_y2 = b_au_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_rectau, b_au_x1, b_au_y1, b_au_x2, b_au_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_au_x1, b_au_y1, b_au_x2, b_au_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_txtau, b_au_x, b_au_y+10, "AU"
    
    ! creation bouton adr
    b_adr_x = 140
    b_adr_y = 510
    b_adr_x1 = b_adr_x - 30
    b_adr_x2 = b_adr_x + 30
    b_adr_y1 = b_adr_y - 30
    b_adr_y2 = b_adr_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_rectadr, b_adr_x1, b_adr_y1, b_adr_x2, b_adr_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_adr_x1, b_adr_y1, b_adr_x2, b_adr_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_txtadr, b_adr_x, b_adr_y+10, "adr"

    ! creation bouton prog
    b_prog_x = 240
    b_prog_y = 510
    b_prog_x1 = b_prog_x - 30
    b_prog_x2 = b_prog_x + 30
    b_prog_y1 = b_prog_y - 30
    b_prog_y2 = b_prog_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_rectprog, b_prog_x1, b_prog_y1, b_prog_x2, b_prog_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_prog_x1, b_prog_y1, b_prog_x2, b_prog_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_txtprog, b_prog_x, b_prog_y+10, "prg"

    ! creation bouton acc
    b_acc_x = 340
    b_acc_y = 510
    b_acc_x1 = b_acc_x - 30
    b_acc_x2 = b_acc_x + 30
    b_acc_y1 = b_acc_y - 30
    b_acc_y2 = b_acc_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_rectacc, b_acc_x1, b_acc_y1, b_acc_x2, b_acc_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_acc_x1, b_acc_y1, b_acc_x2, b_acc_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_txtacc, b_acc_x, b_acc_y+10, "acc"  

    ! creation bouton fct    
    
    ! F0
    b_f0_x = 170
    b_f0_y = 80
    b_f0_x1 = b_f0_x - 30
    b_f0_x2 = b_f0_x + 30
    b_f0_y1 = b_f0_y - 30
    b_f0_y2 = b_f0_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_rectf0, b_f0_x1, b_f0_y1, b_f0_x2, b_f0_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_f0_x1, b_f0_y1, b_f0_x2, b_f0_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_r, b_f0_x, b_f0_y+10, "F0"
    
    ! F>
    b_fn_x = 170+70
    b_fn_y = 80
    b_fn_x1 = b_fn_x - 30
    b_fn_x2 = b_fn_x + 30
    b_fn_y1 = b_fn_y - 30
    b_fn_y2 = b_fn_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_rectfn, b_fn_x1, b_fn_y1, b_fn_x2, b_fn_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_fn_x1, b_fn_y1, b_fn_x2, b_fn_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_r, b_fn_x, b_fn_y+10, "F>"
    
    ! F1--F10 qui serviront aussi a F11--F20 F21--F30 (F29 & F30 ne sont pas utilises)
    DIM p_rectfct[10] %warning in RFO basic, first elmeent is index 1
    DIM p_txtfct[10]
    b_f_x = 170
    b_f_y = 150
    b_f_dy = 70
    b_f_dx = 70
    b_f_x1 = b_f_x - 30
    b_f_x2 = b_f_x + 30
    b_f_y1 = b_f_y - 30
    b_f_y2 = b_f_y + 30
    FOR j = 1 TO 2
        FOR i = 1 TO 5
            ind = i+5*(j-1)  %1-10
            GR.COLOR 255, 136, 136, 136, 1 %fill
            GR.RECT p_rectfct[ind], b_f_x1 + b_f_dx * (j-1), b_f_y1 + b_f_dy * (i-1), b_f_x2 + b_f_dx * (j-1), b_f_y2 + b_f_dy * (i-1)
            GR.COLOR 255, 0, 0, 0, 0 %border
            GR.RECT p_r, b_f_x1 + b_f_dx * (j-1), b_f_y1 + b_f_dy * (i-1), b_f_x2 + b_f_dx * (j-1), b_f_y2 + b_f_dy * (i-1)
            GR.COLOR 255, 0, 0, 0, 1 %fill
            s$ = "F"
            !IF(i = 1 & j = 1) THEN s$ = "F0"
            GR.TEXT.DRAW p_txtfct[ind], b_f_x + b_f_dx * (j-1), b_f_y + b_f_dy * (i-1) + 10, s$
            update_fct = 1   %le nom des fonctions sera mise a jour dans la boucle
        NEXT i
    NEXT j

    ! creation bouton sorties    
    DIM p_rectout[6]
    b_out_x = 340
    b_out_y = 80
    b_out_dy = 70
    b_out_x1 = b_out_x - 30
    b_out_x2 = b_out_x + 30
    b_out_y1 = b_out_y - 30
    b_out_y2 = b_out_y + 30
    FOR i = 1 TO 6
        GR.COLOR 255, 136, 136, 136, 1 %fill
        GR.RECT p_rectout[i], b_out_x1, b_out_y1 + b_out_dy * (i-1), b_out_x2, b_out_y2 + b_out_dy * (i-1)
        GR.COLOR 255, 0, 0, 0, 0 %border
        GR.RECT p_r, b_out_x1, b_out_y1 + b_out_dy * (i-1), b_out_x2, b_out_y2 + b_out_dy * (i-1)
        GR.COLOR 255, 0, 0, 0, 1 %fill
        GR.TEXT.DRAW p_txtout, b_out_x, b_out_y + b_out_dy * (i-1) + 10, "o" + left$(str$(i-1),1)
    NEXT i  b_out_x = 300
                
    GR.RENDER   %toujours faire render, car RECT ... dessinent en memoire

    ! Open the acclerometer sensor
    !ouverture maintenant seulement au 1er appuie pour qu'on ne l'ouvre pas sur les appareils qui n'en ont pas
    !SENSORS.OPEN 1  
    acc_open = 0

    
    
!***************** MISE A JOUR L'INTERFACE GRAPHIQUE ************************
use_acc=0
inv_acc=0
acc_x=0
acc_y=0
acc_z=0

cpt = 0
tx_ok = 0

redraw_pot = 1

DO
    pause 50
    old_touched = touched
    GR.TOUCH touched, tx, ty    %attention xscale ne marche pas sur Touch
    tx = tx/zoom
    ty = ty/zoom
    
    cpt += 1
    IF(cpt = 10) THEN cpt = 0
    tx_ok = BXOR(tx_ok, 1) %transmettre une fois/2 (toutes les 100ms)
    
    ! APPUI CONSTANT
    IF(touched) THEN
        !d_u.continue
      
        ! Gestion du potentiometre
        IF(tx >= (pot_x - 50) & tx <= (pot_x + 50) & ty < (pot_y+20)) THEN
            vit = v_range * (pot_y - ty) / pot_h
            redraw_pot = 1
        ENDIF      
    ENDIF

    
    ! ACC   -7>-2 STOP 2->7
    IF(use_acc) THEN
        !Read the acclerometer (en g)
        SENSORS.READ 1,acc_y,acc_x,acc_z
        !PRINT "x=" + str$(acc_x) + " y=" + str$(acc_y) + str$(acc_z)

        IF(orientation = 0) THEN acc = acc_y
        IF(orientation = 1) THEN acc = acc_x
        IF(inv_acc) THEN acc = -acc
        
        IF(acc<-1) THEN
            sens=0
            sens$="-"
            IF(old_sens$ <> "-") THEN
                GR.MODIFY p_rectsens, "paint", p_paint_sens_0
                  GR.MODIFY p_txtsens, "text", sens$
            ENDIF
        ENDIF
        IF(acc>1) THEN
            sens=1
            sens$="+"
            IF(old_sens$ <> "+") THEN
                GR.MODIFY p_rectsens, "paint", p_paint_sens_1
                GR.MODIFY p_txtsens, "text", sens$
            ENDIF
        ENDIF
        old_sens$ = sens$

        IF(acc<0) THEN
            acc=-acc
        ENDIF
        IF(acc<2) THEN
            vit=0
        ELSE
            IF(acc>7) THEN
                vit=v_range
            ELSE   %IF((acc>=2) and (acc<=7)) THEN
                acc=acc-2  %0-5
                vit = (v_range * acc) / 5.0
            ENDIF
        ENDIF
        
        IF(old_vit<>vit) THEN
            redraw_pot = 1
        ENDIF
    ENDIF
        
        
    IF(redraw_pot) THEN
        IF(vit < 0 ) THEN vit=0
        IF(vit > v_range) THEN vit=v_range
        IF(vit >= 10.0) THEN n = 2 else n = 1
        IF(vit >= 100.0) THEN n = 3
        vit$ = left$(str$(vit), n)
        IF(vit = 0) THEN vit$ = "0"
        y = pot_y - pot_h * vit / v_range
        yh = (y - 10)
        yl = (y + 10)
        GR.MODIFY p_rectcursor, "top"   , yh
        GR.MODIFY p_rectcursor, "bottom", yl
        GR.MODIFY p_rcursor   , "top"   , yh
        GR.MODIFY p_rcursor   , "bottom", yl
        IF(sens = 1) THEN vvit$ = "+" ELSE vvit$ = "-"
        vvit$ += vit$ + "%"
        GR.MODIFY p_txtvit    , "text"  , vvit$
        old_vit$ = vit$
        old_vit = vit
        redraw_pot = 0
    ENDIF

    
    
    ! APPUI FRONT
    IF(old_touched = 0 & touched = 1) THEN
    
        ! Gestion du bouton sens
        IF(tx >= b_sens_x1 & tx <= b_sens_x2 & ty > b_sens_y1 & ty < b_sens_y2) THEN
            sens = BXOR(sens, 1)
            IF(sens = 1) THEN
                sens$ = "+"
                GR.MODIFY p_rectsens, "paint", p_paint_sens_1
            ELSE
                sens$ = "-"
                GR.MODIFY p_rectsens, "paint", p_paint_sens_0
            ENDIF
            GR.MODIFY p_txtsens, "text", sens$
            
            IF(sens = 1) THEN vvit$ = "+" ELSE vvit$ = "-"
            vvit$ += vit$ + "%"
            GR.MODIFY p_txtvit, "text"  , vvit$
            
            !GR.RENDER
            old_sens$ = sens$

            IF(use_acc) THEN
                inv_acc = BXOR(inv_acc, 1)
            ENDIF
        ENDIF
      
        ! Gestion du bouton AU
        IF(tx >= b_au_x1 & tx <= b_au_x2 & ty > b_au_y1 & ty < b_au_y2) THEN
            au = BXOR(au, 1)
        ENDIF
      
        ! Gestion des boutons des fonctions
        
        ! F0
        IF(tx > b_f0_x1 & tx < b_f0_x2 & ty > b_f0_y1 & ty < b_f0_y2 ) THEN 
            fct0 = BXOR(fct0, 1)
            IF(fct0 = 0) THEN
                GR.MODIFY p_rectf0, "paint", p_paint_grey 
            ELSE
                GR.MODIFY p_rectf0, "paint", p_paint_yellow
            ENDIF
        ENDIF
        
        ! F1-F28        
        IF(tx > b_f_x1 & tx < b_f_x2 + 70 & ty > b_f_y1 & ty < b_f_y2 + 4 * 70) THEN
            IF(tx > b_f_x2 + 5) THEN col = 1 ELSE col = 0
            lgn = 0
            IF(ty > b_f_y2 + 5  ) THEN lgn = 1
            IF(ty > b_f_y2 + 75 ) THEN lgn = 2
            IF(ty > b_f_y2 + 145) THEN lgn = 3
            IF(ty > b_f_y2 + 215) THEN lgn = 4
            num = fbase + 5 * col + lgn + 1
            IF(num<=28) THEN
                fct[num] = BXOR(fct[num], 1)
                update_fct = 1
            ENDIF
        ENDIF
        
        ! F>
        IF(tx > b_fn_x1 & tx < b_fn_x2 & ty > b_fn_y1 & ty < b_fn_y2 ) THEN
            fbase += 10
            IF(fbase = 30) THEN fbase = 0   % 0,10,20
            update_fct = 1
        ENDIF
    
        ! Gestion des boutons des sorties
        IF(tx > b_out_x1 & tx < b_out_x2) THEN 
            FOR i = 1 to 6
                IF(ty > b_out_y1 + b_out_dy * (i-1) & ty < b_out_y2 + b_out_dy * (i-1)) THEN
                    fout[i] = BXOR(fout[i], 1)
                    IF(fout[i] = 0) THEN
                        GR.MODIFY p_rectout[i], "paint", p_paint_grey 
                    ELSE
                        GR.MODIFY p_rectout[i], "paint", p_paint_blue
                    ENDIF
                    !GR.RENDER
                ENDIF
            NEXT i
        ENDIF
        
        ! Gestion du changement d'adresse de locomotive
        IF(tx >= b_adr_x1 & tx <= b_adr_x2 & ty > b_adr_y1 & ty < b_adr_y2) THEN
		    old_adr = dcc_adr
            !GR.FRONT 0
            DO
                !INPUT "Loco ?", dcc_adr, dcc_adr
    			INPUT "Loco ?", dcc_adr$, dcc_adr$
				dcc_adr = val(dcc_adr$)			
                !IF(dcc_adr >= 10.0) THEN n = 2 ELSE n = 1
                !dcc_adr$ = left$(str$(dcc_adr), n)    
            UNTIL(dcc_adr >= 0 & dcc_adr <= 99)
			IF(old_adr = 1 & dcc_adr <> 1) THEN
                INPUT "ATTENTION, PASSAGE DE L'ANALOGIQUE AU DCC. RETIRER LA LOCO ANALOGIQUE !", s$, "OK"
			ENDIF
			IF(old_adr <> 1 & dcc_adr = 1) THEN
                INPUT "ATTENTION, PASSAGE DU DCC A L'ANALOGIQUE !", s$, "OK"
			ENDIF
			!GR.FRONT 1
            GR.MODIFY p_txtdccadr, "text", "$" + dcc_adr$
            !GR.RENDER
        ENDIF

        ! Gestion de la programation des decodeurs (click en haut a droite)
        IF(tx >= b_prog_x1 & tx <= b_prog_x2 & ty > b_prog_y1 & ty < b_prog_y2) THEN
            IF(dcc_prog_on) THEN
                !GR.FRONT 0
                !PRINT "ATTENTION TOUTES LES LOCOS ALIMENTEES SERONT PROGRAMEES !"
            
                DO
                        INPUT "ATTENTION TOUTES LES LOCOS ALIMENTEES SERONT PROGRAMEES ! PROG CODE 0-9999 ?", s$, "1234"
						cv_code = val(s$)
                UNTIL(cv_code >= 0 & cv_code <= 9999)

                IF(cv_code >= 10.0) THEN n = 2 ELSE n = 1
                IF(cv_code >= 100.0) THEN n = 3
                IF(cv_code >= 1000.0) THEN n = 4
                IF(n = 4) THEN cv_code$ = ""
                IF(n = 3) THEN cv_code$ = "0"
                IF(n = 2) THEN cv_code$ = "00"
                IF(n = 1) THEN cv_code$ = "000"
                cv_code$ = cv_code$ + left$(str$(cv_code), n)    

                DO
                    INPUT "CV ADR 1-1024 ?", s$, "1"
					cv_adr = val(s$)
                UNTIL(cv_adr >= 1 & cv_adr <= 1024)
            
                IF(cv_adr >= 10.0) THEN n = 2 ELSE n = 1
                IF(cv_adr >= 100.0) THEN n = 3
                IF(cv_adr >= 1000.0) THEN n = 4
                IF(n = 4) THEN cv_adr$ = ""
                IF(n = 3) THEN cv_adr$ = "0"
                IF(n = 2) THEN cv_adr$ = "00"
                IF(n = 1) THEN cv_adr$ = "000"
                cv_adr$ = cv_adr$ + left$(str$(cv_adr), n)    
            
                DO
                    INPUT "CV DAT 0-255 ?", s$, "3"
    				cv_dat = val(s$)
                UNTIL(cv_dat >= 0 & cv_dat <= 255)
            
                IF(cv_dat >= 10.0) THEN n = 2 ELSE n = 1
                IF(cv_dat >= 100.0) THEN n = 3
                IF(n = 3) THEN cv_dat$ = "0"
                IF(n = 2) THEN cv_dat$ = "00"
                IF(n = 1) THEN cv_dat$ = "000"
                cv_dat$ = cv_dat$ + left$(str$(cv_dat), n)    
            
                cmess_prog$ = "cva" + cv_adr$ + " cvd" + cv_dat$ + " cvp" + cv_code$
                PRINT cmess_prog$
                IF(use_net) THEN
                    SOCKET.CLIENT.WRITE.LINE cmess_prog$
                ENDIF

                !GR.FRONT 1
            ENDIF
        ENDIF
        
        ! Gestion du bouton acc
        IF(tx >= b_acc_x1 & tx <= b_acc_x2 & ty > b_acc_y1 & ty < b_acc_y2) THEN
            use_acc = BXOR(use_acc, 1)
            IF(use_acc = 0) THEN
                !SENSORS.CLOSE 1
                GR.MODIFY p_rectacc, "paint", p_paint_grey 
            ELSE
                IF(acc_open = 0) THEN
                    SENSORS.OPEN 1
                    acc_open = 1
                ENDIF
                GR.MODIFY p_rectacc, "paint", p_paint_green
            ENDIF
        ENDIF
        
    ENDIF 

    ! Gestion du clignotement du bouton AU
    IF(au = 1 & cpt < 5) THEN
        au_red = 1
    ELSE
        au_red = 0
    ENDIF
    IF(au_red <> old_au_red) THEN
        old_au_red = au_red
        IF(au_red = 1) THEN 
            GR.MODIFY p_rectau, "paint", p_paint_red
        ELSE
            GR.MODIFY p_rectau, "paint", p_paint_grey
        ENDIF
    ENDIF

    ! Gestion de l'affichage des boutons des fonctions  
    ! en dehors du click pour pouvoir etre utilise par l'init
    IF(update_fct) THEN         
        update_fct = 0
        FOR i = 1 to 10
            num = fbase + i    % 1..10, 11..20, 21..30
            IF(num>=10) THEN
                s$ = "F" + left$(str$(num),2)
            ELSE
                s$ = "F" + left$(str$(num),1)
            ENDIF
            IF(num>=29 & num<=30) THEN s$=""
            GR.MODIFY p_txtfct[i], "text", s$
               IF(fct[num] = 0) THEN
                   GR.MODIFY p_rectfct[i], "paint", p_paint_grey 
               ELSE
                   GR.MODIFY p_rectfct[i], "paint", p_paint_yellow
               ENDIF
           NEXT i           
    ENDIF
  
    
!***************** TRANSMISSION DE LA COMMANDE ************************
    !ex de cmd: cmess$ = "a3 au0 s+ v25 f0+f1-f2-f3-f4-f5-f6-f7-f8- o5-"
    !toutes les fct d'une page sont transmises, seulement les sorties qui chnagenet sont transmisent
    
    IF(tx_ok) THEN
        cmess$ = "a"
        cmess$ += dcc_adr$
    
        IF(old_au <> au) THEN
            IF(au = 0) THEN
            cmess$ += " au0"
            ELSE
            cmess$ += " au1"
        ENDIF
        old_au = au
        ENDIF
    
        cmess$ += " v"
        cmess$ += vit$
    
        IF(sens = 1) THEN
            cmess$ += " s+"
        ELSE
            cmess$ += " s-"
        ENDIF
    
        cmess$ += " f0"
        IF(fct0 = 0) THEN
            cmess$ += "-"
        ELSE
            cmess$ += "+"
        ENDIF
        FOR i = 1 TO 10        % envoie seulement la base active
            num = fbase + i    % 1..10,11..20,21..28
            IF(num<=28) THEN
                IF(i = 1) THEN    %optimisation f1+f2-f3+f4+f5+f6+f7-f8-f9-f10+ --> f1+-++++---+
                    IF(num>=10) THEN
                        cmess$ += "f" + left$(str$(num),2)
                    ELSE
                        cmess$ += "f" + left$(str$(num),1)
                    ENDIF
                ENDIF
                IF(fct[num] = 0) THEN
                    cmess$ += "-"
                ELSE
                    cmess$ += "+"
                ENDIF
            ENDIF
        NEXT i

        cmess$ += " "
        FOR i = 1 TO 6
            IF(fout[i] <> oldfout[i]) THEN
                cmess$ += "o"
                cmess$ += left$(str$(i-1),1)
                IF(fout[i]=0) THEN
                    cmess$ += "-"
                ELSE
                    cmess$ += "+"
                ENDIF
                oldfout[i] = fout[i]
            ENDIF
        NEXT i
        
        IF(cmess$ <> old_cmess$) THEN
            !GR.FRONT 0
            !PRINT cmess$
            !PAUSE 2000
            !GR.FRONT 1
            !GR.RENDER
            IF(use_net) THEN
                SOCKET.CLIENT.WRITE.LINE cmess$
            ENDIF
        ENDIF
        old_cmess$ = cmess$
    
    ENDIF

    GR.RENDER
    
UNTIL(0)



 
 
 
