/*
    Centrale D17

    Cette centrale DCC genere:
    - un signal DCC pour conduire ou programmer des locomotives numeriques
    - ou un signal PWM (+sens) pour une locomotive analogique
    La centrale pilote aussi des IO
    - en sortie: aiguillages, led, sorties, pwm, servos, decodeurs d'accessoires basiques et etendus
    - en entree: entrees numeriques d'un bus S88, et courant du booster
    Les ordres sont transmis par des clients TCP/IP qui se connectent via le Wifi integre.

    historique:
    - 2017/02/13: Ulysse Delmas-Begue  Ajout du choix de la polarite du bouton d'arret d'urgence
                                       Memorisation des entrees pour chaque souris afin de ne pas manquer les contacts fugitifs comme les ILS tres utile pour le mode script)
                                       Limitation a une seule reponse de demande de status par souris et par boucle (afin de ne pas surcharger le wifi)
                                       Choix de la commande des decodeurs d'accessoires en DCC (interdir, ok mais avec booster inactif, OK avec booster actif) 
    - 2017/02/08: Ulysse Delmas-Begue  Ajout de la rotation lente des servos
    - 2018/02/07  Ulysse Delmas-Begue  Ajout du mode 126 crans en DCC. Vous pouvez choisir entre le mode 28 crans ou 126 crans (28 crans par defaut)
                                       Ajout d'un facteur pour diminuer la plage PWM en analogique si vous utilisez une alim > 12V
    - 2018/01/31  Ulysse Delmas-Begue  Passage de la resolution des tempos de 20ms a 250ms car on ne pouvait pas tenir cette resolution et les pca/led ne sont mis a jour que toute les 250ms
                                       La mise a jour des pca9685 est maintenant faite uniquement toute les 250ms (et seulement sur les canaux necessaires)
                                       Ajout d'un bit 0 au signal dcc lorsque la boucle peut prendre trop de temps afin de rester dans les tolerances de la norme DCC (bit0 = 10ms max par état, 12ms au total)
    - 2018/01/29  Ulysse Delmas-Begue  Ajout du bouton d'arrêt d'urgence sur D5
                                       Retrait temporaire de la variation lente des servos
    - 2018/01/22  Ulysse Delmas-Begue  Ajout de la commande u
                                       Ajout a l'etat des variables u
                                       Ajout de l'environement user de D18 
                                       Optimisation de la transmission des fonctions auxiliaires f1+f2-f3+... -> f1+-+ 
    - 2018/01/21  Ulysse Delmas-Begue  Rajout de la commande des decodeurs d'accessoires etendus 
    - 2018/01/18  Ulysse Delmas-Begue  Test avec le decodeur d'accessories D18  
    - 2018/01/07  Ulysse Delmas-Begue  Test avec TCO sur tablette pour in et aig ok    
    - 2018/01/06  Ulysse Delmas-Begue  La LED "sign of life" peut etre dispo maintenant sur le max
                                       Rajout de la commande des decodeurs d'accessoirs basiques
                                       Ajout d'une commande pour identifier la centrale
    - 2018/01/05  Ulysse Delmas-Begue  Passage a 96entrees, 128leds, 48srv/pwm
                                       Rajout de la commande des leds/srv/pwm par wifi
                                       Rajout variation lente des servos
    - 2017/12/29  Ulysse Delmas-Begue  Ajout des fonctions F13-F28
                                       Ajout des packets de 3bytes DCC (en plus du preambule et checksum)
                                       Ajout de la commande des decodeurs d'accesoires DCC 
    - 2017/12/27  Ulysse Delmas-Begue  Passage de 0-28 crans a 0-100% pour les souris
                                       Ajout des fonctions F5-F12 (elle ne sont transmises que lorsque necessaire pour ne pas perdre de la bande passante)
                                       Ajout d'un second canal dcc pour chaque souris pr piloter 2 locos simultanees par souris
    - 2017/12/26  Ulysse Delmas-Begue  Ajout de l'I2C afin de proposer 16 PWM ou SRV par PCA9685 (16)
                                       Ajout du S88 (64)
    - 2017/12/24  Ulysse Delmas-Begue  Ajout des leds (64)
    - 2017/12/23  Ulysse Delmas-Begue  Ajout programation des CV
    - 2017/12/22  Ulysse Delmas-Begue  Ajout (temporaire) de 6 sorties controlees par le wifi
    - 2017/12/21  Ulysse Delmas-Begue  Correctif la centrale ne plante plus en DCC
                                       Gere les passages entre DCC et ANA.                                  
                                       Ajout de la mesure du courant
    - 2017/12/16  Ulysse Delmas-Begue  Genere un signal PWM pour une locomotive ANAlogique en fonction d'une souris wifi    
                                       Passage de 1kHz a 20KHz afin de rendre la PWM inaudible
    - 2017/06/27  Ulysse Delmas-Begue  Creation: Genere un signal DCC en fonction de 4 souris wifi max 

    a faire:
    - ajouter sur tablette appli de test pour servo, pwm, led, in, aig, acc   <-- erzast pour l'instant avec msg
    - ajouter gestion des aiguillage  <-- erzast pour l'instant
    - souris 1 changer les boutons
    - ID a la connection IP
    - voir si possible 5 souris

    a voire ???:
    - passage de l'adresse loco en 16bits ? --> NON pas d'interet
    - ajout d'itineraires           <-- erzast pour l'instant
    - gestion de la signalisation   <-- erzast pour l'instant
    - gestion de l'automatisation   <-- erzast pour l'instant
    - ajout d'un protocol sur USB pour connection (FDCC, DCC++ ...)  <-- plus tard
    - voir si on passe la boucle de 250ms à 125ms comme sur le D18  <-- pas pour l'instant, necessaire de faire des tests de perf avant
    - voir, si on met plus de leds et pca comme sur le D18
    - voir si on met plus d'entrees

    bugs
    - aucun

    notes:
    - La centrale demarre en AU avec le booster desactive
    - Si une souris utilise l'adrresse 1, la centrale passe en mode analogique ANA (PWM)
    - Si aucune souris n'utilise l'adresse 1, la centrale passe en mode DCC
    - Si le mode (DCC ou ANA) n'est pas autorise, la centrale passe quand meme dans ce mode mais se met en AU 
    - Pour inactiver une souris, selectionner l'adresse 0 ou deconnectez la du wifi 
    - Le programme ne doit pas bloquer la stack wifi pendant plus de 50ms (ajouter yield(0); or delay(0);)
    
        From: https://github.com/adafruit/ESP8266-Arduino
        Remember that there is a lot of code that needs to run on the chip besides the sketch when WiFi is connected.
        WiFi and TCP/IP libraries get a chance to handle any pending events each time the loop() function completes, OR when delay(...) is called.
        If you have a loop somewhere in your sketch that takes a lot of time (>50ms) without calling delay(),
        you might consider adding a call to delay function to keep the WiFi stack running smoothly.
        There is also a yield() function which is equivalent to delay(0).
        The delayMicroseconds function, on the other hand, does not yield to other tasks, so using it for delays more than 20 milliseconds is not recommended.

    pins:
                    RST #### TX
          SENCE -->  A0 #### RX
  DIN+DOUT/OUT1 <--  D0 #### D1  --> OUT0/LDIN
 AU + CLK /OUT2 <--  D5 #### D2  --> EN  +PWM
      SDA /OUT3 <--  D6 #### D3  --> DCC +SENS             (PU)
      SCK /OUT4 <--  D7 #### D4  --> LED (on board) / LLED (PU)
(PD) RSTIN/OUT5 <--  D8 #### GND
                   3.3V #### 5V

    gpio ds la datasheet de l'esp 8266
    - D0=GPIO16 / D1=GPIO5  / D2=GPIO4  / D3=GPIO0
    - D4=GPIO2  / D5=GPIO14 / D6=GPIO12 / D7=GPIO13
    - D8=GPIO15 / D9=GPIO3  / D1=GPIO1  / A0=NA

    durees des mises a jours:
    - in: 96bits @ 50us            -> 4.8ms
    - led: 2*8*16 = 256bits @ 10us -> 2.5ms
    - pca: 6*10bits @ 10us -> 0.6ms /ch
    - pca: 48* 0.6                 -> 29ms
    TOTAL: 36ms / 250ms

*/


#include <ESP8266WiFi.h>



//==============================================================================================
//     USER PART
//==============================================================================================

//--------------------------------------------------------------------------------
// Constantes utilisateur (vous pouvez changer ces valeurs)
//----------------------------------------------------------------------------------

// Acces point configuration
const char AP_name[] = "D17-0001";
const char AP_pass[] = "ulysse31";

// Server configuration
int tcp_port = 1234;

// CV programmation code
#define CV_PROG_CODE 1234

// PIN assignation
#define USER_USE_S88  0     // 1 to use S88 IN     (out D0, D5, D1, D8 no more available)
#define USER_USE_MAX  0     // 1 to use MAX7219/21 (out D0, D5, D4     no more available)
#define USER_USE_PCA  0     // 1 to use PCA9685    (out D6, D7         no more available)
#define USER_CLI_LED_MAX -1 // indicate which LED of MAX should blink to indicate sign of life (-1 not used) 
#define USER_USE_AU   0     // 1 to use AU button on pin D5 (it can be used in // with S88, MAX, OUT) (very small glitch with OUT). Read the doc because 2 resistors must be used !
#define USER_AU_LEVEL 0     // 0 AU actif a l'etat bas, 1 AU actif a l'etat haut

// speed mode
#define USER_USE_126_CRANS 0  // 0 to use 28 crans, 1 to use 126 crans
#define USER_PWM_FACTOR 100   // Plage d'utilisation de la pwm pour les locos analogiques (en %) 
                              // afin de reduire la tension moyenne max si si l'alim > 12V. 
                              // (ex: 12V * 100% = 12V, 15V * 80% = 12V, 18V * 67% = 12V)

// dcc & analog modes                              
#define USER_DCC_OK  1        // 0 ne jamais utiliser le DCC, 1 ok pour utiliser le DCC
#define USER_ANA_OK  1        // 0 ne jamais utiliser l'analogique, 1 ok pour utilise l'analogique   
#define USER_ACC_ANA 2        // commande des accessoires en analogique: 0 ne pas commander, 1 commander sans le booster, 2 commander avec le booster                      

// Version de la centrale
#define CENTRAL_NAME "D17 v20180213a"



//--------------------------------------------------------------------------------
// Code utilisateur (vous pouvez ajouter la gestion des accessoires
//----------------------------------------------------------------------------------

