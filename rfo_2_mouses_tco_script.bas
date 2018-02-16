!!
    RFO_MOUSE.BAS
    
    Ce programme est une souris TCP/IP code en RFO basic
    pour les telephones et tablettes Android
    qui se connecte a la centrale D17
	
    Cette souris propose
    - un ecran permettant de conduire 2 locos
    - un ecran TCO
	- un mode script pour faire des sequences automatiques
        
    Historique:
      2018-02-09: Ulysse Delmas-Begue: ajout avertissement passage ANA à DCC
	                                   modification des input pour ne plus avoir la partie decimale
	                                   correctif bouton AU loco
      2018-01-24: Ulysse Delmas-Begue: ajout du script
      2018-01-24: Ulysse Delmas-Begue: passage de 1 a 5 TCO
      2018-01-24: Ulysse Delmas-Begue: ajout du TCO
      2017-01-24: Ulysse Delmas-Begue: optimisation de la transmission des fonctions F1-F28
      2018-01-23: Ulysse Delmas-Begue: correctif: le bouton sens n'etait pas mis a jour en mode acc
      2018-01-20: Ulysse Delmas-Begue: ajout de l'UM (Unites multiples)
      2018-01-20: Ulysse Delmas-Begue: support du multi touch (utile pour manipuler les 2 potentiometres en meme temps)
      2018-01-19: Ulysse Delmas-Begue: ajout d'une 2eme souris
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
        
    TBD:
      - reconnection wifi
      - affichage mode
	  - affichage courant (can)
	  - voir ecran de test
	  - voir si on passe tco dans un fichier
	  
	BUG:
	  - aucun

    Notes:
      On programme souvent en Anglais voici quelques traductions
	  - mouse   = souris
	  - in      = entree
	  - out     = sortie
	  - turnout = aiguillage

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