// functions available for user
void user_out(byte num, byte val);
void user_led(byte num, byte val);
void user_led_cli(byte num, byte val);
void user_led_pha(byte num, byte val);
void user_pwm_0_100(byte num, byte val);
void user_servo_500_2500(byte num, unsigned int val);
void user_servo_speed(byte num, byte speed);  //delta pulse us / 250ms 
void user_tempo_start(byte num_tempo, unsigned int duration_ms);
void user_bas_acc_dec_tx(unsigned adr, byte out, byte val);
void user_ext_acc_dec_tx(unsigned adr, byte val);
void user_set_d_e(byte num, byte val_d, byte val_e);
void user_set_u(byte num, byte val);
byte user_get_u(byte num);
byte user_get_in(byte num);

// User defines

// User functions
void user_init(void)
{
     /*
     user_led_cli( 0,1);
     user_led_cli( 7,1); user_led_pha(7,1);
     user_led_cli(56,1); user_led_pha(56,1);
     user_led_cli(63,1);

     user_pwm_0_100( 0,   0);
     user_pwm_0_100( 1,  10);
     user_pwm_0_100( 2,  25);
     user_pwm_0_100( 3,  50);
     user_pwm_0_100( 4,  50);
     user_pwm_0_100( 5,  75);
     user_pwm_0_100( 6,  90);
     user_pwm_0_100( 7, 100);

     user_servo_500_2500( 8,  500);
     user_servo_500_2500( 9,  750);
     user_servo_500_2500(10, 1000);
     user_servo_500_2500(11, 1500);
     user_servo_500_2500(12, 1500);
     user_servo_500_2500(13, 2000);
     user_servo_500_2500(14, 2250);
     user_servo_500_2500(15, 2500);
     */
}


void user_notify_u(byte num, byte val)
{
     /*
     if(num==0) user_led(0,val);
     if(num==1) user_led(7,val);
     if(num==2) user_led(56,val);
     if(num==3) user_led(63,val);
     */
     
     user_set_u(num, val);
}


void user_notify_aig(byte num, byte cmd) // cmd=0=direct cmd=1=devie
{
    user_set_d_e(num, 1 - cmd, cmd);
}


void user_notify_tempo_end(byte num_tempo)
{
}


void user_250ms()
{
}



//==============================================================================================
//     END of USER PART
//==============================================================================================



//--------------------------------------------------------------------------------
// Constantes system
//----------------------------------------------------------------------------------

// Server configuration
#define MAX_CLIENTS 4

// Analog Address
#define ADR_ANA 1

// Booster modes
#define BOOST_DCC 0
#define BOOST_ANA 1

// pins
#define S_PIN D3
#define P_PIN D2
#define DCC_PIN S_PIN

#define LED_PIN LED_BUILTIN //D4

#define CLK_PIN  D5
#define DAT_PIN  D0
#define LLED_PIN D4
#define LDIN_PIN D1 
#define RST_PIN  D8
#define SCK_PIN  D7
#define SDA_PIN  D6

#define AU_PIN   D5   //can be used in // of CLK_PIN & OUT PIN (with small glitch for OUT)



//------------------------------------------------------------------------------
// DIRECT OUT (7)
//------------------------------------------------------------------------------

void user_out(byte num, byte val)
{                  
    if(val == 1) val = HIGH; else val = LOW;
#if USER_USE_PCA == 0
            if(num == SDA_PIN) digitalWrite(SDA_PIN, val); //pin6
            if(num == SCK_PIN) digitalWrite(SCK_PIN, val); //pin7
#endif
#if USER_USE_S88 == 0
            if(num == LDIN_PIN) digitalWrite(LDIN_PIN, val); //pin1
            if(num == RST_PIN) digitalWrite(RST_PIN, val); //pin8
#endif
#if USER_USE_MAX == 0
    #if USER_USE_PCA == 0
            if(num == DAT_PIN) digitalWrite(DAT_PIN, val); //pin0
            if(num == CLK_PIN) digitalWrite(CLK_PIN, val); //pin5
    #endif
#endif          
}



//------------------------------------------------------------------------------
// S88 (96)
//------------------------------------------------------------------------------

#define IO_IN_NB 96

byte io_in[IO_IN_NB / 8];     // 96 entrees
byte io_inmem[4][IO_IN_NB / 8];  // memorisation des entrees pour chaque souris

// utilisation de 25us sur S88 soit une periode de 50us et une frequence de 20kHz
// Cette basse frequence permet de fonctionner avec des uc qui emulent lentement le S88 au lieu des 4014/2021  
// Duree totale theorique pour 96 entrees: 4.8ms
byte in_shift8(void)
{
    byte i, dat;

    //pinMode(DAT_PIN, INPUT);
    
    for(i = 0; i < 8; i++)
    {
        dat = dat >> 1;
        if(digitalRead(DAT_PIN) == HIGH) dat |= 0x80; else dat &= 0x7f;
        digitalWrite(CLK_PIN, HIGH); delayMicroseconds(25); digitalWrite(CLK_PIN, LOW); delayMicroseconds(25);
    }
    return dat;    
}


void s88_maj(void)
{
    byte i, v;

    pinMode(DAT_PIN, INPUT);
    
    digitalWrite(CLK_PIN , LOW ); delayMicroseconds(25);  //mise a 0 car utilisee par d'autres fonctions qui peuvent l'avoir mise a 1
    digitalWrite(LDIN_PIN, HIGH); delayMicroseconds(25);
    digitalWrite(CLK_PIN , HIGH); delayMicroseconds(25);
    digitalWrite(CLK_PIN , LOW ); delayMicroseconds(25);
    digitalWrite(LDIN_PIN, LOW ); delayMicroseconds(25);
    digitalWrite(RST_PIN , HIGH); delayMicroseconds(25);
    digitalWrite(RST_PIN , LOW ); delayMicroseconds(25);
    
    for(i = 0; i < (IO_IN_NB / 8); i++)
    {
        v = in_shift8();
        io_in[i] = v;
        io_inmem[0][i] |= v;
        io_inmem[1][i] |= v;
        io_inmem[2][i] |= v;
        io_inmem[3][i] |= v;
        yield();
    } 
}


void s88_init(void)
{
    byte i;
      
    for(i = 0; i < (IO_IN_NB / 8);i++)
    {
        io_in[i] = io_inmem[0][i] = io_inmem[1][i] = io_inmem[2][i] = io_inmem[3][i] = 0;
    }      
}


byte user_get_in(byte num)
{
    if(num < IO_IN_NB) if(io_in[num / 8] & 1 << (num & 7)) return 1;

    return 0;    
}



//--------------------------------------------------------------------------------
// Leds (128)
//----------------------------------------------------------------------------------

#define IO_LED_NB 128

byte io_led[IO_LED_NB / 8] = { 0, 0, 0, 0 ,0, 0, 0, 0,    0, 0, 0, 0 ,0, 0, 0, 0 };  // possibilite d'initialiser les valeurs
byte io_cli[IO_LED_NB / 8] = { 0, 0, 0, 0 ,0, 0, 0, 0,    0, 0, 0, 0 ,0, 0, 0, 0 };  // ex led clignotante
byte io_pha[IO_LED_NB / 8] = { 0, 0, 0, 0 ,0, 0, 0, 0,    0, 0, 0, 0 ,0, 0, 0, 0 };
byte led_cpt = 0;


void user_led(byte num, byte val)
{
    byte msk;
    msk = 1 << (num & 7);
    if(val) io_led[num / 8] |= msk;
    else    io_led[num / 8] &= (0xff ^ msk);    
}


void user_led_cli(byte num, byte val)
{
    byte msk;
    msk = 1 << (num & 7);
    if(val) io_cli[num / 8] |= msk;
    else    io_cli[num / 8] &= (0xff ^ msk);
}


void user_led_pha(byte num, byte val)
{
    byte msk;
    msk = 1 << (num & 7);
    if(val) io_pha[num / 8] |= msk;
    else    io_pha[num / 8] &= (0xff ^ msk);
}


void led_shift8(byte dat)
{
    byte i;

    pinMode(DAT_PIN, OUTPUT);

    for(i = 0; i < 8; i++)
    {
         if(dat & 0x80) digitalWrite(DAT_PIN, HIGH);
         else           digitalWrite(DAT_PIN, LOW);
             
         delayMicroseconds(4);
         digitalWrite(CLK_PIN, HIGH);
         delayMicroseconds(4);  //periode=8us = 125KHz (ok sur longue distances)
         digitalWrite(CLK_PIN, LOW);
         
         dat = dat<<1;
    }
}

  
void led_reg(byte reg0, byte dat0, byte reg1, byte dat1)
{
     digitalWrite(CLK_PIN, LOW);
     digitalWrite(LLED_PIN, HIGH); delayMicroseconds(10); digitalWrite(LLED_PIN, LOW); delayMicroseconds(10);
     led_shift8(reg1);
     led_shift8(dat1);
     led_shift8(reg0);
     led_shift8(dat0);
     digitalWrite(LLED_PIN, HIGH); delayMicroseconds(10); 
     yield();
}


byte compute_led_on_cli_phase(byte on, byte cli, byte phase)
{
    byte led;

    if(led_cpt & 1) led = 0xff;  else led = 0;   //clignotement 1Hz
    led ^= phase;                                //changement de phase
    led |= ~cli;                                 //allumer si pas clignotant
    led &= on;                                   //eteindre si pas on

    return led;
}


void led_maj(void)
{
    byte i, dat0, dat1;
    
    for(i = 0; i < 8; i++)
    {
        dat0 = compute_led_on_cli_phase(io_led[    i], io_cli[    i], io_pha[    i]);
        dat1 = compute_led_on_cli_phase(io_led[8 + i], io_cli[8 + i], io_pha[8 + i]);
        led_reg(1 + i, dat0, 1 + i, dat1);
    }
}


void led_init(void)
{
                              // R0    : bypass
                              // R1-8  : data
    led_reg(9  ,  0,  9,  0); // R9    : decode mode off (1ere fois pas sure que ca marche) 
    led_reg(9  ,  0,  9,  0); // R9    : decode mode off
    led_reg(0xa,0x4,0xa,0x4); // R10   : intensite 4/15 (0xf=max)
    led_reg(0xb,  7,0xb,  7); // R11   : 8 digit    
    led_reg(0xc,  1,0xc,  1); // R12   :shutdown mode off
                              // R13-14: NA
    led_reg(0xf,  0,0xf,  0); // R15   :test mode off (1=on)

    led_maj(); 
}


void led_sign_of_life(byte val)
{
    #if USER_USE_MAX == 0
        if(val) digitalWrite(LED_PIN, LOW);  //active LOW
        else    digitalWrite(LED_PIN, HIGH);
    #endif
    #if USER_USE_MAX == 1
        #if USER_CLI_LED_MAX != -1
            user_led(USER_CLI_LED_MAX, val);
        #endif
    #endif
}



//------------------------------------------------------------------------------
// I2C (I2C fait a la main pour pouvoir utiliser une basse frequence et n'importe quelle patte)
//------------------------------------------------------------------------------