! Adresse de la locomotive 1ere souris
! ex: 3
! ex: 1  (Dans ce cas la centrale fonctionne en analogique)
! ex: 0  (Dans ce cas la souris n'est assignee a aucune loco)
! ex: -1 (Dans ce cas le programme demande a l'utilisateur d'indiquer l'adresse DCC)
m1_dcc_adr = 0

! Adresse de la locomotive 2eme souris
m2_dcc_adr = 0

! Autorisation de la programmation des decodeurs
dcc_prog_on = 1

! Activation du wifi (desactivation si 0 pour deboguer)
use_net = 1

! visualisation des zones de click (0 normalement)
see_click_zone = 0

! Si des parametres manquent, ils sont demandes
IF(ip$ = "") THEN INPUT "Adresse IP ?", ip$
    
IF(port = 0) THEN
    INPUT "Port TCP ?", s$, "1234"
	port = val(s$)
ENDIF	

IF(m1_dcc_adr = -1) THEN 
    INPUT "Loco ?", s$, 3
	m1_dcc_adr = val(s$)
ENDIF	
IF(m1_dcc_adr >= 10.0) THEN n = 2 ELSE n = 1
m1_dcc_adr$ = left$(str$(m1_dcc_adr), n)  

IF(m2_dcc_adr = -1) THEN 
    INPUT "Loco ?", s$, 3
	m2_dcc_adr = val(s$)
ENDIF	
IF(m2_dcc_adr >= 10.0) THEN n = 2 ELSE n = 1
m2_dcc_adr$ = left$(str$(m2_dcc_adr), n)  



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

! specific mouse1

m1_sens = 1
m1_old_sens = 2  %NA

m1_vit = 0
m1_old_vit = 0
m1_vit$ = "0"

m1_fct0 = 0
DIM m1_fct[30]
FOR i = 1 TO 30
    m1_fct[i] = 0
NEXT i
m1_fbase = 0
m1_update_fct = 1

m1_cmess$ = ""
m1_old_cmess$ = ""

m1_use_acc=0
m1_inv_acc=0


! specific mouse2

m2_sens = 1
m2_old_sens = 2

m2_vit = 0
m2_old_vit = 0
m2_vit$ = "0"

m2_fct0 = 0
DIM m2_fct[30]
FOR i = 1 TO 30
    m2_fct[i] = 0
NEXT i
m2_fbase = 0
m2_update_fct = 1

m2_cmess$ = ""
m2_old_cmess$ = ""

m2_use_acc=0
m2_inv_acc=0


! global

m0_cmess$ = ""
m0_old_cmess$ = ""
cmess$ = ""

au_msg$ = ""
au = 1      %on demarre en AU maintenant mais sans envoyer l'ordre
au_red = 0
old_au_red = 0

ana = 0
can$ = "00"
can = 0

DIM fout[6]
DIM oldfout[6]
FOR i = 1 TO 6
    fout[i] = 0
    oldfout[i] = 0
NEXT i

old_touched = 0
touched = 0
old_touched2 = 0
touched2 = 0

cv_adr=0
cv_dat=0
cv_code=0
cv_adr$=""
cv_dat$=""
cv_code$=""

v_range = 100  

um = 0

acc_open = 0  %ouverture au 1er appuie pour qu'on ne l'ouvre pas sur les appareils qui n'en ont pas

acc_x=0
acc_y=0
acc_z=0

cpt  = 0  %pour clignotement AU
cpt2 = 0  %pour ne pas transmettre a chaque fois 

m1_redraw_pot = 1
m2_redraw_pot = 1
m1_redraw_sens = 1
m2_redraw_sens = 1
first_aff = 1

LOC = 0
TCO = 1
mode = LOC

DIM m1_p_rectfct[10] %warning in RFO basic, first elmeent is index 1
DIM m1_p_txtfct[10]  %ici car les tableaux ne peuvent etre definit qu'une seule fois
DIM m2_p_rectfct[10]
DIM m2_p_txtfct[10]

script_on    = 0
script_clock = 0
script_tempo = 0
script_wait_in  = -1
script_wait_u   = -1
script_wait_val = 1
script_msg$ = ""

pf = 0 %file pointer

ok_to_tx = 1
rxed = 1
rxclock = clock()


!***************** VARIABLES DU TCO ************************

x0 = 0
y0 = 0
x1 = 0
x2 = 0
y1 = 0
y2 = 0
r = 0
g = 0
b = 0
xc=0
yc=0
xl=50
yl=20
in = -1
aigdir = -1
aigdev = -1
u = -1
v = -1

DIM p_line[100]
DIM p_line1[100]
DIM p_line2[100]
DIM in_line[100]   % -1=rien 0-95=in 100-147=aigdir 200-247=aigdev 300-395=u 400-495=!u
line_nb = 1
DIM p_rect[100]
DIM in_rect[100]
rect_nb = 1
DIM p_oval[100]
DIM in_oval[100]
oval_nb = 1
DIM xy_cmd[100]    % ind1=x1 ind2=y1 ind3=x2 ind4=y2 ind5=aig(+0=inv,+100=dir,+200=dev)  |  ind1=x1 ...
xy_cmd_nb = 1
list.create s, action_list
action$ = ""
txt$=""

! chaine retour: au0 dcc iFFFFFFFFFFFFFFFFFFFFFFFF dFFFFFFFFFFFF e000000000000 uFFFFFFFFFFFFFFFFFFFFFFFF cYY  --> 91 vrais chars
io_in$ = "550000000000000000000000"   % 24*4bits=96
io_dir$ = "500000000000" %12*4bits=48
io_dev$ = "C00000000000" %12*4bits=48
io_u$  = "550000000000000000000000"   % 24*4bits=96
aig_n   = 0
aig_dir = 0
aig_dev = 0
in_n = 0
in_val = 0
u_n = 0
u_val = 0

msg$ = ""
msg_cmd$ = ""
user_cmd$ = ""

DIM p_rect_tco[5]

tco_sel = 1
old_tco_sel = 1

rx_updated = 0

goto main



!*****************
! TCO   
!*****************

get_in:
    in_v = hex(mid$(io_in$,1+in_n/4,1))  %0-15
    in_m = shift(1,-mod(in_n,4))  %1,2,4,8
    IF(BAND(in_v,in_m)=0) THEN in_val=0 ELSE in_val=1
    return

get_aig_dir:
    aig_v = hex(mid$(io_dir$,1+aig_n/4,1))  %0-15
    aig_m = shift(1,-mod(aig_n,4))  %1,2,4,8
    IF(BAND(aig_v,aig_m)=0) THEN aig_dir=0 ELSE aig_dir=1
    return
    
get_aig_dev:
    aig_v = hex(mid$(io_dev$,1+aig_n/4,1))  %0-15
    aig_m = shift(1,-mod(aig_n,4))  %1,2,4,8
    IF(BAND(aig_v,aig_m)=0) THEN aig_dev=0 ELSE aig_dev=1
    return

get_u:
    u_v = hex(mid$(io_u$,1+u_n/4,1))  %0-15
    u_m = shift(1,-mod(u_n,4))  %1,2,4,8
    IF(BAND(u_v,u_m)=0) THEN u_val=0 ELSE u_val=1
    return

get_val:
    val_res = 0
    IF(num>=0 & num<=95) THEN
        ! entree 0-95
        in_n = num
        GOSUB get_in
        val_res = in_val
    ELSEIF(num>=100 & num<=147) THEN
        ! branche direct d'un aiguillage 100-147
        aig_n = num - 100
        gosub get_aig_dir
        val_res = aig_dir
    ELSEIF(num>=200 & num<=247) THEN
        ! branche deviee d'un aiguillage 200-247
        aig_n = num - 200
        gosub get_aig_dev
        val_res = aig_dev
    ELSEIF(num>=300 & num<=395)
        u_n = num - 300
        gosub get_u
        val_res = u_val
    ELSEIF(num>=400 & num<=495) 
        u_n = num - 400
        gosub get_u
        val_res = 1 - u_val
    ENDIF
    return
    
add_line:
    IF(line_nb = 101) THEN return
    
    GR.COLOR 255, r, g, b, 1 %fill
    GR.line p_line[line_nb], x0+x1, y0+y1, x0+x2, y0+y2
    dy=y1-y2
    IF(dy<0) THEN dy=-dy
    dx=x1-x2
    IF(dx<0) THEN dx=-dx
    IF(dx>dy) THEN
        GR.line p_line1[line_nb], x0+x1, y0+y1-1, x0+x2, y0+y2-1
        GR.line p_line2[line_nb], x0+x1, y0+y1+1, x0+x2, y0+y2+1
    ELSE
        GR.line p_line1[line_nb], x0+x1-1, y0+y1, x0+x2-1, y0+y2
        GR.line p_line2[line_nb], x0+x1+1, y0+y1, x0+x2+1, y0+y2
    ENDIF
    x1=x2
    y1=y2

    num = in    %-1 par defaut
    IF(aigdir<>-1) THEN num = 100 + aigdir
    IF(aigdev<>-1) THEN num = 200 + aigdev
    IF(u<>-1     ) THEN num = 300 + u
    IF(v<>-1     ) THEN num = 400 + v
    in_line[line_nb] = num
    IF(num<>-1) THEN line_nb += 1   %on ne met dans le tableau que les lignes qui changent
    in = -1
    aigdir = -1
    aigdev = -1
    u = -1
    v = -1
    
    return
    
maj_line:
    IF(line_nb=1) THEN return
    FOR i=1 TO line_nb-1
        num = in_line[i]
        IF(num<>-1) THEN    % -1 = fix color
            gosub get_val
            IF(num>=0 & num<=95) THEN
                ! entree 0-95
                IF(val_res) THEN
                    GR.MODIFY p_line[i], "paint", p_paint_seg_occ       
                    GR.MODIFY p_line1[i], "paint", p_paint_seg_occ      
                    GR.MODIFY p_line2[i], "paint", p_paint_seg_occ      
                ELSE
                    GR.MODIFY p_line[i], "paint", p_paint_seg_libre             
                    GR.MODIFY p_line1[i], "paint", p_paint_seg_libre                
                    GR.MODIFY p_line2[i], "paint", p_paint_seg_libre                
                ENDIF       
            ELSEIF(num>=100 & num<=247) THEN
                ! branche direct d'un aiguillage 100-147
                ! branche deviee d'un aiguillage 200-247
                IF(val_res) THEN
                    GR.MODIFY p_line[i], "paint", p_paint_seg_aigok     
                    GR.MODIFY p_line1[i], "paint", p_paint_seg_aigok    
                    GR.MODIFY p_line2[i], "paint", p_paint_seg_aigok
                ELSE                    
                    GR.MODIFY p_line[i], "paint", p_paint_seg_aigko
                    GR.MODIFY p_line1[i], "paint", p_paint_seg_aigko    
                    GR.MODIFY p_line2[i], "paint", p_paint_seg_aigko
                ENDIF
            ELSEIF(num>=300 & num<=495) THEN
                ! variables u/v
                IF(val_res) THEN
                    GR.MODIFY p_line[i], "paint", p_paint_seg_on     
                    GR.MODIFY p_line1[i], "paint", p_paint_seg_on    
                    GR.MODIFY p_line2[i], "paint", p_paint_seg_on
                ELSE                    
                    GR.MODIFY p_line[i], "paint", p_paint_seg_off
                    GR.MODIFY p_line1[i], "paint", p_paint_seg_off    
                    GR.MODIFY p_line2[i], "paint", p_paint_seg_off
                ENDIF				
            ENDIF
        ENDIF
    NEXT i
    return  

add_rect:
    IF(rect_nb = 101) THEN return
    GR.COLOR 255, r, g, b, 1 %fill
    GR.RECT p_rect[rect_nb], x0+xc-xl, y0+yc-yl, x0+xc+xl, y0+yc+yl
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, x0+xc-xl, y0+yc-yl, x0+xc+xl, y0+yc+yl

    num = in    %-1 par defaut
    IF(aigdir<>-1) THEN num=100+aigdir
    IF(aigdev<>-1) THEN num=200+aigdev
    IF(u<>-1)      THEN num=300+u
    IF(v<>-1)      THEN num=400+v
    in_rect[rect_nb] = num
		
    IF(num<>-1) THEN rect_nb += 1
    in = -1
    aigdir = -1
    aigdev = -1
    u = -1
    v = -1
    
    return
    
maj_rect:
    IF(rect_nb=1) THEN return
    FOR i=1 TO rect_nb-1
        num = in_rect[i]
        IF(num<>-1) THEN    % -1 = fix color
            gosub get_val
            IF(num>=0 & num<=95) THEN
                ! entree 0-95
                IF(val_res) THEN
                    GR.MODIFY p_rect[i], "paint", p_paint_rect_occ      
                ELSE
                    GR.MODIFY p_rect[i], "paint", p_paint_rect_libre                
                ENDIF
            ELSEIF(num>=100 & num<=247) THEN
                IF(val_res) THEN
                    GR.MODIFY p_rect[i], "paint", p_paint_rect_aigok       
                ELSE
                    GR.MODIFY p_rect[i], "paint", p_paint_rect_aigko            
                ENDIF           
            ELSEIF(num>=300 & num<=495) THEN
                IF(val_res) THEN
                    GR.MODIFY p_rect[i], "paint", p_paint_rect_on       
                ELSE
                    GR.MODIFY p_rect[i], "paint", p_paint_rect_off            
                ENDIF           
            ENDIF
        ENDIF
    NEXT i
    return  

add_oval:
    IF(oval_nb = 101) THEN return
    GR.COLOR 255, r, g, b, 1 %fill
    GR.OVAL p_oval[oval_nb], x0+xc-xl, y0+yc-yl, x0+xc+xl, y0+yc+yl
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.OVAL p_r, x0+xc-xl, y0+yc-yl, x0+xc+xl, y0+yc+yl

    num = in    %-1 par defaut
    IF(aigdir<>-1) THEN num=100+aigdir
    IF(aigdev<>-1) THEN num=200+aigdev
    IF(u<>-1)      THEN num=300+u
    IF(v<>-1)      THEN num=400+v
    in_oval[oval_nb] = num
    IF(num<>-1) THEN oval_nb += 1
    in = -1
    aigdir = -1
    aigdev = -1
    u = -1
    v = -1
    
    return
    
maj_oval:
    IF(oval_nb=1) THEN return
    FOR i=1 TO oval_nb-1
        num = in_oval[i]
        IF(num<>-1) THEN    % -1 = fix color
            gosub get_val
			IF(num>=0 & num<=95) THEN
                IF(val_res) THEN
                    GR.MODIFY p_oval[i], "paint", p_paint_oval_occ   
                ELSE
                    GR.MODIFY p_oval[i], "paint", p_paint_oval_libre              
                ENDIF
            ELSEIF(num>=100 & num<=247) THEN
                IF(val_res) THEN
                    GR.MODIFY p_oval[i], "paint", p_paint_oval_aigok       
                ELSE
                    GR.MODIFY p_oval[i], "paint", p_paint_oval_aigko            
                ENDIF           
            ELSEIF(num>=300 & num<=495) THEN
                IF(val_res) THEN
                    GR.MODIFY p_oval[i], "paint", p_paint_oval_on       
                ELSE
                    GR.MODIFY p_oval[i], "paint", p_paint_oval_off            
                ENDIF           
			ENDIF
        ENDIF
    NEXT i
    return  

add_txt:
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_txt, x0+xc, y0+yc+10, txt$
    return

add_click:
    IF(xy_cmd_nb=101) THEN return
    xy_cmd[xy_cmd_nb] = x0+xc-xl
    xy_cmd_nb += 1
    xy_cmd[xy_cmd_nb] = y0+yc-yl
    xy_cmd_nb += 1
    xy_cmd[xy_cmd_nb] = x0+xc+xl
    xy_cmd_nb += 1
    xy_cmd[xy_cmd_nb] = y0+yc+yl
    xy_cmd_nb += 1
    !xy_cmd[xy_cmd_nb]=-1
    !IF(aigdev<>-1) THEN xy_cmd[xy_cmd_nb] = 200+aigdev
    !IF(aigdir<>-1) THEN xy_cmd[xy_cmd_nb] = 100+aigdir
    !IF(aiginv<>-1) THEN xy_cmd[xy_cmd_nb] = aiginv
    !aiginv=-1
    !aigdir=-1
    !aigdev=-1
    !xy_cmd_nb += 1
    list.add action_list, action$
	IF(see_click_zone) THEN
        GR.COLOR 255, 255, 0, 255, 0 %border
        GR.RECT p_r, x0+xc-xl, y0+yc-yl, x0+xc+xl, y0+yc+yl
	ENDIF
    return

maj_click:
    msg_cmd$ = ""
	l = 1
    FOR i=1 TO 1000 STEP 4
        IF(i = xy_cmd_nb) THEN return
        x1 = xy_cmd[i]
        x2 = xy_cmd[i+2]
        IF(xclick > x1 & xclick < x2) THEN
            y1 = xy_cmd[i+1]
            y2 = xy_cmd[i+3]
            IF(yclick > y1 & yclick < y2) THEN
                list.get action_list, l, action$
                msg_cmd$ += " " + action$
            ENDIF
        ENDIF
		l += 1
    NEXT i
    return
    
    
    
user_create_tco1:    
    
    x0=15    %changement de l'origine des coordonees
    y0=250
    
    r=0
    g=0
    b=0 
	
	in = -1
	aigdir = -1
	aigdev = -1
	u = -1
	v = -1
    
    !in=0   %premier segment qui change de couleur suivant la valeur de l'entree 0
    x1=0
    y1=0
    x2=100
    y2=0
    gosub add_line
    
    xc=150
    yc=20
    txt$="aig0"
    gosub add_txt
    
    aigdir=0    %second segment qui change de couleur suivant la position de l'aiguillage 0
    x2=200
    y2=0
    gosub add_line

    x2=700
    y2=0
    !in=2   
    gosub add_line
    
    x2=800
    y2=0
    aigdir=3
    gosub add_line
    
    x2=900
    y2=0
    aigdir=2
    gosub add_line

    x2=1000
    y2=0
    !in=5
    gosub add_line
    
    x1=100
    y1=0
    x2=200
    y2=-100
    aigdev=0
    gosub add_line

    x2=800
    y2=-100
    !in=1
    gosub add_line
    
    x2=900
    y2=0
    aigdev=2
    gosub add_line

    x1=400
    y1=100
    x2=700
    y2=100
    !in=3
    gosub add_line

    x2=800
    y2=100
    aigdir=4
    gosub add_line
    
    x2=900
    y2=100
    !in=4
    gosub add_line
    
    x1=700
    y1=100
    x2=750
    y2=50
    aigdev=4
    gosub add_line
    
    x2=800
    y2=0
    aigdev=3
    gosub add_line
    
    
    ! Ajout des voyants de detection (rectangulaire)
    
    xl = 25
    yl = 10
    xc = 50
    yc = 0
    in = 0
    gosub add_rect
    yc += 20
    txt$ = "z0"
    gosub add_txt
    
    xc = 550
    yc = -100
    in = 1
    gosub add_rect

    xc = 550
    yc = 0
    in = 2
    gosub add_rect

    xc = 550
    yc = 100
    in = 3
    gosub add_rect
    
    xc = 850
    yc = 100
    in = 4
    gosub add_oval

    xc = 950
    yc = 0
    in = 5
    gosub add_rect
    
    
    ! Ajout des zones de click des aiguillages
    
    xl = 50
    yl = 50
    xc = 100
    yc = 0
    action$ = "t0^"
    gosub add_click

    xc = 900
    yc = 0
    action$ = "t2^"
    gosub add_click

    xc = 800
    yc = 0
    action$ = "t3^"
    gosub add_click

    xc=700
    yc=100
    action$ = "t4^"
    gosub add_click
    
    return  

user_create_tco2:
    return    
    
user_create_tco3:
    return    

user_create_tco4:
    return    

user_create_tco5:

    x0 = 0
	y0 = 0
    xl = 30
    yl = 30
	
    xc = 50
    yc = 50	
    u = 0
    gosub add_rect
    txt$ = "u0"
    gosub add_txt
    action$ = "u0^"
    gosub add_click

    xc = 50
    yc = 150
    u = 1
    gosub add_rect
    txt$ = "u1"
    gosub add_txt
    action$ = "u1^"
    gosub add_click

    xc = 50
    yc = 250
    u = 2
    gosub add_oval
    txt$ = "u2"
    gosub add_txt
    action$ = "u2^"
    gosub add_click

    xc = 50
    yc = 350
    u = 3
    gosub add_oval
    txt$ = "u3"
    gosub add_txt
    action$ = "u3^"
    gosub add_click

    return    
	

tco_setup:
    ! parametrage du graphique

    !GR.OPEN 255, 0, 0, 0

    ! calcul du zoom a appliquer aux coordonees
    ! Le programme a ete developpe pour fonctionner en 1024x600 paysage
    ! Le zoom adapte l'interface aux autres definitions
    ! en prenant le maximum de place mais sans modifier la geometrie 
    ! orienattion 0=paysage 1=portrait (non conseille: -1=auto 2=paysage_inv 3=portrait_inv)
    hdev = 552
    GR.ORIENTATION 0
    GR.SCREEN w , h
    IF(h > w) THEN PAUSE 1000 %necessaire apres orientation pour laisser le temps a l'ecran de tourner et avoir un w, h correct
    GR.SCREEN w , h
    zoom = h/hdev
    x_m2 = (w/zoom)- 300

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

    ! colors for line
    GR.COLOR 255, 255, 0, 0, 1 %fill     in=1
    GR.PAINT.GET p_paint_seg_occ
    GR.COLOR 255, 0, 0, 0, 1 %fill       in=0
    GR.PAINT.GET p_paint_seg_libre
    GR.COLOR 255, 255, 0, 0, 1 %fill     aigok
    GR.PAINT.GET p_paint_seg_aigok
    GR.COLOR 255, 192, 192, 192, 1 %fill aigko
    GR.PAINT.GET p_paint_seg_aigko
    GR.COLOR 255, 0, 255, 0, 1 %fill    u/vok
    GR.PAINT.GET p_paint_seg_on
    GR.COLOR 255, 64, 64, 64, 1 %fill   u/vko
    GR.PAINT.GET p_paint_seg_off
    
	! colors for rect
    GR.COLOR 255, 255, 0, 0, 1 %fill    in=1
    GR.PAINT.GET p_paint_rect_occ
    GR.COLOR 255, 64, 64, 64, 1 %fill   in=0
    GR.PAINT.GET p_paint_rect_libre
    GR.COLOR 255, 255, 255, 0, 1 %fill  aigok
    GR.PAINT.GET p_paint_rect_aigok
    GR.COLOR 255, 64, 64, 64, 1 %fill   aigko
    GR.PAINT.GET p_paint_rect_aigko
    GR.COLOR 255, 0, 255, 0, 1 %fill    u/vok
    GR.PAINT.GET p_paint_rect_on
    GR.COLOR 255, 64, 64, 64, 1 %fill   u/vko
    GR.PAINT.GET p_paint_rect_off

	! colors for oval
    GR.COLOR 255, 255, 0, 0, 1 %fill    in=1
    GR.PAINT.GET p_paint_oval_occ
    GR.COLOR 255, 64, 64, 64, 1 %fill   in=0
    GR.PAINT.GET p_paint_oval_libre
    GR.COLOR 255, 255, 255, 0, 1 %fill  aigok
    GR.PAINT.GET p_paint_oval_aigok
    GR.COLOR 255, 64, 64, 64, 1 %fill   aigko
    GR.PAINT.GET p_paint_oval_aigko
    GR.COLOR 255, 0, 255, 0, 1 %fill    u/vok
    GR.PAINT.GET p_paint_oval_on
    GR.COLOR 255, 64, 64, 64, 1 %fill   u/vko
    GR.PAINT.GET p_paint_oval_off

    ! Widgets

    ! rectangle zone de fond du TCO
    GR.COLOR 255, 91, 155, 213, 1 %fill
	!GR.COLOR 255, 255, 255, 255, 1 %fill
    GR.RECT p_rectfond, 0, 0, 2900, 470

    ! rectangle zone des options
    GR.COLOR 255, 128, 155, 213, 1 %fill
    GR.RECT p_rectfond, 0, 470, 2900, 600

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
	GR.MODIFY p_rectau, "paint", p_paint_grey
	old_au_red = 0

    ! creation bouton LOC
    b_loc_x = 150
    b_loc_y = 510
    b_loc_x1 = b_loc_x - 30
    b_loc_x2 = b_loc_x + 30
    b_loc_y1 = b_loc_y - 30
    b_loc_y2 = b_loc_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_r, b_loc_x1, b_loc_y1, b_loc_x2, b_loc_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_loc_x1, b_loc_y1, b_loc_x2, b_loc_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_t, b_loc_x, b_loc_y+10, "LOC"

    ! creation des boutons des TCOs 1 a 5
    b_tco1_x = 250
    b_tco1_y = 510
    b_tco1_x1 = b_tco1_x - 30
    b_tco1_x2 = b_tco1_x + 30
    b_tco1_y1 = b_tco1_y - 30
    b_tco1_y2 = b_tco1_y + 30
    FOR i = 1 TO 5
	    IF(i=tco_sel) THEN
		    GR.COLOR 255, 0, 255, 0, 1 %fill
		ELSE
            GR.COLOR 255, 136, 136, 136, 1 %fill
		ENDIF
        GR.RECT p_rect_tco[i], b_tco1_x1 + 100 * (i-1), b_tco1_y1, b_tco1_x2 + 100 * (i-1), b_tco1_y2
        GR.COLOR 255, 0, 0, 0, 0 %border
        GR.RECT p_r, b_tco1_x1 + 100 * (i-1), b_tco1_y1, b_tco1_x2 + 100 * (i-1), b_tco1_y2
        GR.COLOR 255, 0, 0, 0, 1 %fill
        GR.TEXT.DRAW p_t, b_tco1_x + 100 * (i-1), b_tco1_y+10, "TC" + left$(str$(i),1)
    NEXT i

    ! creation bouton MSG
    b_msg_x = 750
    b_msg_y = 510
    b_msg_x1 = b_msg_x - 30
    b_msg_x2 = b_msg_x + 30
    b_msg_y1 = b_msg_y - 30
    b_msg_y2 = b_msg_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_r, b_msg_x1, b_msg_y1, b_msg_x2, b_msg_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_msg_x1, b_msg_y1, b_msg_x2, b_msg_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_t, b_msg_x, b_msg_y+10, "MSG"

    ! creation bouton SCRIPT
    b_scr_x = 850
    b_scr_y = 510
    b_scr_x1 = b_scr_x - 30
    b_scr_x2 = b_scr_x + 30
    b_scr_y1 = b_scr_y - 30
    b_scr_y2 = b_scr_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_rectscr, b_scr_x1, b_scr_y1, b_scr_x2, b_scr_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_scr_x1, b_scr_y1, b_scr_x2, b_scr_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_t, b_scr_x, b_scr_y+10, "SCR"
	old_script_green = 0
    
    return

    
tco_touch:
    old_touched = touched
    GR.TOUCH touched, tx, ty      %attention xscale ne marche pas sur Touch
    tx = tx/zoom
    ty = ty/zoom

    ! APPUI FRONT
    IF(old_touched = 0 & touched = 1) THEN
    
        ! Gestion du bouton AU
        IF(tx >= b_au_x1 & tx <= b_au_x2 & ty > b_au_y1 & ty < b_au_y2) THEN
		    IF(au) THEN au_msg$ = "au0" ELSE au_msg$ = "au1"
			IF(use_net = 0) THEN au = BXOR(au, 1)
        ENDIF
    
        ! Gestion du bouton MSG
        IF(tx > b_msg_x1 & tx < b_msg_x2 & ty > b_msg_y1 & ty < b_msg_y2 ) THEN 
		    !GR.FRONT 0
            input "cmd? l/c/p0-127+-^ o0-47+-^=0-100 s0-47+-^=50-250 a0-47+-/^ x1-511.0-7+-^", user_cmd$
			!GR.FRONT 1
        ENDIF

        ! Gestion du bouton SCR
        IF(tx > b_scr_x1 & tx < b_scr_x2 & ty > b_scr_y1 & ty < b_scr_y2 ) THEN 
		    IF(script_on = 0) THEN 
			    gosub script_start 
			ELSE 
			    gosub script_stop
			ENDIF
        ENDIF
        
        ! Gestion du bouton LOC
        IF(tx > b_loc_x1 & tx < b_loc_x2 & ty > b_loc_y1 & ty < b_loc_y2 ) THEN 
            mode = LOC
        ENDIF   
	
		! un des boutons de selection d'un TCO
        IF(tx > b_tco1_x1 & tx < b_tco1_x2 + 400 & ty > b_tco1_y1 & ty < b_tco1_y2 ) THEN
		    IF(tx > b_tco1_x1     & tx < b_tco1_x2    ) THEN tco_sel	= 1
		    IF(tx > b_tco1_x1+100 & tx < b_tco1_x2+100) THEN tco_sel	= 2
		    IF(tx > b_tco1_x1+200 & tx < b_tco1_x2+200) THEN tco_sel	= 3
		    IF(tx > b_tco1_x1+300 & tx < b_tco1_x2+300) THEN tco_sel	= 4
		    IF(tx > b_tco1_x1+400 & tx < b_tco1_x2+400) THEN tco_sel	= 5            
        ENDIF   

        ! Gestion appuies sur l'ecran du TCO
        xclick = tx
        yclick = ty
        gosub maj_click
		        
    ENDIF

    ! clignotement du bouton AU
    IF(au = 1 & cpt < 4) THEN
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
	
    script_green = script_on
    IF(script_green <> old_script_green) THEN
        old_script_green = script_green
        IF(script_green) THEN 
		    GR.MODIFY p_rectscr, "paint", p_paint_green
	    ELSE
	        GR.MODIFY p_rectscr, "paint", p_paint_grey
		ENDIF
	ENDIF

    return

    
tco_tx:

    IF(use_net = 0) THEN return

	GOSUB all_rx_process_status

	msg$ = ""
    IF(au_msg$   <> "") THEN msg$ += au_msg$
	IF(msg_cmd$  <> "") THEN msg$ += msg_cmd$
	IF(user_cmd$ <> "") THEN msg$ += user_cmd$
	gosub update_ok_to_tx
	IF(ok_to_tx) THEN msg$ += "?"

	IF(msg$ <> "") THEN SOCKET.CLIENT.WRITE.LINE msg$
	
	au_msg$  = ""
    msg_cmd$ = ""
    user_cmd$ = ""
		
    return

    

!*****************
! SOURIS    
!*****************
    
!***************** CREATION DE L'INTERFACE GRAPHIQUE ************************

loc_setup:

    ! parametrage du graphique

    !GR.OPEN 255, 0, 0, 0

    ! calcul du zoom a appliquer aux coordonees
    ! Le programme a ete developpe pour fonctionner en 1024x600 paysage
    ! Le zoom adapte l'interface aux autres definitions
    ! en prenant le maximum de place mais sans modifier la geometrie 
    ! orienattion 0=paysage 1=portrait (non conseille: -1=auto 2=paysage_inv 3=portrait_inv)
    hdev = 552
    GR.ORIENTATION 0
    GR.SCREEN w , h
    IF(h > w) THEN PAUSE 1000 %necessaire apres orientation pour laisser le temps a l'ecran de tourner et avoir un w, h correct
    GR.SCREEN w , h
    zoom = h/hdev
    x_m2 = (w/zoom)- 300

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
    GR.RECT p_rectfond, 0, 0, 2900, 470

    ! rectangle zone des options
    GR.COLOR 255, 128, 155, 213, 1 %fill
    GR.RECT p_rectfond, 0, 470, 2900, 600

    ! rectangle zone des sorties
    GR.COLOR 255, 81, 135, 183, 1 %fill
    GR.RECT p_rectfond, 290, 0, x_m2, 470
        
    ! creation label dcc adr
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW m1_p_txtdccadr, 200, 35, "$" + m1_dcc_adr$
    GR.TEXT.DRAW m2_p_txtdccadr, x_m2+200, 35, "$" + m2_dcc_adr$

    ! creation label cran
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW m1_p_txtvit, 70, 35, "+0%"
    GR.TEXT.DRAW m2_p_txtvit, x_m2+70, 35, "+0%"
        
    ! creation potentiometre
    ! glissiere
    pot_x = 70
    pot_y = 350
    pot_h = 280
    GR.COLOR 255, 192,192, 192, 1 %fill
    GR.RECT p_r, pot_x - 20, pot_y - pot_h, pot_x + 20, pot_y
    GR.RECT p_r, x_m2 + pot_x - 20, pot_y - pot_h, x_m2 + pot_x + 20, pot_y
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, pot_x - 20, pot_y - pot_h, pot_x + 20, pot_y
    GR.RECT p_r, x_m2 + pot_x - 20, pot_y - pot_h, x_m2 + pot_x + 20, pot_y
    ! cursor
    GR.COLOR 255, 255, 0, 0, 1 %fill
    GR.RECT p_rectcursor, pot_x - 50, pot_y - 10, pot_x + 50, pot_y + 10
    GR.RECT m2_p_rectcursor, x_m2 + pot_x - 50, pot_y - 10, x_m2 + pot_x + 50, pot_y + 10
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_rcursor, pot_x - 50, pot_y - 10, pot_x + 50, pot_y + 10
    GR.RECT m2_p_rcursor, x_m2 + pot_x - 50, pot_y - 10, x_m2 + pot_x + 50, pot_y + 10

    ! creation bouton sens
    b_sens_x = 70
    b_sens_y = 430
    b_sens_x1 = b_sens_x - 30
    b_sens_x2 = b_sens_x + 30
    b_sens_y1 = b_sens_y - 30
    b_sens_y2 = b_sens_y + 30
    GR.COLOR 255, 136, 136, 255, 1 %fill
    GR.RECT p_rectsens, b_sens_x1, b_sens_y1, b_sens_x2, b_sens_y2
    GR.RECT m2_p_rectsens, x_m2 + b_sens_x1, b_sens_y1, x_m2 + b_sens_x2, b_sens_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_sens_x1, b_sens_y1, b_sens_x2, b_sens_y2
    GR.RECT p_r, x_m2 + b_sens_x1, b_sens_y1, x_m2 + b_sens_x2, b_sens_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_txtsens, b_sens_x, b_sens_y+10, "+"
    GR.TEXT.DRAW m2_p_txtsens, x_m2 + b_sens_x, b_sens_y+10, "+"

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
	GR.MODIFY p_rectau, "paint", p_paint_grey
	old_au_red = 0
        
    ! creation bouton adr1
    m1_b_adr_x = 150
    m1_b_adr_y = 510
    m1_b_adr_x1 = m1_b_adr_x - 30
    m1_b_adr_x2 = m1_b_adr_x + 30
    m1_b_adr_y1 = m1_b_adr_y - 30
    m1_b_adr_y2 = m1_b_adr_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_r, m1_b_adr_x1, m1_b_adr_y1, m1_b_adr_x2, m1_b_adr_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, m1_b_adr_x1, m1_b_adr_y1, m1_b_adr_x2, m1_b_adr_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_r, m1_b_adr_x, m1_b_adr_y+10, "adr"

    ! creation bouton acc1
    m1_b_acc_x = 250
    m1_b_acc_y = 510
    m1_b_acc_x1 = m1_b_acc_x - 30
    m1_b_acc_x2 = m1_b_acc_x + 30
    m1_b_acc_y1 = m1_b_acc_y - 30
    m1_b_acc_y2 = m1_b_acc_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT m1_p_rectacc, m1_b_acc_x1, m1_b_acc_y1, m1_b_acc_x2, m1_b_acc_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, m1_b_acc_x1, m1_b_acc_y1, m1_b_acc_x2, m1_b_acc_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_r, m1_b_acc_x, m1_b_acc_y+10, "acc"  
        
    ! creation bouton prog
    b_prog_x = 350
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

    ! creation bouton TCO
    b_tco_x = 450
    b_tco_y = 510
    b_tco_x1 = b_tco_x - 30
    b_tco_x2 = b_tco_x + 30
    b_tco_y1 = b_tco_y - 30
    b_tco_y2 = b_tco_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_r, b_tco_x1, b_tco_y1, b_tco_x2, b_tco_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_tco_x1, b_tco_y1, b_tco_x2, b_tco_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_t, b_tco_x, b_tco_y+10, "TCO"
        
    ! creation bouton UM
    b_um_x = x_m2+50
    b_um_y = 510
    b_um_x1 = b_um_x - 30
    b_um_x2 = b_um_x + 30
    b_um_y1 = b_um_y - 30
    b_um_y2 = b_um_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_rectum, b_um_x1, b_um_y1, b_um_x2, b_um_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_um_x1, b_um_y1, b_um_x2, b_um_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_t, b_um_x, b_um_y+10, "UM"   

    ! creation bouton adr2
    m2_b_adr_x = x_m2 + 150
    m2_b_adr_y = 510
    m2_b_adr_x1 = m2_b_adr_x - 30
    m2_b_adr_x2 = m2_b_adr_x + 30
    m2_b_adr_y1 = m2_b_adr_y - 30
    m2_b_adr_y2 = m2_b_adr_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_r, m2_b_adr_x1, m2_b_adr_y1, m2_b_adr_x2, m2_b_adr_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, m2_b_adr_x1, m2_b_adr_y1, m2_b_adr_x2, m2_b_adr_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_r, m2_b_adr_x, m2_b_adr_y+10, "adr"

    ! creation bouton acc2
    m2_b_acc_x = x_m2 + 250
    m2_b_acc_y = 510
    m2_b_acc_x1 = m2_b_acc_x - 30
    m2_b_acc_x2 = m2_b_acc_x + 30
    m2_b_acc_y1 = m2_b_acc_y - 30
    m2_b_acc_y2 = m2_b_acc_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT m2_p_rectacc, m2_b_acc_x1, m2_b_acc_y1, m2_b_acc_x2, m2_b_acc_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, m2_b_acc_x1, m2_b_acc_y1, m2_b_acc_x2, m2_b_acc_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_r, m2_b_acc_x, m2_b_acc_y+10, "acc"  
        
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
    GR.RECT m2_p_rectf0, x_m2 + b_f0_x1, b_f0_y1, x_m2 + b_f0_x2, b_f0_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_f0_x1, b_f0_y1, b_f0_x2, b_f0_y2
    GR.RECT p_r, x_m2 + b_f0_x1, b_f0_y1, x_m2 + b_f0_x2, b_f0_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_r, b_f0_x, b_f0_y+10, "F0"
    GR.TEXT.DRAW p_r, x_m2 + b_f0_x, b_f0_y+10, "F0"
        
    ! F>
    b_fn_x = 170+70
    b_fn_y = 80
    b_fn_x1 = b_fn_x - 30
    b_fn_x2 = b_fn_x + 30
    b_fn_y1 = b_fn_y - 30
    b_fn_y2 = b_fn_y + 30
    GR.COLOR 255, 136, 136, 136, 1 %fill
    GR.RECT p_rectfn, b_fn_x1, b_fn_y1, b_fn_x2, b_fn_y2
    GR.RECT m2_p_rectfn, x_m2 + b_fn_x1, b_fn_y1, x_m2 + b_fn_x2, b_fn_y2
    GR.COLOR 255, 0, 0, 0, 0 %border
    GR.RECT p_r, b_fn_x1, b_fn_y1, b_fn_x2, b_fn_y2
    GR.RECT p_r, x_m2 + b_fn_x1, b_fn_y1, x_m2 + b_fn_x2, b_fn_y2
    GR.COLOR 255, 0, 0, 0, 1 %fill
    GR.TEXT.DRAW p_r, b_fn_x, b_fn_y+10, "F>"
    GR.TEXT.DRAW p_r, x_m2 + b_fn_x, b_fn_y+10, "F>"
        
    ! F1--F10 qui serviront aussi a F11--F20 F21--F30 (F29 & F30 ne sont pas utilises)
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
            GR.RECT m1_p_rectfct[ind], b_f_x1 + b_f_dx * (j-1), b_f_y1 + b_f_dy * (i-1), b_f_x2 + b_f_dx * (j-1), b_f_y2 + b_f_dy * (i-1)
            GR.RECT m2_p_rectfct[ind], x_m2 + b_f_x1 + b_f_dx * (j-1), b_f_y1 + b_f_dy * (i-1), x_m2 + b_f_x2 + b_f_dx * (j-1), b_f_y2 + b_f_dy * (i-1)
            GR.COLOR 255, 0, 0, 0, 0 %border
            GR.RECT p_r, b_f_x1 + b_f_dx * (j-1), b_f_y1 + b_f_dy * (i-1), b_f_x2 + b_f_dx * (j-1), b_f_y2 + b_f_dy * (i-1)
            GR.RECT p_r, x_m2 + b_f_x1 + b_f_dx * (j-1), b_f_y1 + b_f_dy * (i-1), x_m2 + b_f_x2 + b_f_dx * (j-1), b_f_y2 + b_f_dy * (i-1)
            GR.COLOR 255, 0, 0, 0, 1 %fill
            s$ = "F"
            GR.TEXT.DRAW m1_p_txtfct[ind], b_f_x + b_f_dx * (j-1), b_f_y + b_f_dy * (i-1) + 10, s$
            GR.TEXT.DRAW m2_p_txtfct[ind], x_m2 + b_f_x + b_f_dx * (j-1), b_f_y + b_f_dy * (i-1) + 10, s$
            m1_update_fct = 1   %le nom des fonctions sera mise a jour dans la boucle
            m2_update_fct = 1   %le nom des fonctions sera mise a jour dans la boucle
        NEXT i
    NEXT j
                    
    GR.RENDER   %toujours faire render, car RECT ... dessinent en memoire
        
    cpt = 0
    cpt2 = 0

    m1_redraw_pot = 1
    m2_redraw_pot = 1
    m1_redraw_sens = 1
    m2_redraw_sens = 1
	first_aff = 1
    
    return
    
    
!***************** MISE A JOUR L'INTERFACE GRAPHIQUE ************************

loc_touch:

    old_touched = touched
    old_touched2 = touched2
    GR.TOUCH touched, tx, ty      %attention xscale ne marche pas sur Touch
    GR.TOUCH2 touched2, tx2, ty2  %touch2 detecte un eventuel 2eme doigt pratique pour les 2 potentiometres
    tx = tx/zoom
    ty = ty/zoom
    tx2 = tx2/zoom
    ty2 = ty2/zoom
    touch_n = 1
    
    l_touch:    

        ! APPUI CONSTANT
        IF(touched) THEN
            !d_u.continue
      
            ! Gestion du potentiometre 1
            IF(tx >= (pot_x - 50) & tx <= (pot_x + 50) & ty < (pot_y+20)) THEN
                m1_vit = v_range * (pot_y - ty) / pot_h
                m1_redraw_pot = 1
                IF(um) THEN
                    m2_vit = m1_vit
                    m2_redraw_pot = 1
                ENDIF
            ENDIF      
        
            ! Gestion du potentiometre 2
            IF(tx >= x_m2 + (pot_x - 50) & tx <= x_m2 + (pot_x + 50) & ty < (pot_y+20)) THEN
                m2_vit = v_range * (pot_y - ty) / pot_h
                m2_redraw_pot = 1
                IF(um) THEN
                    m1_vit = m2_vit
                    m1_redraw_pot = 1
                ENDIF
            ENDIF      

        ENDIF

        IF(m1_use_acc) THEN
            !Read the acclerometer (en g)
            SENSORS.READ 1,acc_y,acc_x,acc_z
            !PRINT "x=" + str$(acc_x) + " y=" + str$(acc_y) + str$(acc_z)

            IF(orientation = 0) THEN acc = acc_y
            IF(orientation = 1) THEN acc = acc_x
            IF(m1_inv_acc) THEN acc = -acc
        
            IF(acc<-1) THEN m1_sens = 0
            IF(acc>1)  THEN m1_sens = 1
            IF(m1_old_sens <> m1_sens) THEN m1_redraw_sens = 1

            IF(acc<0) THEN acc=-acc
            IF(acc<2) THEN m1_vit=0
            IF(acc>7) THEN m1_vit=v_range
            IF((acc>=2) & (acc<=7)) THEN m1_vit = (v_range * (acc-2)) / 5.0
            IF(m1_old_vit<>m1_vit) THEN m1_redraw_pot = 1       
        ENDIF

        ! ACC 2  -7>-2 STOP 2->7
        IF(m2_use_acc) THEN
            !Read the acclerometer (en g)
            SENSORS.READ 1,acc_y,acc_x,acc_z
            !PRINT "x=" + str$(acc_x) + " y=" + str$(acc_y) + str$(acc_z)

            IF(orientation = 0) THEN acc = acc_y
            IF(orientation = 1) THEN acc = acc_x
            IF(m2_inv_acc) THEN acc = -acc
        
            IF(acc<-1) THEN m2_sens = 0
            IF(acc>1)  THEN m2_sens = 1
            IF(m2_old_sens <> m2_sens) THEN m2_redraw_sens = 1

            IF(acc<0) THEN acc=-acc
            IF(acc<2) THEN m2_vit=0
            IF(acc>7) THEN m2_vit=v_range
            IF((acc>=2) & (acc<=7)) THEN m2_vit = (v_range * (acc-2)) / 5.0
            IF(m2_old_vit<>m2_vit) THEN m2_redraw_pot = 1
        ENDIF

        ! APPUI FRONT
        IF(old_touched = 0 & touched = 1) THEN
    
            ! Gestion du bouton sens
            IF(tx >= b_sens_x1 & tx <= b_sens_x2 & ty > b_sens_y1 & ty < b_sens_y2) THEN
                m1_sens = BXOR(m1_sens, 1)
                m1_redraw_sens = 1
                IF(um) THEN
                    m2_sens = BXOR(m2_sens, 1)
                    m2_redraw_sens = 1
                ENDIF
                IF(m1_use_acc) THEN m1_inv_acc = BXOR(m1_inv_acc, 1)
            ENDIF

            ! Gestion du bouton sens
            IF(tx >= x_m2 + b_sens_x1 & tx <= x_m2 + b_sens_x2 & ty > b_sens_y1 & ty < b_sens_y2) THEN
                m2_sens = BXOR(m2_sens, 1)
                m2_redraw_sens = 1
                IF(um) THEN
                    m1_sens = BXOR(m1_sens, 1)
                    m1_redraw_sens = 1
                ENDIF
                IF(m2_use_acc) THEN m2_inv_acc = BXOR(m2_inv_acc, 1)
            ENDIF
              
            ! Gestion des boutons des fonctions souris 1
        
            ! F0
            IF(tx > b_f0_x1 & tx < b_f0_x2 & ty > b_f0_y1 & ty < b_f0_y2 ) THEN 
                m1_fct0 = BXOR(m1_fct0, 1)
                IF(m1_fct0 = 0) THEN
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
                num = m1_fbase + 5 * col + lgn + 1
                IF(num<=28) THEN
                    m1_fct[num] = BXOR(m1_fct[num], 1)
                    m1_update_fct = 1
                ENDIF
            ENDIF
        
            ! F>
            IF(tx > b_fn_x1 & tx < b_fn_x2 & ty > b_fn_y1 & ty < b_fn_y2 ) THEN
                m1_fbase += 10
                IF(m1_fbase = 30) THEN m1_fbase = 0   % 0,10,20
                m1_update_fct = 1
            ENDIF
                    
            ! Gestion des boutons des fonctions souris 2
        
            ! F0
            IF(tx > x_m2 + b_f0_x1 & tx < x_m2 + b_f0_x2 & ty > b_f0_y1 & ty < b_f0_y2 ) THEN 
                m2_fct0 = BXOR(m2_fct0, 1)
                IF(m2_fct0 = 0) THEN
                    GR.MODIFY m2_p_rectf0, "paint", p_paint_grey 
                ELSE
                    GR.MODIFY m2_p_rectf0, "paint", p_paint_yellow
                ENDIF
            ENDIF
        
            ! F1-F28        
            IF(tx > x_m2 + b_f_x1 & tx < x_m2 + b_f_x2 + 70 & ty > b_f_y1 & ty < b_f_y2 + 4 * 70) THEN
                IF(tx > x_m2 + b_f_x2 + 5) THEN col = 1 ELSE col = 0
                lgn = 0
                IF(ty > b_f_y2 + 5  ) THEN lgn = 1
                IF(ty > b_f_y2 + 75 ) THEN lgn = 2
                IF(ty > b_f_y2 + 145) THEN lgn = 3
                IF(ty > b_f_y2 + 215) THEN lgn = 4
                num = m2_fbase + 5 * col + lgn + 1
                IF(num<=28) THEN
                    m2_fct[num] = BXOR(m2_fct[num], 1)
                    m2_update_fct = 1
                ENDIF
            ENDIF
        
            ! F>
            IF(tx > x_m2 + b_fn_x1 & tx < x_m2 + b_fn_x2 & ty > b_fn_y1 & ty < b_fn_y2 ) THEN
                m2_fbase += 10
                IF(m2_fbase = 30) THEN m2_fbase = 0   % 0,10,20
                m2_update_fct = 1
            ENDIF
    
            ! Gestion du bouton AU
            IF(tx >= b_au_x1 & tx <= b_au_x2 & ty > b_au_y1 & ty < b_au_y2) THEN
		        IF(au) THEN au_msg$ = "au0" ELSE au_msg$ = "au1"
			    IF(use_net = 0) THEN au = BXOR(au, 1)
            ENDIF
        
            ! Gestion du changement d'adresse de locomotive 1
            IF(tx >= m1_b_adr_x1 & tx <= m1_b_adr_x2 & ty > m1_b_adr_y1 & ty < m1_b_adr_y2) THEN
			    old_adr = m1_dcc_adr
                !GR.FRONT 0
                DO
				    !s$ = replace$(format$("###", m1_dcc_adr), " ", "")  %marche pas pour 0
					!IF(m1_dcc_adr = 0) THEN s$ = "0"
					!INPUT "Loco ?", m1_dcc_adr$, s$
					INPUT "Loco ?", m1_dcc_adr$, m1_dcc_adr$
					m1_dcc_adr = val(m1_dcc_adr$)
                    !INPUT "Loco ?", m1_dcc_adr, m1_dcc_adr
                    !IF(m1_dcc_adr >= 10.0) THEN n = 2 ELSE n = 1
                    !m1_dcc_adr$ = left$(str$(m1_dcc_adr), n)    
                UNTIL(m1_dcc_adr >= 0 & m1_dcc_adr <= 99)
				IF(old_adr = 1 & m1_dcc_adr <> 1 & m2_dcc_adr <> 1) THEN
                    INPUT "ATTENTION, PASSAGE DE L'ANALOGIQUE AU DCC. RETIRER LA LOCO ANALOGIQUE !", s$, "OK"
                    !IF(s$ <> "OK¨) THEN m1_dcc_adr = old_adr 					
				ENDIF
				IF(old_adr <> 1 & m1_dcc_adr = 1 & m2_dcc_adr <> 1) THEN
                    INPUT "ATTENTION, PASSAGE DU DCC A L'ANALOGIQUE !", s$, "OK"
				ENDIF
                !GR.FRONT 1
                GR.MODIFY m1_p_txtdccadr, "text", "$" + m1_dcc_adr$
            ENDIF

            ! Gestion du changement d'adresse de locomotive 2
            IF(tx >= m2_b_adr_x1 & tx <= m2_b_adr_x2 & ty > m2_b_adr_y1 & ty < m2_b_adr_y2) THEN
			    old_adr = m2_dcc_adr
                !GR.FRONT 0
                DO
					INPUT "Loco ?", m2_dcc_adr$, m2_dcc_adr$
					m2_dcc_adr = val(m2_dcc_adr$)
                    !INPUT "Loco ?", m2_dcc_adr, m2_dcc_adr
                    !IF(m2_dcc_adr >= 10.0) THEN n = 2 ELSE n = 1
                    !m2_dcc_adr$ = left$(str$(m2_dcc_adr), n)    
                UNTIL(m2_dcc_adr >= 0 & m2_dcc_adr <= 99)
				IF(old_adr = 1 & m2_dcc_adr <> 1 & m1_dcc_adr <> 1) THEN
                    INPUT "ATTENTION, PASSAGE DE L'ANALOGIQUE AU DCC. RETIRER LA LOCO ANALOGIQUE !", s$, "OK"
				ENDIF
				IF(old_adr <> 1 & m2_dcc_adr = 1 & m1_dcc_adr <> 1) THEN
                    INPUT "ATTENTION, PASSAGE DU DCC A L'ANALOGIQUE !", s$, "OK"
				ENDIF
                !GR.FRONT 1
                GR.MODIFY m2_p_txtdccadr, "text", "$" + m2_dcc_adr$
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
                    IF(use_net) THEN SOCKET.CLIENT.WRITE.LINE cmess_prog$

                    !GR.FRONT 1
                ENDIF
            ENDIF
                
            ! Gestion du bouton acc1
            IF(tx >= m1_b_acc_x1 & tx <= m1_b_acc_x2 & ty > m1_b_acc_y1 & ty < m1_b_acc_y2 & um = 0) THEN
                m1_use_acc = BXOR(m1_use_acc, 1)
                IF(m1_use_acc = 0) THEN
                    !SENSORS.CLOSE 1
                    GR.MODIFY m1_p_rectacc, "paint", p_paint_grey 
                ELSE
                    IF(acc_open = 0) THEN
                        SENSORS.OPEN 1
                        acc_open = 1
                    ENDIF
                    GR.MODIFY m1_p_rectacc, "paint", p_paint_green
                ENDIF
            ENDIF

            ! Gestion du bouton acc2
            IF(tx >= m2_b_acc_x1 & tx <= m2_b_acc_x2 & ty > m2_b_acc_y1 & ty < m2_b_acc_y2 & um = 0) THEN
                m2_use_acc = BXOR(m2_use_acc, 1)
                IF(m2_use_acc = 0) THEN
                    !SENSORS.CLOSE 1
                    GR.MODIFY m2_p_rectacc, "paint", p_paint_grey 
                ELSE
                    IF(acc_open = 0) THEN
                        SENSORS.OPEN 1
                        acc_open = 1
                    ENDIF
                    GR.MODIFY m2_p_rectacc, "paint", p_paint_green
                ENDIF
            ENDIF
        
            ! Gestion du bouton UM
            IF(tx > b_um_x1 & tx < b_um_x2 & ty > b_um_y1 & ty < b_um_y2 & m1_use_acc = 0 & m2_use_acc = 0) THEN 
                um = BXOR(um, 1)
                IF(um = 0) THEN
                    GR.MODIFY p_rectum, "paint", p_paint_grey 
                ELSE
                    GR.MODIFY p_rectum, "paint", p_paint_green
                    m2_vit = m1_vit
                    m2_redraw_pot = 1
                ENDIF
            ENDIF
                
            ! Gestion du bouton TCO
            IF(tx > b_tco_x1 & tx < b_tco_x2 & ty > b_tco_y1 & ty < b_tco_y2 ) THEN 
                mode = TCO
            ENDIF
            
        ENDIF 

    ! on refait un tour pour le multi touch
    IF(touch_n = 1) THEN
        touch_n += 1
        tx = tx2
        ty = ty2
        t = touched
        touched = touched2
        touched2 = t
        t = old_touched
        old_touched = old_touched2
        old_touched2 = t
        goto l_touch
    ENDIF   
    t = touched
    touched = touched2
    touched2 = t
    t = old_touched
    old_touched = old_touched2
    old_touched2 = t

    
    IF(m1_redraw_pot) THEN
        m1_redraw_pot = 0
        IF(m1_vit < 0 ) THEN m1_vit=0
        IF(m1_vit > v_range) THEN m1_vit=v_range
        IF(m1_vit >= 10.0) THEN n = 2 else n = 1
        IF(m1_vit >= 100.0) THEN n = 3
        m1_vit$ = left$(str$(m1_vit), n)
        IF(m1_vit = 0) THEN m1_vit$ = "0"
        y = pot_y - pot_h * m1_vit / v_range
        yh = (y - 10)
        yl = (y + 10)
        GR.MODIFY p_rectcursor, "top"   , yh
        GR.MODIFY p_rectcursor, "bottom", yl
        GR.MODIFY p_rcursor   , "top"   , yh
        GR.MODIFY p_rcursor   , "bottom", yl
        IF(m1_sens = 1) THEN vvit$ = "+" ELSE vvit$ = "-"
        vvit$ += m1_vit$ + "%"
        GR.MODIFY m1_p_txtvit    , "text"  , vvit$
    ENDIF

    IF(m2_redraw_pot) THEN
        m2_redraw_pot = 0
        IF(m2_vit < 0 ) THEN m2_vit=0
        IF(m2_vit > v_range) THEN m2_vit=v_range
        IF(m2_vit >= 10.0) THEN n = 2 else n = 1
        IF(m2_vit >= 100.0) THEN n = 3
        m2_vit$ = left$(str$(m2_vit), n)
        IF(m2_vit = 0) THEN m2_vit$ = "0"
        y = pot_y - pot_h * m2_vit / v_range
        yh = (y - 10)
        yl = (y + 10)
        GR.MODIFY m2_p_rectcursor, "top"   , yh
        GR.MODIFY m2_p_rectcursor, "bottom", yl
        GR.MODIFY m2_p_rcursor   , "top"   , yh
        GR.MODIFY m2_p_rcursor   , "bottom", yl
        IF(m2_sens = 1) THEN vvit$ = "+" ELSE vvit$ = "-"
        vvit$ += m2_vit$ + "%"
        GR.MODIFY m2_p_txtvit    , "text"  , vvit$
    ENDIF
    
    IF(m1_redraw_sens) THEN
        m1_redraw_sens = 0
        IF(m1_sens = 1) THEN
            sens$ = "+"
            GR.MODIFY p_rectsens, "paint", p_paint_sens_1
        ELSE
            sens$ = "-"
            GR.MODIFY p_rectsens, "paint", p_paint_sens_0
        ENDIF
        GR.MODIFY p_txtsens, "text", sens$
            
        IF(m1_sens = 1) THEN vvit$ = "+" ELSE vvit$ = "-"
        vvit$ += m1_vit$ + "%"
        GR.MODIFY m1_p_txtvit, "text"  , vvit$
    ENDIF

    IF(m2_redraw_sens) THEN
        m2_redraw_sens = 0
        IF(m2_sens = 1) THEN
            sens$ = "+"
            GR.MODIFY m2_p_rectsens, "paint", p_paint_sens_1
        ELSE
            sens$ = "-"
            GR.MODIFY m2_p_rectsens, "paint", p_paint_sens_0
        ENDIF
        GR.MODIFY m2_p_txtsens, "text", sens$
            
        IF(m2_sens = 1) THEN vvit$ = "+" ELSE vvit$ = "-"
        vvit$ += m2_vit$ + "%"
        GR.MODIFY m2_p_txtvit, "text"  , vvit$
    ENDIF
    
    m1_old_vit = m1_vit
    m2_old_vit = m2_vit
    m1_old_sens = m1_sens
    m2_old_sens = m2_sens

    ! clignotement du bouton AU
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

    ! Gestion de l'affichage des boutons des fonctions 1
    ! en dehors du click pour pouvoir etre utilise par l'init
    IF(m1_update_fct) THEN          
        m1_update_fct = 0
        FOR i = 1 to 10
            num = m1_fbase + i    % 1..10, 11..20, 21..30
            IF(num>=10) THEN s$ = "F" + left$(str$(num),2) ELSE s$ = "F" + left$(str$(num),1)
            IF(num>=29 & num<=30) THEN s$=""
            GR.MODIFY m1_p_txtfct[i], "text", s$
            IF(m1_fct[num] = 0) THEN
                GR.MODIFY m1_p_rectfct[i], "paint", p_paint_grey 
            ELSE
                GR.MODIFY m1_p_rectfct[i], "paint", p_paint_yellow
            ENDIF
        NEXT i          
    ENDIF
    
    ! Gestion de l'affichage des boutons des fonctions 2
    ! en dehors du click pour pouvoir etre utilise par l'init
    IF(m2_update_fct) THEN          
        m2_update_fct = 0
        FOR i = 1 to 10
            num = m2_fbase + i    % 1..10, 11..20, 21..30
            IF(num>=10) THEN s$ = "F" + left$(str$(num),2) ELSE s$ = "F" + left$(str$(num),1)
            IF(num>=29 & num<=30) THEN s$=""
            GR.MODIFY m2_p_txtfct[i], "text", s$
            IF(m2_fct[num] = 0) THEN
                GR.MODIFY m2_p_rectfct[i], "paint", p_paint_grey 
            ELSE
                GR.MODIFY m2_p_rectfct[i], "paint", p_paint_yellow
            ENDIF
        NEXT i          
    ENDIF
	
    IF(first_aff) THEN
	    first_aff = 0
        IF(m1_use_acc = 0) THEN GR.MODIFY m1_p_rectacc, "paint", p_paint_grey 
        IF(m1_use_acc = 1) THEN GR.MODIFY m1_p_rectacc, "paint", p_paint_green
        IF(m2_use_acc = 0) THEN GR.MODIFY m2_p_rectacc, "paint", p_paint_grey 
        IF(m2_use_acc = 1) THEN GR.MODIFY m2_p_rectacc, "paint", p_paint_green
		IF(um = 0) THEN GR.MODIFY p_rectum, "paint", p_paint_grey 
        IF(um = 1) THEN GR.MODIFY p_rectum, "paint", p_paint_green
    ENDIF	
        
    return
    
    
!***************** TRANSMISSION DE LA COMMANDE ************************

loc_tx:

    !ex de cmd: cmess$ = "a3 au0 s+ v25 f0+f1-f2-f3-f4-f5-f6-f7-f8- o5-"
    !toutes les fct d'une page sont transmises, seulement les sorties qui changent sont transmises
            
    m1_cmess$ = "a"
    m1_cmess$ += m1_dcc_adr$
        
    m1_cmess$ += " v"
    m1_cmess$ += m1_vit$
    
    IF(m1_sens = 1) THEN
        m1_cmess$ += " s+"
    ELSE
        m1_cmess$ += " s-"
    ENDIF
    
    m1_cmess$ += " f0"
    IF(m1_fct0 = 0) THEN
        m1_cmess$ += "-"
    ELSE
        m1_cmess$ += "+"
    ENDIF

    FOR i = 1 TO 10        % envoie seulement la base active
        num = m1_fbase + i    % 1..10,11..20,21..28
        IF(num<=28) THEN
            IF(i = 1) THEN    %optimisation f1+f2-f3+f4+f5+f6+f7-f8-f9-f10+ --> f1+-++++---+
                IF(num>=10) THEN
                    m1_cmess$ += "f" + left$(str$(num),2)
                ELSE
                    m1_cmess$ += "f" + left$(str$(num),1)
                ENDIF
            ENDIF
            IF(m1_fct[num] = 0) THEN
                m1_cmess$ += "-"
            ELSE
                m1_cmess$ += "+"
            ENDIF
        ENDIF
    NEXT i

    m2_cmess$ = "b"
    m2_cmess$ += m2_dcc_adr$
        
    m2_cmess$ += " v"
    m2_cmess$ += m2_vit$
    
    IF(m2_sens = 1) THEN
        m2_cmess$ += " s+"
    ELSE
        m2_cmess$ += " s-"
    ENDIF
    
    m2_cmess$ += " f0"
    IF(m2_fct0 = 0) THEN
        m2_cmess$ += "-"
    ELSE
        m2_cmess$ += "+"
    ENDIF
    FOR i = 1 TO 10        % envoie seulement la base active
        num = m2_fbase + i    % 1..10,11..20,21..28
        IF(num<=28) THEN
            IF(i = 1) THEN    %optimisation f1+f2-f3+f4+f5+f6+f7-f8-f9-f10+ --> f1+-++++---+
                IF(num>=10) THEN
                    m2_cmess$ += "f" + left$(str$(num),2)
                ELSE
                    m2_cmess$ += "f" + left$(str$(num),1)
                ENDIF
            ENDIF
            IF(m2_fct[num] = 0) THEN
                m2_cmess$ += "-"
            ELSE
                m2_cmess$ += "+"
            ENDIF
        ENDIF
    NEXT i

    cmess$ = ""
        
    ttx = 0
	
	IF(au_msg$ <> "") THEN
	    cmess$ = cmess$ + au_msg$ + " "
		au_msg$ = ""
        ttx = 1
	ENDIF
	
	IF(ask_status) THEN
    	gosub update_ok_to_tx
	    IF(ok_to_tx) THEN
	        cmess$ += "? "
            ttx = 1	
		ENDIF
	ENDIF
		
    IF(m1_cmess$ <> m1_old_cmess$) THEN
        cmess$ = cmess$ + m1_cmess$ + " "
        ttx = 1
    ENDIF
            
    IF(m2_cmess$ <> m2_old_cmess$) THEN
        cmess$ = cmess$ + m2_cmess$ +  " "
        ttx = 1
    ENDIF
       
    IF(ttx) THEN
        ttx = 0
        
        !GR.FRONT 0
        !PRINT cmess$
        !PAUSE 2000
        !GR.FRONT 1
        !GR.RENDER
        IF(use_net) THEN SOCKET.CLIENT.WRITE.LINE cmess$
            
        m0_old_cmess$ = m0_cmess$
        m1_old_cmess$ = m1_cmess$
        m2_old_cmess$ = m2_cmess$           
    ENDIF
    
    return


!***************** SCRIPT ************************

script_start:
    IF(script_on = 1) THEN return
	
	! choix du fichier
	array.delete d1$[]
	file.dir "",d1$[]
	select s,d1$[],""
	filename$ = d1$[s]
	
	! edition du fichier (peu etre commente)
	grabfile d$, filename$
	text.input d$,d$
	text.open w,pf,filename$
	text.writeln pf, d$
	text.close pf
	
	!pas de return car on continue

script_restart:	
    ! ouvrir le fichier
	! TEXT.OPEN R, pf, "script.txt"
	TEXT.OPEN R, pf, filename$
	IF(pf = -1) THEN return
	
    ! init des variables	
    script_tempo    = 0
    script_wait_in  = -1
    script_wait_u   = -1
    script_wait_val = 1
    script_on       = 1
	return

script_stop:
    IF(script_on = 0) THEN return
    script_on = 0
	TEXT.CLOSE pf
	return
	

script_update:
   
    IF(script_on = 0) THEN return
	
    IF(script_tempo > 0) THEN
	   IF((clock() - script_clock) < script_tempo) THEN return
	   script_tempo = 0
    ENDIF	
	
	IF(script_wait_in<>-1) THEN
        in_n = script_wait_in
        GOSUB get_in
        IF(in_val<>script_wait_val) THEN return
	ENDIF

	IF(script_wait_u<>-1) THEN
        u_n = script_wait_u
        gosub get_u
        GOSUB get_in
        IF(u_val<>script_wait_val) THEN return
	ENDIF

	cont = 1
	DO
	
        TEXT.READLN pf, script_line$
	    script_cmd$ = upper$(script_line$) 
	
	    IF(script_cmd$ = "EOF") THEN
	        gosub script_stop
			cont = 0
	    ENDIF	
	
		IF(script_cmd$ = "") THEN d_u.continue
		
		script_cmd$ = word$(script_cmd$,1)
		
		IF(script_cmd$ = "END") THEN
	        gosub script_stop
			cont = 0
	    ENDIF	
	
	    IF(script_cmd$ = "LOOP") THEN
	        gosub script_stop
	        gosub script_restart
			cont = 0
	    ENDIF	
	
	    IF(script_cmd$ = "TEMPO") THEN
		    script_tempo = 1000 * val(word$(script_line$,2))  %en ms
		    script_clock = clock()		
			cont = 0
	    ENDIF	
	
	    IF(script_cmd$ = "TEMPOR") THEN
	        script_val1 = val(word$(script_line$,2))
	        script_val2 = val(word$(script_line$,3))
		    script_tempo = script_val1 + (script_val2 - script_val1) * rnd()
		    script_tempo = 1000 * script_tempo
		    script_clock = clock()		
			cont = 0
	    ENDIF	
	
	    IF(script_cmd$ = "WAITIN") THEN
    	    script_wait_in = val(word$(script_line$,2))
	    	script_wait_val = 1
			cont = 0
    	ENDIF	
	
	    IF(script_cmd$ = "WAITNOTIN") THEN
    	    script_wait_in = val(word$(script_line$,2))
	    	script_wait_val = 0
			cont = 0
	    ENDIF	
	
    	IF(script_cmd$ = "WAITU") THEN
	        script_wait_u = val(word$(script_line$,2))
    		script_wait_val = 1
			cont = 0
	    ENDIF	
	
    	IF(script_cmd$ = "WAITNOTU") THEN
	        script_wait_u = val(word$(script_line$,2))
    		script_wait_val = 0
			cont = 0
	    ENDIF	
	
    	IF(script_cmd$ = "CMD") THEN
	        script_msg$ = word$(script_line$,2)
		    IF(use_net) THEN SOCKET.CLIENT.WRITE.LINE script_msg$
			cont = 1
	    ENDIF	

    	IF(script_cmd$ = "MSG") THEN
	        script_val$ = word$(script_line$,2)
		    POPUP script_val$,0,0,0
			cont = 1
	    ENDIF	
		
	UNTIL(cont = 0)
	
	return


	
!***************** MAIN ************************

update_ok_to_tx:
    ok_to_tx = 0
    IF(rxed) THEN
	    rxed = 0
		ok_to_tx = 1
	ELSE
	    IF((clock() - rxclock)>1000) THEN ok_to_tx = 1
		rxclock = clock() 
	ENDIF
		
    return

! all_rx_process_status recoit les status de la centrale et met a jour les diferentes valeurs
!
! chaine retour: au0 dcc iFFFFFFFFFFFFFFFFFFFFFFFF dFFFFFFFFFFFF e000000000000 uFFFFFFFFFFFFFFFFFFFFFFFF cyy
!                1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901
!                0        1         2         3         4         5         6         7         8         9
all_rx_process_status:	
    IF(use_net = 0) THEN return
	
	DO
        SOCKET.CLIENT.READ.READY flag
        IF(flag <> 0) THEN
            SOCKET.CLIENT.READ.LINE msg$
            IF(len(msg$) >= 91) THEN
                IF(mid$(msg$,1,3)  = "au1") THEN au  = 1
    		    IF(mid$(msg$,1,3)  = "au0") THEN au  = 0
	    	    IF(mid$(msg$,5,3)  = "dcc") THEN ana = 0
		        IF(mid$(msg$,5,3)  = "ana") THEN ana = 1
                IF(mid$(msg$,9,1)  = "i"  ) THEN io_in$  = mid$(msg$,10,24)
                IF(mid$(msg$,35,1) = "d"  ) THEN io_dir$ = mid$(msg$,36,12)
                IF(mid$(msg$,49,1) = "e"  ) THEN io_dev$ = mid$(msg$,50,12)                       
                IF(mid$(msg$,63,1) = "u"  ) THEN io_u$   = mid$(msg$,64,24)                       
    		    IF(mid$(msg$,89,1) = "c"  ) THEN
	    		    can$ = mid$(msg$,90,2)                       
		    		can = val(can$)
                ENDIF					
    			rx_updated = 1
				rxed = 1
				rxclock = clock()
			ENDIF
        ENDIF
    UNTIL(flag = 0)
    
    return

main:
    GR.OPEN 255, 0, 0, 0

    DO
        IF(mode = LOC) THEN
        
            gosub loc_setup
            
            WHILE(mode = LOC)
            
                ! on teste les appuis toutes les 50ms ou 33ms pour avoir une interface reactive
                pause 33
                gosub loc_touch

				! on recoit opportunement
                GOSUB all_rx_process_status
				
		        ! on transmet une fois toutes les 100ms (s'il y a du changement)
		        ! on demande le status une fois toute les 200ms
                cpt2 += 1
                IF(cpt2 >= 3) THEN   %on transmettre une fois/3 (toutes les 100ms)
                    cpt2 = 0
      				ask_status = BXOR(ask_status, 1)
                    GOSUB loc_tx
                ENDIF

				! compteur pout faire clignoter le bouton d'AU
                cpt += 1
                IF(cpt >= 10) THEN cpt = 0
				
				! mise a jour du script
				gosub script_update
				
                GR.RENDER
                
            REPEAT
            
            GR.CLS
            
        ENDIF

        IF(mode = TCO) THEN
    
            gosub tco_setup

            line_nb = 1
            rect_nb = 1
            oval_nb = 1
            xy_cmd_nb = 1
            list.clear action_list
			old_tco_sel = tco_sel

            IF(tco_sel = 1) THEN gosub user_create_tco1
            IF(tco_sel = 2) THEN gosub user_create_tco2
            IF(tco_sel = 3) THEN gosub user_create_tco3
            IF(tco_sel = 4) THEN gosub user_create_tco4
            IF(tco_sel = 5) THEN gosub user_create_tco5
            gosub maj_line
            gosub maj_rect
            gosub maj_oval
            GR.RENDER
            
            WHILE(mode = TCO & tco_sel = old_tco_sel)
							
                ! on teste les clicks toutes les 50ms sinon pas assez fluide
				pause 50
                GOSUB tco_touch

				! on recoit opportunement
			    GOSUB all_rx_process_status
				
				! on update si changement
				IF(rx_updated) THEN
				    rx_updated = 0
                    gosub maj_line
                    gosub maj_rect
                    gosub maj_oval
				ENDIF

		        ! on transmet une fois toutes les 200ms (surtout pour demander le status)
                cpt2 += 1
                IF(cpt2 >= 4) THEN
                    cpt2 = 0
                    GOSUB tco_tx
                ENDIF
				
				! compteur pout faire clignoter le bouton d'AU
				cpt += 1
                IF(cpt >= 8) THEN cpt = 0
            
				! mise a jour du script
				gosub script_update

                GR.RENDER
				
            REPEAT

            GR.CLS
            
        ENDIF
        
    UNTIL(0)