//on emule un collecteur ouvert en mettant les sorties a 0 et en jouant sur la direction.
#define SDA_1 pinMode(SDA_PIN, INPUT)
#define SDA_0 pinMode(SDA_PIN, OUTPUT)
#define SCK_1 pinMode(SCK_PIN, INPUT)
#define SCK_0 pinMode(SCK_PIN, OUTPUT)


void i2c_init(void)
{
    pinMode(SCK_PIN, INPUT); digitalWrite(SCK_PIN, LOW);
    pinMode(SDA_PIN, INPUT); digitalWrite(SDA_PIN, LOW); 
}


void i2c_start(void)
{
    SDA_1; SCK_1; delayMicroseconds(5);  
    SDA_0; delayMicroseconds(5);
    SCK_0; delayMicroseconds(5);  
}


void i2c_stop(void)
{
    SDA_0; SCK_0; delayMicroseconds(5);  
    SCK_1; delayMicroseconds(5);  
    SDA_1; delayMicroseconds(5);  
}


void i2c_wr_8(byte data)
{
    byte i;

    for(i = 0; i < 8;i++)
    {
        if(data & 0x80) { SDA_1; } else { SDA_0; } delayMicroseconds(4);  
        SCK_1; delayMicroseconds(4);  
        SCK_0; delayMicroseconds(1);  
        data = data << 1;        
    }
    SDA_1; delayMicroseconds(1);  
}


byte i2c_rd_ack(void)
{
    byte ack;

    delayMicroseconds(4);  //before 0
    SCK_1; delayMicroseconds(4);  
    if(digitalRead(SDA_PIN) == HIGH) ack = 0; /*nack*/ else ack = 1; /*ack*/
    SCK_0; delayMicroseconds(1);  
    return ack;
}


byte i2c_rd_8(void)
{
    byte i, data;

    data = 0;
    for(i = 0; i < 8; i++)
    {
        delayMicroseconds(4);  //before 0
        SCK_1; delayMicroseconds(4);  
        if(digitalRead(SDA_PIN) == HIGH) data |= 1;  
        SCK_0; delayMicroseconds(1);  
        data = data << 1;        
    }
    return data;  
}


byte i2c_wr_ack(byte ack)   //1=ack, 0=nack
{
    if(ack) { SDA_0; } else { SDA_1; } delayMicroseconds(4);  
    SCK_1; delayMicroseconds(4);  
    SCK_0; delayMicroseconds(1);  
}



//------------------------------------------------------------------------------
// PCA9685 (3x16=48)
//------------------------------------------------------------------------------

#define PCA9685_MODE1_REG    0x00
#define PCA9685_MODE2_REG    0x01
#define PCA9685_LED0_REG     0x06
#define PCA9685_PRESCALE_REG 0xfe

#define IO_PCA9685_NB 3
#define IO_PCA9685_OUT_NB (16 * IO_PCA9685_NB)

byte pca9685_tx_srv[ IO_PCA9685_OUT_NB];  // bit0=tx  bit1=srv
unsigned int pca9685_on[ IO_PCA9685_OUT_NB];
unsigned int pca9685_off[IO_PCA9685_OUT_NB];
unsigned int pca9685_off_target[IO_PCA9685_OUT_NB];
byte srv_speed[IO_PCA9685_OUT_NB];


byte set_pca9685_reg(byte i2c_adr, byte adr, byte dat)
{
    i2c_start();
    i2c_wr_8(0x80 + 2 * i2c_adr);  //A6=1,A5-A0=pin,R/W#
    if(i2c_rd_ack() == 0)
    {
        i2c_stop();  
        return 0;
    }
    i2c_wr_8(adr);    
    if(i2c_rd_ack() == 0)
    {
        i2c_stop();  
        return 0;
    }
    i2c_wr_8(dat);    
    if(i2c_rd_ack() == 0)
    {
        i2c_stop();  
        return 0;
    }
    i2c_stop();  
    return 1;
}


byte set_pca9685_on_off(byte i2c_adr, byte out, unsigned int on, unsigned int off)
{
    byte on_h, on_l, off_h, off_l;
    
    on_h  = byte(on  >> 8); on_l  = byte(on  & 255);  //existe aussi lowByte highByte
    off_h = byte(off >> 8); off_l = byte(off & 255); 

    i2c_start();  // A6=1,A5-A0=pin,R/W#
    i2c_wr_8(0x80 + 2 * i2c_adr);          i2c_rd_ack();
    i2c_wr_8(PCA9685_LED0_REG + 4 * out);  i2c_rd_ack();
    i2c_wr_8(on_l);                        i2c_rd_ack();
    i2c_wr_8(on_h);                        i2c_rd_ack();
    i2c_wr_8(off_l);                       i2c_rd_ack();
    i2c_wr_8(off_h);                       i2c_rd_ack();
    i2c_stop();
    yield();
}


byte set_pca9685_only_off_out(byte i2c_adr, byte out, unsigned int off)
{
    byte on_h, on_l, off_h, off_l;
    
    off_h = byte(off >> 8); off_l = byte(off & 255); 

    i2c_start();  // A6=1,A5-A0=pin,R/W#
    i2c_wr_8(0x80 + 2 * i2c_adr);              i2c_rd_ack();
    i2c_wr_8(PCA9685_LED0_REG + 4 * out + 2);  i2c_rd_ack();
    i2c_wr_8(off_l);                           i2c_rd_ack();
    i2c_wr_8(off_h);                           i2c_rd_ack();
    i2c_stop();
    yield();
}


// only used at init
void set_pca9685_pwm0_100(byte num, byte pwm)
{
    byte i2c_adr;
    byte out;
    unsigned int off;
    
    i2c_adr = num >> 4; 
    out = num & 15;
    off = map(pwm, 0, 100, 0, 4096); //c bien 4096 et pas 4095 !
    
    if(off == 0)         set_pca9685_on_off(i2c_adr, out,    0, 4096);
    else if(off == 4096) set_pca9685_on_off(i2c_adr, out, 4096,    0);
    else                 set_pca9685_on_off(i2c_adr, out,    0, off );
}


// no more used
void set_paca9685_srv50_250(byte num, byte pulse)  //50 -> 150 -> 250
{
    byte i2c_adr;
    byte out;
    unsigned int off;
    
    i2c_adr = byte(num >> 4); 
    out = byte(num & 15);
    off = map(pulse, 50, 250, 102, 512);
    
    set_pca9685_on_off(i2c_adr, out, 0, off );
}


byte i2c_pca9685_online[IO_PCA9685_NB];

void pca9685_init(void)
{
    byte i;  
    byte i2c_adr;

    for(i2c_adr = 0; i2c_adr < IO_PCA9685_NB; i2c_adr++)
    {
        // reset et config MODE1
        i2c_pca9685_online[i2c_adr] = set_pca9685_reg(i2c_adr, PCA9685_MODE1_REG, 0xB0); //reset=1, extclk=0, autoincrement=1, sleep=1 (all leds are off after reset)
        if(i2c_pca9685_online[i2c_adr] == 0) return;
        delay(1);

        // Frequence de decoupage
        // 50Hz pour les servos: 25.000.000/(4096*50Hz) - 1 = 122-1 = 121.
        // 60Hz pour les servos: 25.000.000/(4096*60Hz) - 1 = 102-1 = 101.
        // mesure:
        // 121 -> 18.7ms     -1.3ms     err -6.5%
        // 130 -> 19.92ms    -0.08ms    err  0.4%
        // 131 -> 20.07ms    +0.07ms    err  0.4%
        set_pca9685_reg(i2c_adr, PCA9685_PRESCALE_REG, 130);

        // exit from sleep
        set_pca9685_reg(i2c_adr, PCA9685_MODE1_REG, 0x20);    //reset=0, extclk=0, autoincrement=1, sleep=0
        delay(1); //wait exit from low power mode

        // config MODE2
        set_pca9685_reg(i2c_adr, PCA9685_MODE2_REG, 0x04);     // invert=0 change=onSTOP out=totem off=led_0
    }
        
    /* toutes les sorties a 0 */
    for(i = 0; i < IO_PCA9685_OUT_NB; i++) 
    {
        if(i2c_pca9685_online[i / 16] == 0) continue;
        
        set_pca9685_pwm0_100(i, 0);      //uu: voir si on fait pas avant d'activer les sorties
        pca9685_on[i] = 0;
        pca9685_off[i] = 4096;
        pca9685_tx_srv[i] = 0; 
        srv_speed[i] = 0;		
    }

    /* spares  
    set_pca9685_on_off(0,0 ,4096,0); //out 0 always on
    set_pca9685_on_off(0,1 ,0,4096); //out 0 always off
    set_pca9685_on_off(0,8 ,0,2048); //out 50%
    set_pca9685_on_off(0,9 ,0,100);  //servo 0.5ms   102  -> ok LA 457us
    set_pca9685_on_off(0,10,0,200);  //servo 1.0ms   206
    set_pca9685_on_off(0,11,0,300);  //servo 1.5ms   308  -> ok LA 1.46ms
    set_pca9685_on_off(0,12,0,400);  //servo 2.0ms   410  
    set_pca9685_on_off(0,13,0,500);  //servo 2.5ms   512*4.882us=2.5ms    
    set_paca9685_pwm0_100(0, 0);
    set_paca9685_srv50_250(11, 150);
    */
}


//variation lente des servos
byte pca9685_slow_srv()
{
    byte num;
    unsigned int off, off_target;

    for(num = 0; num < IO_PCA9685_OUT_NB; num++)
    {
        if(i2c_pca9685_online[num / 16] == 0) continue; // PCA9685 module is not present 

        if((pca9685_tx_srv[num] & 2) == 0) continue; // servos only
        
        if(pca9685_off_target[num] == pca9685_off[num]) continue;
        
        off_target = pca9685_off_target[num];
        off = pca9685_off[num];
        
        if(srv_speed[num]==0) 
        { 
            off = off_target;
        }
        else
        {
            if(off_target > off) { off += srv_speed[num]; if(off > off_target) off = off_target; }
            if(off_target < off) { off -= srv_speed[num]; if(off < off_target) off = off_target; }
        }
        if(pca9685_off[num] != off)
        {
            pca9685_off[num] = off;
            pca9685_tx_srv[num] |= 1;  //update
        }        
    }   
}


// return 1 when update is finished
byte pca9685_maj(byte index)
{
    byte i, num;
    byte i2c_adr;
    byte out;

    for(i = 0; i < 4; i++)
    {
        num = 4 * index + i;
        if(num >= IO_PCA9685_OUT_NB) return 1;       
        
        if(i2c_pca9685_online[num / 16] == 0) continue;   // PCA9685 module is not present

        if(pca9685_tx_srv[num] & 1)
        {
            pca9685_tx_srv[num] &= 0xfe;

            i2c_adr = num / 16; 
            out = num & 15;

            set_pca9685_on_off(i2c_adr, out, pca9685_on[num], pca9685_off[num]);
        }
    }

    return 0;
}


void user_pwm_0_100(byte num, byte val)
{
    unsigned int off;
    
    if(num >= IO_PCA9685_OUT_NB) return;

    off = map(val, 0, 100, 0, 4096);

    if(off == 0)         { pca9685_on[num] = 0;    pca9685_off[num] = 4096; }
    else if(off == 4096) { pca9685_on[num] = 4096; pca9685_off[num] =    0; }
    else                 { pca9685_on[num] = 0;    pca9685_off[num] =  off; }

    pca9685_tx_srv[num] |= 1;
    pca9685_tx_srv[num] &= 0xfd;  //not a servo
}


void user_servo_500_2500(byte num, unsigned int val)
{   
    unsigned int off;

    if(num >= IO_PCA9685_OUT_NB) return;

    off = map(val, 500, 2500, 102, 512);    //4096=20ms > 102=0.5ms 512=2.5ms

    pca9685_on[num] = 0;    pca9685_off_target[num] = off;

    pca9685_tx_srv[num] |= 2;  //is a servo (no update, done in pca9685_slow_srv)
	
}


void user_servo_speed(byte num, byte speed)
{
    if(num >= IO_PCA9685_OUT_NB) return;

    srv_speed[num] = speed; 
}



//--------------------------------------------------------------------------------
// Aiguillages
//----------------------------------------------------------------------------------

#define IO_AIG_NB 48

byte io_aig_cmd[IO_AIG_NB];
byte io_aig_dir[IO_AIG_NB];
byte io_aig_dev[IO_AIG_NB];

void user_set_d_e(byte num, byte val_d, byte val_e)
{
    if(num >= IO_AIG_NB) return;
    io_aig_dir[num] = val_d;
    io_aig_dev[num] = val_e;
}


void aig_init(void)
{
    byte i;

    for(i = 0; i < IO_AIG_NB; i++)
    {
        io_aig_cmd[i] = 0;
        io_aig_dev[i] = 0;
        io_aig_dir[i] = 0; 
    }
}


#if 0
void aig_maj(void)
{
    // stub pour tester
    byte i;
    for(i = 0; i < IO_AIG_NB; i++)
    {
        if(io_aig_cmd[i] == 1) io_aig_dev[i] = 1; else io_aig_dev[i] = 0;
        io_aig_dir[i] = io_aig_dev[i] ^ 1; 
    }
}
#endif



//--------------------------------------------------------------------------------
// User vars
//----------------------------------------------------------------------------------

#define VAR_U_NB 96

byte var_u[VAR_U_NB / 8];   // 96 variables

void set_var_u(byte num, byte val)
{
    byte ind = num / 8;
    byte msk = 1 << (num & 3);

    if(num >= VAR_U_NB) return;
    if(val) var_u[ind] |= msk; 
    else    var_u[ind] &= (0xff ^ msk);
}


void inv_var_u(byte num)
{
    if(num >= VAR_U_NB) return;

    byte ind = num / 8;
    byte msk = 1 << (num & 3);
    
    var_u[ind] ^= msk; 
}


byte get_var_u(byte num)
{
    if(num >= VAR_U_NB) return 0;

    byte ind = num / 8;
    byte msk = 1 << (num & 3);

    if(var_u[ind] & msk) return 1; else return 0;      
}


void user_set_u(byte num, byte val)
{
    if(num < VAR_U_NB) set_var_u(num, val);
}


byte user_get_u(byte num)
{
    if(num >= VAR_U_NB) return 0;
    return get_var_u(num);
}



//--------------------------------------------------------------------------------
// User tempos
//----------------------------------------------------------------------------------

#define TEMPO_NB 80  //mettre un multiple de 8
unsigned int tempo_dcpt[TEMPO_NB];
byte tempo_flag[TEMPO_NB / 8];

void user_tempo_start(byte num_tempo, unsigned int duration_ms)
{
    if(num_tempo >= TEMPO_NB) return;

    //tempo_dcpt[num_tempo] = duration_ms / 20; //20ms increment
    tempo_dcpt[num_tempo] = duration_ms / 250; //250ms increment
    if(duration_ms > 0 && duration_ms < 250) tempo_dcpt[num_tempo] = 1;

    if(duration_ms) tempo_flag[num_tempo / 8] |= (1 << (num_tempo & 7));
    else            tempo_flag[num_tempo / 8] &= (0xff ^ (1 << (num_tempo & 7)));
}


void tempo_maj(void)  //a appeller toutes les 250ms
{
    byte i, j, num;

    for(j = 0; j < (TEMPO_NB / 8); j++) if(tempo_flag[j])
    for(i = 0; i < 8; i++) if(tempo_dcpt[i])
    {
        num = 8*j + i;
        tempo_dcpt[num]--;
        if(tempo_dcpt[num] == 0) 
        { 
            tempo_flag[num / 8] &= (0xff ^ (1 << (num & 7)));
            user_notify_tempo_end(num);
        }
    }
    yield();
}



//--------------------------------------------------------------------------------
// Variables
//----------------------------------------------------------------------------------

byte boost = BOOST_DCC;
byte oldboost = BOOST_DCC;
byte au = 1;   //maintenant la centrale demarre en AU (donc alimenation off, cela est plus sure)  
byte pwmsens = 0;
unsigned int pwm1024 = 0;
unsigned int cv_adr = 1;
byte cv_dat = 3;
unsigned int an;   //derniere lecture du convertisseur analogique/numerique




//--------------------------------------------------------------------------------
// DCC signal   part
//----------------------------------------------------------------------------------

// DCC
// "1"
//    typ      58us
//    station  55-61us  (delta max entre periodes 3us)  --> measure LA OK: 1=57.5 or 61us
//    decodeur 52-64us  (delta max entre periodes 6us)     
// "0"
//    typ      100us
//    station  95-9990us (total 12000us)
//        
// IDLE     : 1111111111 0 11111111 0 00000000            0 EEEEEEEE 1
//
// VIT  28  : 1111111111 0 0AAAAAAA 0 01DFSSSS            0 EEEEEEEE 1
// VIT 127  : 1111111111 0 0AAAAAAA 0 00111111            0 DSSSSSSS 0 EEEEEEEE 1
//
// FCT 0-4  : 1111111111 0 0AAAAAAA 0 100-FL-F4-F3-F2-F1  0 EEEEEEEE 1
// FCT 5-8  : 1111111111 0 0AAAAAAA 0 1011-F8-F7-F6-F5    0 EEEEEEEE 1 
// FCT 9-12 : 1111111111 0 0AAAAAAA 0 1010-F12-F11-F10-F9 0 EEEEEEEE 1 
// FCT 13-20: 1111111111 0 0AAAAAAA 0 11011110            0 F20-F19-F18-F17-F16-F15-F14-F13 0 EEEEEEEE 1 
// FCT 11-28: 1111111111 0 0AAAAAAA 0 11011111            0 F28-F27-F26-F25-F24-F23-F22-F21 0 EEEEEEEE 1 
//
// ACC 1-511: 1111111111 0 10AAAAAA 0 1AAA1DDD            0 EEEEEEEE 1 attention, les 3xAAA sont inverses, ils forment aussi le MSB adr0 est reserve le 1 entre AetD peut etre mis a 0 pour mettre la sortie a 0, mais normalement allumer la 0 eteint la 1 et inversement. ou alors remise a 0 automatique apres une pulse
// ACC1-2047: 1111111111 0 10AAAAAA 0 0AAA0AA1 0 000xxxxx 0 EEEEEEEE 1
//
// une explication accessible sur le DCC est dispo sur: http://trainminiature.discutforum.com/t12784-dcc-comment-ca-marche-place-a-la-technique

#define T1 55   // half period DCC bit 1 
#define T0 100  // half period DCC bit 0


void dcc_tx(byte p_len, byte nb, byte a, byte b, byte c)
{
    byte x = a, i;
    
    // preambule
    for(i = 0; i < p_len; i++)
    {
        digitalWrite(DCC_PIN, LOW); delayMicroseconds(T1); digitalWrite(DCC_PIN, HIGH); delayMicroseconds(T1);
    }

    // separator
    digitalWrite(DCC_PIN, LOW); delayMicroseconds(T0); digitalWrite(DCC_PIN, HIGH); delayMicroseconds(T0); delay(0);

    // data
    while(1)
    {
        for(i = 0; i < 8; i++)    //MSB transmit first
        {
            if(a & 128) { digitalWrite(DCC_PIN, LOW); delayMicroseconds(T1); digitalWrite(DCC_PIN, HIGH); delayMicroseconds(T1); }
            else        { digitalWrite(DCC_PIN, LOW); delayMicroseconds(T0); digitalWrite(DCC_PIN, HIGH); delayMicroseconds(T0); }
            a = a << 1;
        }

        // separator
        digitalWrite(DCC_PIN, LOW); delayMicroseconds(T0); digitalWrite(DCC_PIN, HIGH); delayMicroseconds(T0); delay(0);
         
        nb--;
        if(nb == 0) break;

        x ^= b;
        a = b; b = c; 
    }

    // xor
    for(i = 0; i < 8; i++)
    {
        if(x & 128) { digitalWrite(DCC_PIN, LOW); delayMicroseconds(T1); digitalWrite(DCC_PIN, HIGH); delayMicroseconds(T1); }
        else        { digitalWrite(DCC_PIN, LOW); delayMicroseconds(T0); digitalWrite(DCC_PIN, HIGH); delayMicroseconds(T0); }
        x = x << 1;
    }

    // end
    digitalWrite(DCC_PIN, LOW); delayMicroseconds(T1); digitalWrite(DCC_PIN, HIGH); delayMicroseconds(T1);

    // start a 0 (can last 9.9ms max)
    digitalWrite(DCC_PIN, LOW); delayMicroseconds(T0); digitalWrite(DCC_PIN, HIGH); delayMicroseconds(T0); delay(0);
}


void dcc_tx2(byte p_len, byte a, byte c)
{
    dcc_tx(p_len, 2, a, c, 0);
}


void dcc_tx3(byte p_len, byte a, byte b, byte c)
{
    dcc_tx(p_len, 3, a, b, c);
}


void dcc_keepalive(void)   //a appeller si une fonction dure plus de 9.9ms pour que les decodeurs restent en mode DCC
{
    if(boost != BOOST_DCC) return
    
    // start a 0 (can last 9.9ms max)
    digitalWrite(DCC_PIN, LOW); delayMicroseconds(T0); digitalWrite(DCC_PIN, HIGH); delayMicroseconds(T0); delay(0);
}


// envoie d'une trame pour activer une sortie sur un decodeur d'accessoire basique
// normalement val=1 car les decodeurs d'accesoires sont souvent configures soit:
// - allumer la 0 eteint la 1 et vice versa
// - generer des pulses
// adr: 1-511
// out: 0-7
// val: 0/1
// ACC1-511: 1111111111 0 10AAAAAA 0 1AAAVDDD 0 EEEEEEEE 1
void user_bas_acc_dec_tx(unsigned int adr, byte out, byte val)
{
    byte b1 = 128 | ((byte)adr & 0x3f);
    byte b2 = (((byte)(adr >> 2) & 0x70) ^ 0x70) | 0x80 | (out & 7) | ((val & 1) << 3); 

    if(boost == BOOST_ANA)
    {
        #if USER_ACC_ANA == 0   // pas de transmission en ANA 
            return; 
        #endif
        #if USER_ACC_ANA == 1   // desactivation du booster durant la transmission
            if(au == 0) analogWrite(P_PIN, 0);
        #endif
        #if USER_ACC_ANA == 2   // activation du booster durant la transmission
            if(au == 0) analogWrite(P_PIN, 1);
        #endif        
    }
     
    dcc_tx2(15, b1, b2);  //on transmet 2x une commande pour un accessoire
    dcc_tx2(15, b1, b2);      

    if(boost == BOOST_ANA)
    {
        if(pwmsens) digitalWrite(S_PIN, HIGH);
        else        digitalWrite(S_PIN, LOW);    

        #if USER_ACC_ANA == 1   // desactivation du booster durant la transmission
            if(au == 0) analogWrite(P_PIN, pwm1024);
        #endif
        #if USER_ACC_ANA == 2   // activation du booster durant la transmission
            if(au == 0) analogWrite(P_PIN, pwm1024);
        #endif        
    }
}


// envoie d'une valeur 0-31 a un decodeur d'accessoire etendu
// adr: 1-2044
// val: 031
// ACC1-2044: 1111111111 0 10AAAAAA 0 0AAA0AA1 0 000DDDDD 0 EEEEEEEE 1
void user_ext_acc_dec_tx(unsigned int adr, byte val)
{
    adr--; // 0-2043
    byte low = adr & 3; //0-3 
    adr = adr >> 2; //0-510
    adr++; //1-511
    
    byte b1 = 128 | (byte)(adr & 0x3f);
    byte b2 = (((byte)(adr >> 2) & 0x70) ^ 0x70) | (low << 1) | 1; 

    if(boost == BOOST_ANA)
    {
        #if USER_ACC_ANA == 0   // pas de transmission en ANA 
            return; 
        #endif
        #if USER_ACC_ANA == 1   // desactivation du booster durant la transmission
            if(au == 0) analogWrite(P_PIN, 0);
        #endif
        #if USER_ACC_ANA == 2   // activation du booster durant la transmission
            if(au == 0) analogWrite(P_PIN, 1);
        #endif        
    }
    
    dcc_tx3(15, b1, b2, val);  //on transmet 2x une commande pour un accesoire
    dcc_tx3(15, b1, b2, val);       

    if(boost == BOOST_ANA)
    {
        if(pwmsens) digitalWrite(S_PIN, HIGH);
        else        digitalWrite(S_PIN, LOW);    

        #if USER_ACC_ANA == 1   // desactivation du booster durant la transmission
            if(au == 0) analogWrite(P_PIN, pwm1024);
        #endif
        #if USER_ACC_ANA == 2   // activation du booster durant la transmission
            if(au == 0) analogWrite(P_PIN, pwm1024);
        #endif        
    }
}


// sens: 1=AV, 0=AR
// vit 0-28
byte vit28_2_dcc(byte sens, byte vit)
{
    if(vit > 0)
    {  
        vit += 3;
        if(vit & 1) vit |= 32;
        vit = vit >> 1;  
    }
    if(sens) vit |= 32;
    vit |= 64;

    return vit;
}
// vit 0-126
byte vit126_2_dcc(byte sens, byte vit)
{
    if(vit > 0) vit += 1;
    if(sens) vit |= 128;

    return vit;
}



//--------------------------------------------------------------------------------
// DCC prog   part
//----------------------------------------------------------------------------------

#define DCC_PROG_FRAME_IDLE  0
#define DCC_PROG_FRAME_RESET 1
#define DCC_PROG_FRAME_PAGE  2
#define DCC_PROG_FRAME_DAT   3

#define PROG_SEQ_SIZE 35
// 0x idle 3x reset 6x page 10x reset 6x dat 10x reset 0x idle
byte dcc_prog_seq[] = { \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
\
DCC_PROG_FRAME_PAGE, \
DCC_PROG_FRAME_PAGE, \
DCC_PROG_FRAME_PAGE, \
DCC_PROG_FRAME_PAGE, \
DCC_PROG_FRAME_PAGE, \
DCC_PROG_FRAME_PAGE, \
\
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
\
DCC_PROG_FRAME_DAT, \
DCC_PROG_FRAME_DAT, \
DCC_PROG_FRAME_DAT, \
DCC_PROG_FRAME_DAT, \
DCC_PROG_FRAME_DAT, \
DCC_PROG_FRAME_DAT, \
\
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
DCC_PROG_FRAME_RESET, \
};

// cv_adr = 1-1024
//     cv_pag = 1-255-0
//     cv_reg = 0-3
// cv_dat = 0-255
void prog_cv(unsigned int cv_adr, byte dat)
{
    byte seq_ind, a, c, cv_pag, cv_reg, cv_dat;
  
    cv_pag = ((cv_adr - 1) / 4) + 1;
    cv_reg = (cv_adr - 1) & 3;
    cv_dat = dat;
  
    for(seq_ind = 0; seq_ind < PROG_SEQ_SIZE; seq_ind++)
    {
        switch(dcc_prog_seq[seq_ind])
        {
            case DCC_PROG_FRAME_IDLE:        
                    a = 0xff;
                    c = 0;
                    break;
            case DCC_PROG_FRAME_RESET:        
                    a = 0;
                    c = 0;
                    break;
            case DCC_PROG_FRAME_PAGE:        
                    a = 0x7D;  //0111CRRR C=1=WR RRR=5=page
                    c = cv_pag;
                    break;
            case DCC_PROG_FRAME_DAT:        
                    a = (byte)0x78 + cv_reg;  //0111CRRR C=1=WR RRR=0(cv1),1(cv2),2(cv3),3(cv4) ...
                    c = cv_dat;
                    break;
        }
        dcc_tx2(22, a, c);  
    }
}



//--------------------------------------------------------------------------------
// Booster management
//----------------------------------------------------------------------------------

class C_dcc_ch   
{
    public:
        byte adr = 0;
        byte sens = 0;
        byte vit = 0;
        byte fct[29] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};  //f0-f1---f28
        byte fct_5_8_transmited = 0;
        byte fct_9_12_transmited = 0;
        byte fct_13_20_transmited = 0;
        byte fct_21_28_transmited = 0;
};

C_dcc_ch dcc_ch[2][MAX_CLIENTS];

byte client_tx = 0;

void booster_maj(void)
{
    byte i, j;
    byte val;
    byte ch_ab = 0;
    byte adr, sens, vit;
    byte fct04_1, fct8_5, fct12_9, fct20_13, fct28_21;

    boost = BOOST_DCC;
    for(j = 0; j < 2; j++) for(i = 0; i < 4; i++) if(dcc_ch[j][i].adr == ADR_ANA) boost = BOOST_ANA;

    yield();

    if(boost != oldboost)
    {
        if(oldboost == BOOST_ANA) { analogWriteFreq(50); analogWrite(P_PIN, 0);}
        oldboost = boost;
        if(boost == BOOST_ANA) { Serial.println("BOOST ANA"); analogWriteFreq(20000); analogWrite(P_PIN, 0); }
        if(boost == BOOST_DCC)   Serial.println("BOOST DCC");
    }

    // si un mode est interdit, on peut y passer, mais on reste en AU
    #if USER_DCC_OK == 0
        if(boost == BOOST_DCC) au = 1;
    #endif
    #if USER_ANA_OK == 0
        if(boost == BOOST_ANA) au = 1;
    #endif

    if(boost == BOOST_ANA)
    {
        if(au) analogWrite(P_PIN, 0);
        else   analogWrite(P_PIN, pwm1024);

        if(pwmsens) digitalWrite(S_PIN, HIGH);
        else        digitalWrite(S_PIN, LOW);    
    }

    if(boost == BOOST_DCC)
    {
        //maintent en cas d'arret d'urgence on coupe l'alimentation au lieu d'envoyer la trame d'arret d'urgence
        // ancienne solution
        //dcc_tx2(10, 0, 0x41); // AU : 1111111111 0 00000000 0 01000001 0 EEEEEEEE 1
        //notez qu'il est possible de transmettre des trames pour les acceoires par S_PIN (en dehors de cette fonction)
        if(au) 
        {
            digitalWrite(P_PIN, LOW);   
        }
        else
        {
            digitalWrite(P_PIN, HIGH);

            // GENERATION DU SIGNAL DCC pr S_PIN


            if(!dcc_ch[0][client_tx].adr && !dcc_ch[1][client_tx].adr)
            {
                // IDLE   : 1111111111 0 11111111 0 00000000 0 EEEEEEEE 1
                dcc_tx2(10, 0xff, 0);      
            }

            else for(ch_ab = 0; ch_ab < 2; ch_ab++)
            {
                adr = dcc_ch[ch_ab][client_tx].adr;
                if(!adr) continue;            
                
                sens = dcc_ch[ch_ab][client_tx].sens;
                vit = dcc_ch[ch_ab][client_tx].vit;
                fct04_1  =  16*dcc_ch[ch_ab][client_tx].fct[0]  +  8*dcc_ch[ch_ab][client_tx].fct[4]  +  4*dcc_ch[ch_ab][client_tx].fct[3]  +  2*dcc_ch[ch_ab][client_tx].fct[2] + 1*dcc_ch[ch_ab][client_tx].fct[1];
                fct8_5   =   8*dcc_ch[ch_ab][client_tx].fct[8]  +  4*dcc_ch[ch_ab][client_tx].fct[7]  +  2*dcc_ch[ch_ab][client_tx].fct[6]  +  1*dcc_ch[ch_ab][client_tx].fct[5];
                fct12_9  =   8*dcc_ch[ch_ab][client_tx].fct[12] +  4*dcc_ch[ch_ab][client_tx].fct[11] +  2*dcc_ch[ch_ab][client_tx].fct[10] +  1*dcc_ch[ch_ab][client_tx].fct[9];
                fct20_13 = 128*dcc_ch[ch_ab][client_tx].fct[20] + 64*dcc_ch[ch_ab][client_tx].fct[19] + 32*dcc_ch[ch_ab][client_tx].fct[18] + 16*dcc_ch[ch_ab][client_tx].fct[17] + 8*dcc_ch[ch_ab][client_tx].fct[16] + 4*dcc_ch[ch_ab][client_tx].fct[15] + 2*dcc_ch[ch_ab][client_tx].fct[14] + 1*dcc_ch[ch_ab][client_tx].fct[13];
                fct28_21 = 128*dcc_ch[ch_ab][client_tx].fct[28] + 64*dcc_ch[ch_ab][client_tx].fct[27] + 32*dcc_ch[ch_ab][client_tx].fct[26] + 16*dcc_ch[ch_ab][client_tx].fct[25] + 8*dcc_ch[ch_ab][client_tx].fct[24] + 4*dcc_ch[ch_ab][client_tx].fct[23] + 2*dcc_ch[ch_ab][client_tx].fct[22] + 1*dcc_ch[ch_ab][client_tx].fct[21];                     

                // VIT  28: 1111111111 0 0AAAAAAA 0 01DFSSSS 0 EEEEEEEE 1
                // VIT 126  : 1111111111 0 0AAAAAAA 0 00111111 0 DSSSSSSS 0 EEEEEEEE 1
                #if USER_USE_126_CRANS == 0
                    dcc_tx2(10, adr, vit28_2_dcc(sens, vit));
                #endif              
                #if USER_USE_126_CRANS == 1
                    dcc_tx3(10, adr, 0x3f, vit126_2_dcc(sens, vit));
                #endif
                delay(0);
    
                // non utilise actuellement
                    
                // FCT 0-4: 1111111111 0 0AAAAAAA 0 100-FL-F4-F3-F2-F1 0 EEEEEEEE 1
                dcc_tx2(10, adr, 128 + fct04_1);
                yield();
                      
                // FCT 5-8: 1111111111 0 0AAAAAAA 0 1011-F8-F7-F6-F5 0 EEEEEEEE 1
                if(fct8_5) 
                { 
                    dcc_tx2(10, adr, 0b10110000 | fct8_5); 
                    dcc_ch[ch_ab][client_tx].fct_5_8_transmited = 1;
                }
                else if(dcc_ch[ch_ab][client_tx].fct_5_8_transmited) 
                {   
                    dcc_tx2(10, adr, 0b10110000); 
                    dcc_ch[ch_ab][client_tx].fct_5_8_transmited = 0; 
                } 
                
                // FCT 9-12: 1111111111 0 0AAAAAAA 0 1010-F12-F11-F10-F9  0 EEEEEEEE 1
                if(fct12_9)
                { 
                    dcc_tx2(10, adr, 0b10100000 | fct12_9);
                    dcc_ch[ch_ab][client_tx].fct_9_12_transmited = 1; 
                }
                else if(dcc_ch[ch_ab][client_tx].fct_9_12_transmited) 
                { 
                    dcc_tx2(10, adr, 0b10100000); 
                    dcc_ch[ch_ab][client_tx].fct_9_12_transmited = 0;
                } 
                yield();
                
                // FCT 13-20: 1111111111 0 0AAAAAAA 0 11011110 0 F20-F19-F18-F17-F16-F15-F14-F13 0 EEEEEEEE 1 
                if(fct20_13)
                { 
                    dcc_tx3(10, adr, 0b11011110, fct20_13);
                    dcc_ch[ch_ab][client_tx].fct_13_20_transmited = 1; 
                }
                else if(dcc_ch[ch_ab][client_tx].fct_13_20_transmited) 
                { 
                    dcc_tx3(10, adr, 0b11011110, 0);
                    dcc_ch[ch_ab][client_tx].fct_13_20_transmited = 0;
                } 
                
                // FCT 21-28: 1111111111 0 0AAAAAAA 0 11011111 0 F28-F27-F26-F25-F24-F23-F22-F21 0 EEEEEEEE 1 
                if(fct28_21)
                { 
                    dcc_tx3(10, adr, 0b11011111, fct28_21);
                    dcc_ch[ch_ab][client_tx].fct_21_28_transmited = 1; 
                }
                else if(dcc_ch[ch_ab][client_tx].fct_21_28_transmited) 
                { 
                    dcc_tx3(10, adr, 0b11011111, 0);
                    dcc_ch[ch_ab][client_tx].fct_21_28_transmited = 0;
                } 
                yield();
                
            } // adr valid and for ch A & B   
            
        } // not au

        client_tx++;
        if(client_tx == MAX_CLIENTS) client_tx = 0;
        
    }  //(boost==BOOST_DCC)

    delay(0);
}



//--------------------------------------------------------------------------------
// Decode  part
//----------------------------------------------------------------------------------

char status_tx[100];
byte status_txed[4] = { 0, 0, 0, 0 };

void update_in_status_message(byte ch)
{
    byte j, k, v;

    j = 9;

    for(k = 0; k < IO_IN_NB/8; k ++)
    {
        v = io_inmem[ch][k] & 0x0f;
        if(v < 10) status_tx[j] = '0' + v; else status_tx[j] = 'A' + v - 10;
        j++;
        v = io_inmem[ch][k] >> 4;
        if(v < 10) status_tx[j] = '0' + v; else status_tx[j] = 'A' + v - 10;
        j++;
        io_inmem[ch][k] = 0; // clr
    }
}

void build_status_message(void)
{
    byte j, k, v;
    
    // au[0/1] ana/dcc iXXXXXXXXXXXXXXXXXXXXXXXX dXXXXXXXXXXXX eXXXXXXXXXXXX uXXXXXXXXXXXXXXXXXXXXXXXX cYY
    // 01 2   3456    789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012
    // 0                 1         2         3         4         5         6         7         8         9          10
    j = 0;
            
    if(au) strcpy(status_tx, "au1 "); else strcpy(status_tx, "au0 ");
    j += 4;

    if(boost == BOOST_ANA) strcpy(&status_tx[j], "ana ");
    if(boost == BOOST_DCC) strcpy(&status_tx[j], "dcc ");
    j+=4; 

    status_tx[j] = 'i'; j++;
    for(k = 0; k < IO_IN_NB/8; k ++)
    {
        v = io_in[k] & 0x0f;
        if(v < 10) status_tx[j] = '0' + v; else status_tx[j] = 'A' + v - 10;
        j++;
        v = io_in[k] >> 4;
        if(v < 10) status_tx[j] = '0' + v; else status_tx[j] = 'A' + v - 10;
        j++;
    }
    status_tx[j] = ' '; j++;
            
    status_tx[j] = 'd'; j++;
    for(k = 0; k < IO_AIG_NB; k += 4)
    {
        v = 8 * io_aig_dir[k + 3] + 4 * io_aig_dir[k + 2] + 2 * io_aig_dir[k + 1] + io_aig_dir[k];
        if(v < 10) status_tx[j] = '0' + v; else status_tx[j] = 'A' + v - 10;
        j++;
    }
    status_tx[j] = ' '; j++;
            
    status_tx[j] = 'e'; j++;
    for(k = 0; k < IO_AIG_NB; k += 4)
    {
        v = 8 * io_aig_dev[k + 3] + 4 * io_aig_dev[k + 2] + 2 * io_aig_dev[k + 1] + io_aig_dev[k];
        if(v < 10) status_tx[j] = '0' + v; else status_tx[j] = 'A' + v - 10;
        j++;
    }
    status_tx[j] = ' '; j++;
            
    status_tx[j] = 'u'; j++;
    for(k = 0; k < VAR_U_NB/8; k ++)
    {
        v = var_u[k] & 0x0f;
        if(v < 10) status_tx[j] = '0' + v; else status_tx[j] = 'A' + v - 10;
        j++;
        v = var_u[k] >> 4;
        if(v < 10) status_tx[j] = '0' + v; else status_tx[j] = 'A' + v - 10;
        j++;
    }
    status_tx[j] = ' '; j++;

    sprintf(&status_tx[j], "c%02d", map(an, 0, 1023, 0, 99));
    j += 3;            
    status_tx[j] = '\0';
}


// ex de trames:
//    au1
//    a3 s+ v8 f0-
//    cva0001 cvd0008 cvp1234

/* Protocole
 * 
 * au1 = arret d'urgence, le booster est desactive
 * au0 = fin d'arret d'urgence
 * 
 * a<1-99>   = adresse de la locomotive et selection du canal A de la souris
 * b<1-99>   = adresse de la locomotive et selection du canal B de la souris
 * s+        = sens 1 (pour le canal selectionne)
 * s-        = sens 0
 * v<0-100>  = vitesse en %
 * f<0-28>+  = allumage fonction auxiliaire
 * f<0-28>-  = extinction fonction auxiliaire
 * 
 * cva<1-1024> cvd<0-255> cvp<XXXX> = programation d'un decodeur de locomotive cva=adresse du CV, cvd=data cvp=code de protection a fixer dans ce programme afin d'interdir les programmation non autorisees
 * 
 * x<1-511>.<0-7>+  = activation d'une sortie d'un decodeur d'accessoire
 * x<1-511>.<0-7>-  = desactivation d'une sortie d'un decodeur d'accessoire (normalement jamais utilise car l'activation de 0 desactive 1 et vice versa, ou alors si le decodeur est configure en impulsion, les sorties reviennent a 0 toutes seules)
 * y<1-2044>=<0-31> = afectation de la valeur 0-31 a un decodeur d'accessoire etendu 
 * 
 * o<0-5>+   = mise a 1 d'une sortie directe
 * o<0-5>-   = mise a 0 d'une sortie directe
 * 
 * l<0-127>+ = allumage d'une led
 * l<0-127>- = extinction d'une led
 * c<0-127>+ = mode clignotant
 * c<0-127>- = mode fixe
 * h<0-127>- = phase normale
 * h<0-127>+ = phase inverse
 * 
 * p<0-47>=<0-100>  = pwm (sur i2c)
 * s<0-47>=<50-250> = servo(sur i2c) = pulsation en 10us, neutre en 150*10us=1.5ms
 * s<0-47>-         = mettre le servo en position 0
 * s<0-47>+         = mettre le servo en position 1
 * w<0-47>=<0-255>  = vitesse de rotation des servos (0=max, nb de us / 250ms, ex: 1 = 1us/250ms = 4us/sec, 1000->1500us en 125s)
 * Le choix entre pwm et servo se regle au debut du fichier d ela centrale
 * Pour utiliser les sorties en 0/1, utiliser pwm0/100
 * La vitesse de rotation des servos, ainsi que les positions extremes sont reglables
 * 
 * t<0-47>- = aiguillage en position direct (t=turnable, aiguillage en Americain)
 * t<0-47>/ = aiguillage en position devie
 * t<0-47>^ = inversion de la position de l'aiguillage
 * l'aiguillage peut etre de n'importe quel type(bobine, moteur, serv) et situe n'importe ou(en sortie de l'esp, sur un module i2c pca9685, sur un decodeur d'accessoire), 
 * c'est a l'utilisateur de le definir dans ce programme. Il est egalement possible d'indiquer la duree de l'impulsion et inverser la commande
 * les rapport d et e sont mis a jour un efois la commande effectuee
 * 
 * u<0-95>- = mettre a 0 la variable utilisateur
 * u<0-95>+ = mettre a 1 la variable utilisateur
 * u<0-95>^ = inverser la variable utilisateur
 * 
 * ? = demande de l'emission de l'etat
 * au[0/1] ana/dcc iXXXXXXXXXXXXXXXXXXXXXXXX dXXXXXXXXXXXX eXXXXXXXXXXXX uXXXXXXXXXXXXXXXXXXXXXXXX cYY
 * 01 2   3456    789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012
 * 0                 1         2         3         4         5         6         7         8         9          10
 * X = codage en hexa 0-F pour transmettre 4 bits par caracter afin de ne pas surcharger le lien
 *     on aurait pu passer en binaire pour encore plus gagner, mais je voulais rester en ASCII
 * i = entree (0-95)
 * u = etat des commandes utilisateur
 * d = aiguillage en position directe (0-47)
 * e = aiguillage en position devie   (0-47)
 * c = convertisseur analogique numerique (souvent utilise pour mesurer le courant
 * YY = 0(0V), 99(1V)
 * 
 * ! = information sur la centrale: ie: D17 v20170106a
 * 
 */
char tx[100];

void parse_rx(byte cclient, char* rx)
{
    byte i, j, k, v, nb, is_num;
    unsigned int nbi;
    byte ch_ab = 0; //canal a par defaut
    
    i = 0;

    while(i != strlen(rx))
    {
        // pre-traitement
        is_num = 0; if(rx[i + 1] >= '0' && rx[i + 1] <= '9') is_num = 1;


        // skip
          
        if(rx[i] == '\n') break;

        else if(rx[i] == ' ') i += 1;
        
        else if(rx[i] == 'c' && rx[i+1] == 'a') // cabine_net v1
        {
            Serial.println("cabine_net v1 no more supported !");
            while(1) delay(0);
        }

        else if(rx[i] == 's' && rx[i+1] == 'o') break; // souris_d17_net v1
 

        // locomotives

        else if(rx[i] == 'a' && rx[i + 1] == 'u')
        {
            if(rx[i + 2] == '0')  au = 0;
            else                  au = 1;
            i += 3;
        }

        else if(rx[i] >= 'a' && rx[i] <= 'b' && is_num)
        {
            if(rx[i] == 'b') ch_ab = 1; else ch_ab = 0;
            
            nb = rx[i + 1] - '0';
            if(rx[i + 2] >= '0' && rx[i + 2] <= '9')
            { 
                nb = 10 * nb + rx[i + 2] - '0'; 
                i += 3; 
            } 
            else
            {
                i += 2;
            }
            dcc_ch[ch_ab][cclient].adr = nb;
        }

        else if(rx[i] == 's' && ( rx[i+1] == '+' || rx[i+1] == '-' )  )
        {
            if(rx[i + 1] == '+') dcc_ch[ch_ab][cclient].sens = 1; else dcc_ch[ch_ab][cclient].sens = 0;
            if(dcc_ch[ch_ab][cclient].adr == ADR_ANA)
            {
                if(rx[i + 1] == '+')  pwmsens = 1; else pwmsens = 0;
            }
            i += 2;
        }

        else if(rx[i] == 'v' && is_num)
        {
            nbi = rx[i + 1] - '0'; 
            i += 2;
            while(rx[i] >= '0' && rx[i] <= '9') 
            { 
                nbi = 10 * nbi + (rx[i] - '0'); 
                i++; 
            } 
            nb = (byte)nbi;  //0-100%

            #if USER_USE_126_CRANS == 0
                dcc_ch[ch_ab][cclient].vit = map(nb, 0, 100, 0, 28);  //0-100% -> 0-28crans
            #endif
            #if USER_USE_126_CRANS == 1
                dcc_ch[ch_ab][cclient].vit = map(nb, 0, 100, 0, 126);  //0-100% -> 0-126crans
            #endif
            
            if(dcc_ch[ch_ab][cclient].adr == ADR_ANA)
            {
                //pwm1024 = nb * 1024 / 100;
                pwm1024 = nb * 1024 * USER_PWM_FACTOR / 100 / 100;
            }
        }

        else if(rx[i] == 'f' && is_num)
        {
            nb = rx[i + 1] - '0';
            i += 2;
            if(rx[i] >= '0' && rx[i] <= '9') 
            { 
                nb = 10 * nb + (rx[i] - '0'); 
                i++; 
            }
            while(nb<=28)
            { 
                if(     rx[i] == '+') { dcc_ch[ch_ab][cclient].fct[nb] = 1; i++; nb++; }
                else if(rx[i] == '-') { dcc_ch[ch_ab][cclient].fct[nb] = 0; i++; nb++; }
                else break;
            }
        }

        else if(rx[i] == 'c' && rx[i + 1] == 'v')
        {
            nbi = 1000 * (rx[i + 3] - '0') + 100 * (rx[i + 4] - '0') + 10 * (rx[i + 5] - '0') + (rx[i + 6] - '0');
            if(rx[i+2] == 'a') cv_adr = nbi;
            if(rx[i+2] == 'd') cv_dat = (byte) nbi;
            if(rx[i+2] == 'p') if(nbi == CV_PROG_CODE) if(boost == BOOST_DCC)
            {
                led_sign_of_life(1); //LED ON
                sprintf(tx, "prog cv%d=%d", cv_adr, cv_dat); Serial.println(tx);
                tx[0] = 0;
                // programing seqeunce
                prog_cv(cv_adr, cv_dat);
                // disable booster during 1s to reboot decoder
                digitalWrite(P_PIN, LOW);
                digitalWrite(S_PIN, LOW);
                led_sign_of_life(0); 
                delay(1000); //UU: possible to check with can
                digitalWrite(P_PIN, HIGH);
                Serial.println("prog done");
            }
            i +=7 ;
        }

        // entrees/sorties

        // direct out
        
        else if(rx[i] == 'o' && is_num)
        {
            nb = rx[i + 1] - '0';      

            if(rx[i + 2] == '+') user_out(nb, 1); else user_out(nb, 0);  
            i += 3;
        }

        // led

        else if(rx[i] == 'l' && is_num)
        {
            i++; nb = 0; while(rx[i] >= '0' && rx[i] <= '9') { nb = 10 * nb + rx[i] - '0'; i++; }
            if(nb < IO_LED_NB)
            {
                if(rx[i] == '+') user_led(nb, 1); else user_led(nb, 0);
            }
            i++;
        }
        else if(rx[i] == 'c' && is_num)
        {
            i++; nb = 0; while(rx[i] >= '0' && rx[i] <= '9') { nb = 10 * nb + rx[i] - '0'; i++; }
            if(nb < IO_LED_NB)
            {
                if(rx[i] == '+') user_led_cli(nb, 1); else user_led_cli(nb, 0);
            }
            i++;
        }
        else if(rx[i] == 'h' && is_num)
        {
            i++; nb = 0; while(rx[i] >= '0' && rx[i] <= '9') { nb = 10 * nb + rx[i] - '0'; i++; }
            if(nb < IO_LED_NB)
            {
                if(rx[i] == '+') user_led_pha(nb, 1); else user_led_pha(nb, 0);
            }
            i++;
        }

        // pwm p<0-47>=<0-100>  = pwm (sur i2c)
        
        else if(rx[i] == 'p' && is_num)
        {
            i++; nb = 0; while(rx[i] >= '0' && rx[i] <= '9') { nb = 10 * nb + rx[i] - '0'; i++; }
            i++; //skip '='
            nbi = 0; while(rx[i] >= '0' && rx[i] <= '9') { nbi = 10 * nbi + rx[i] - '0'; i++; }
            if(nb < IO_PCA9685_OUT_NB) user_pwm_0_100(nb, nbi);
        }

        // servos s<0-47>=<50-250> = servo(sur i2c) = pulsation en 10us, neutre en 150*10us=1.5ms
        //        s<0-47>-         = mettre le servo en position 0
        //        s<0-47>+         = mettre le servo en position 1
        //        s<0-47>/         = mettre le servo en position 1
        //        w<0-47>=<0-255>  = vitesse de rotation des servos (0=max, nb de us / 250ms, ex: 1 = 1us/250ms = 4us/sec, 1000->1500us en 125s)
        else if(rx[i] == 's' && is_num)
        {
            i++; nb = 0; while(rx[i] >= '0' && rx[i] <= '9') { nb = 10 * nb + rx[i] - '0'; i++; }
            if(rx[i] == '=')
            {
                i++;
                nbi = 0; while(rx[i] >= '0' && rx[i] <= '9') { nbi = 10 * nbi + rx[i] - '0'; i++; }
                if(nb < IO_PCA9685_OUT_NB) user_servo_500_2500(nb, 10 * nbi); 
            }
			/* desactive
            else 
            {
                if(nb < IO_PCA9685_OUT_NB)
                {
                    if(rx[i] == '-') set_srv_50_250(nb, srv_pos_0[nb]);
                    if(rx[i] == '+') set_srv_50_250(nb, srv_pos_1[nb]);
                    if(rx[i] == '/') set_srv_50_250(nb, srv_pos_1[nb]);
                }
                i++;
            }
			*/
        }
        else if(rx[i] == 'w' && is_num)
        {
            i++; nb = 0; while(rx[i] >= '0' && rx[i] <= '9') { nb = 10 * nb + rx[i] - '0'; i++; }
            if(rx[i] == '=')
            {
                i++;
                nbi = 0; while(rx[i] >= '0' && rx[i] <= '9') { nbi = 10 * nbi + rx[i] - '0'; i++; }
                if(nb < IO_PCA9685_OUT_NB) user_servo_speed(nb, nbi); 
            }
        }

        // decodeur d'accesssoire "basique"
        // x<1-511>.<0-7>+ = activation d'une sortie d'un decodeur d'accessoire
        // x<1-511>.<0-7>- = desactivation d'une sortie d'un decodeur d'accessoire
        //                   (normalement jamais utilise car l'activation de la sortie 0 desactive la 1 et vice versa, 
        //                   ou alors si le decodeur est configure en impulsion, les sorties reviennent a 0 toutes seules)
        else if(rx[i] == 'x' && is_num)
        {
            i++; nbi = 0; while(rx[i] >= '0' && rx[i] <= '9') { nbi = 10 * nbi + rx[i] - '0'; i++; }
            i++; //skip '.'
            nb = rx[i] - '0'; i++;
            //Serial.print("x="); Serial.print(nbi);
            //Serial.print(" out="); Serial.print(nb);
            
            if(nbi >= 1 && nbi <= 511 && nb<=7)
            {
                if(rx[i] = '-') v = 0; else v = 1;
                //user_notify_bas_acc_dec(nbi, nb, v); 
                user_bas_acc_dec_tx(nbi, nb, v);
            }
            i++;
        }

        // decodeur d'accesssoire "extended"
        // y<1-2044>=<0-31> activation d'une sortie d'un decodeur d'accessoire
        else if(rx[i] == 'y' && is_num)
        {
            i++; nbi = 0; while(rx[i] >= '0' && rx[i] <= '9') { nbi = 10 * nbi + rx[i] - '0'; i++; }
            i++; //skip '='
            nb = 0; while(rx[i] >= '0' && rx[i] <= '9') { nb = 10 * nb + rx[i] - '0'; i++; }
            if(nbi >= 1 && nbi <= 2044 && nb <= 31)
            {
                //user_notify_ext_acc_dec(nbi, nb); 
                user_ext_acc_dec_tx(nbi, nb);
            }
            i++;
        }       

        // aiguillages
        // t<0-47>- = aiguillage en position direct (t=turnable, aiguillage en Americain)
        // t<0-47>/ = aiguillage en position devie
        // t<0-47>^ = inversion de la position de l'aiguillage
        else if(rx[i] == 't' && is_num)
        {
            i++; nb = 0; while(rx[i] >= '0' && rx[i] <= '9') { nb = 10 * nb + rx[i] - '0'; i++; }
            if(nb < IO_AIG_NB)
            {
                if(rx[i] == '-') io_aig_cmd[nb]  = 0;
                if(rx[i] == '+') io_aig_cmd[nb]  = 1;
                if(rx[i] == '/') io_aig_cmd[nb]  = 1;
                if(rx[i] == '^') io_aig_cmd[nb] ^= 1;

                user_notify_aig(nb, io_aig_cmd[nb]);
            }
            i++;
        }

        // user variables
        // u<0-95>- = mettre a 0 la variable utilisateur
        // u<0-95>+ = mettre a 1 la variable utilisateur
        // u<0-95>^ = inverser la variable utilisateur
        else if(rx[i] == 'u' && is_num)
        {
            i++; nb = 0; while(rx[i] >= '0' && rx[i] <= '9') { nb = 10 * nb + rx[i] - '0'; i++; }
            if(nb < VAR_U_NB)
            {
                if(rx[i] == '-') set_var_u(nb,0);
                if(rx[i] == '+') set_var_u(nb,1);
                if(rx[i] == '/') set_var_u(nb,1);
                if(rx[i] == '^') inv_var_u(nb);

                user_notify_u(nb, get_var_u(nb));
            }
            i++;
        }
 
        // querry
        else if(rx[i] == '?')
        {
            i++;
            if(status_tx[0] == '\0') 
            { 
                  build_status_message();  
                  status_txed[0] = status_txed[1] = status_txed[2] = status_txed[3] = 0;
            }  
            if(status_txed[cclient] == 0)
            {
                update_in_status_message(cclient);                      
                strcpy(tx, status_tx);                      
                Serial.println(tx);
                status_txed[cclient] = 1;
            }
        }

        else if(rx[i] == '!')
        {
            i++;
            strcpy(tx, CENTRAL_NAME);
            Serial.println(tx);
        }
        

        else i++;

        yield();
    }  
}



//--------------------------------------------------------------------------------
// TCP/IP server part
//----------------------------------------------------------------------------------

WiFiServer server(tcp_port);
WiFiClient zeclients[MAX_CLIENTS];
byte wait_id_msg[MAX_CLIENTS] = {0, 0, 0, 0};

void wifi_init(void)
{
    WiFi.mode(WIFI_AP);

    WiFi.softAP(AP_name, AP_pass);
  
    IPAddress myIP = WiFi.softAPIP();
    Serial.print("D17 IP address: "); Serial.println(myIP);
    
    server.begin();
}


void parse_wifi_clients(void)
{
    byte i;
    char rx[120] = "";

  
    for(i = 0; i < MAX_CLIENTS; i++)
    {
        // Client comes
        if(!zeclients[i]) 
        { 
            zeclients[i] = server.available();
            if(zeclients[i]) 
            {
                Serial.print("Client"); Serial.print(i); Serial.println(" connected");
                zeclients[i].print("d17 v1\n"); wait_id_msg[i] = 1;
            }                
        }
        
        // No Client
        if(!zeclients[i]) continue;
        
        // Client leaves
        if(!zeclients[i].connected()) 
        {
            Serial.print("Client"); Serial.print(i); Serial.println(" disconnected");
            zeclients[i].stop();
            //zeclients[i] = NULL;  //uu: essayer
            continue;
        }

        // Client sends data
        while(zeclients[i].available()) 
        {
            Serial.print("Client"); Serial.print(i);
            
            String line = zeclients[i].readStringUntil('\n');
            line.toCharArray(rx, 119);
            rx[119] = '\0';
            /**/Serial.print(" "); Serial.println(rx); 

            yield();

            if(wait_id_msg[i]) // remove the welcome message
            {
                wait_id_msg[i] = 0;
            }
            else // parse the command message
            {
                parse_rx(i, rx); 
                if(tx[0] != '\0') 
                {
                     // envoie du message de reponse
                     strcat(tx, "\n"); 
                     zeclients[i].print(tx);
                     tx[0] = '\0'; 
                }
            }

            yield();
            Serial.print(".");
        }
        //client.flush();
    }

    delay(0);      
}



//--------------------------------------------------------------------------------
// MAIN
//----------------------------------------------------------------------------------

void check_au_pin(void)
{
#if USER_USE_AU == 1
    byte state;

    state = digitalRead(AU_PIN);
    pinMode(AU_PIN, INPUT_PULLUP);
    delayMicroseconds(5);
    #if USER_AU_LEVEL == 0
        if(digitalRead(AU_PIN) == LOW) au = 1;
    #else
        if(digitalRead(AU_PIN) == HIGH) au = 1;
    #endif
    pinMode(AU_PIN, OUTPUT);
    digitalWrite(AU_PIN, state);
#endif  
}

unsigned long time0;

void setup() 
{
    // pins init
    pinMode(P_PIN,   OUTPUT); digitalWrite(P_PIN,   LOW);  // D2
    pinMode(S_PIN,   OUTPUT); digitalWrite(S_PIN,   LOW);  // D3
    pinMode(LED_PIN, OUTPUT); digitalWrite(LED_PIN,HIGH);  // D4 LED active low, also LLED_PIN
    pinMode(DAT_PIN, OUTPUT); digitalWrite(DAT_PIN, LOW);  // D0
    pinMode(CLK_PIN, OUTPUT); digitalWrite(CLK_PIN, LOW);  // D5
    pinMode(LDIN_PIN,OUTPUT); digitalWrite(LDIN_PIN,LOW);  // D1
    pinMode(RST_PIN, OUTPUT); digitalWrite(RST_PIN, LOW);  // D8
    pinMode(SCK_PIN, OUTPUT); digitalWrite(SCK_PIN, LOW);  // D7
    pinMode(SDA_PIN, OUTPUT); digitalWrite(SDA_PIN, LOW);  // D6

    // serial init
    Serial.begin(115200);
    Serial.print("\nHello from "); Serial.println(CENTRAL_NAME);

#if USER_USE_MAX == 1
    // led init
    led_init();
#endif

#if USER_USE_PCA == 1
    // i2c init
    i2c_init();
    pca9685_init();
#endif

#if USER_USE_S88 == 1
    // s88 init
    s88_init();
#endif

    aig_init();

    user_init();

    wifi_init();

    Serial.println("waiting clients ...");

    time0 = millis();
}


byte wait_250ms = 0;    
byte cpt_250ms = 0;    

void loop() 
{
    byte is_500ms;
    byte is_1s;
    byte is_2s;
    byte index = 0;
    unsigned long time1;

    //Serial.print("*");
   
    // 1. GESTION DES CLIENTS WIFI
    parse_wifi_clients();
  
    // 2. GENERATION DES SIGAUX DU BOOSTER
    check_au_pin(); // to update AU before booster update
    booster_maj();  // update one client (max 2 locos and functions) 

    // 3. GESTION DU TEMPS (TOUTES LES 250ms) (uu: essayer de reduire a 125ms)
    time1 = millis();
    if((time1 - time0) < 250) return;
    if((time1 - time0) > 300) Serial.print("#");
    Serial.println(time1 - time0);    
    time0=time1;

    // on arrive ici toute les 250ms      
    cpt_250ms++;  
    if((cpt_250ms & 1)==0) is_500ms = 1; else is_500ms = 0;   // 1x/2
    if((cpt_250ms & 3)==0) is_1s = 1; else is_1s = 0;         // 1x/4
    if((cpt_250ms & 7)==0) is_2s = 1; else is_2s = 0;         // 1x/8

    // 4. CLIGNOTEMENT DE LA LED (Sign of life) 
    if(!au) // lent 0.5Hz
    {
        if(cpt_250ms & 4) led_sign_of_life(1); else led_sign_of_life(0);
    }
    else // rapide 2Hz
    {
        if(cpt_250ms & 1) led_sign_of_life(1); else led_sign_of_life(0);
    }
    delay(0);

    // 5. LECTURE DU COURANT
    an = analogRead(A0);
    if(is_1s) { Serial.print("can="); Serial.println(an); }

    // 6. LECTURE DES ENTREES S88
    #if USER_USE_S88    
        s88_maj();   //4.8ms
        if(boost == BOOST_DCC) dcc_keepalive();
    #endif
    delay(0);
   
    // 7. APPEL DE LA FONCTION DE BOUCLE UTILISATEUR
    tempo_maj();
    user_250ms();
    delay(0);
    
    // 8. MISE A JOUR DES LEDs
    #if USER_USE_MAX == 1
        if(is_500ms) led_cpt++;
        led_maj();   //2.5ms
        if(boost == BOOST_DCC) dcc_keepalive();
    #endif   //(yield ds les fonctions SPI)

    // 9. MISE A JOUR PWM et SRV du PCA9685
    #if USER_USE_PCA == 1
        pca9685_slow_srv(); // compute positions for servos using slow movements
        index = 0;
        while(1) // total pca9685_maj lasts between 0 and 60ms, so we cut it to call process_packet() between
        {
            if(pca9685_maj(index)) break;  //return 1 when nothing else to update   0.6ms/ch

            index++;              
            if((index & 7) == 0)  //each 4.8ms
            {
                if(boost == BOOST_DCC) dcc_keepalive();
            }
        }               
    #endif //(yield ds les fonctions I2C)

    // 10. DEMANDE DE MISE A JOUR DU MESSAGE DE STATUS
    status_tx[0] = '\0';
    
    delay(0);
}



