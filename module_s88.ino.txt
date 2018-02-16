/*
  Module_S88_16IN

  Historique:
    2017-06-14 Ulysse Delmas-Begue creation

  License:
    GPL v2

  Description:
   
    Ce Sketch transforme un Arduino UNO/NANO en un module S88 a 15 ou 16 entrees
  
    15 entrees sont supportees si la broche CLR est utilisee
    16 entrees sont supportees si la broche CLR n'est utilisee (La broche LOAD faisant aussi office de CLR)

    Les entrees sont actives au niveau bas et la resistance de pull-up de l'Arduino est activee 
    Les fronts sur les entrees sont memorises
  
    On utilise directement les ports car les acces digitalWrite/Read sont trop lent

  Brochage:

    Numero        15 14 13 12   11  10  9  8                7  6  5  4  3  2  1  0
    Patte Arduino A1.A0.D13.D12.D11.D10.D9.D8               D7.D6.D5.D4.D3.D2.D1.D0
    Port  Arduino C1.C0.B5 .B4 .B3 .B2 .B1.B0    Clr        D7.D6.D5.D4.D3.D2.D1.D0
                  |  |  |   |   |   |   |  |      v         |  |  |  |  |  |  |  |
                 #O##O##O###O###O###O###O##O# Memorisation #O##O##O##O##O##O##O##O#  
                  |  |  |   |   |   |   |  |                |  |  |  |  |  |  |  |
         Dext -> #O##O##O###O###O###O###O##O#### Decalage ##O##O##O##O##O##O##O##O# -> Dcentrale
                                                  ^    ^
                                                 Clk  Load

  Interface S88:
               Patte              Port
    RST      : A1 (si utilisee) : C1
    LOAD     : A2               : C2                                 
    CLK      : A3               : C3
    Dcentrale: A4               : C4
    Dext     : A5               : C5

  Registres des ports de l'Arduino:
  
    Addr    Name     Bit7   Bit6   Bit5   Bit4   Bit3   Bit2   Bit1   Bit0
    ...
    0x03   PINB     PINB7  PINB6  PINB5  PINB4  PINB3  PINB2  PINB1  PINB0
    0x04   DDRB     DDB7   DDB6   DDB5   DDB4   DDB3   DDB2   DDB1   DDB0
    0x05   PORTB    PORTB7 PORTB6 PORTB5 PORTB4 PORTB3 PORTB2 PORTB1 PORTB0
    0x06   PINC     x      PINC6  PINC5  PINC4  PINC3  PINC2  PINC1  PINC0
    0x07   DDRC     x      DDC6   DDC5   DDC4   DDC3   DDC2   DDC1   DDC0
    0x08   PORTC    x      PORTC6 PORTC5 PORTC4 PORTC3 PORTC2 PORTC1 PORTC0
    0x09   PIND     PIND7  PIND6  PIND5  PIND4  PIND3  PIND2  PIND1  PIND0
    0x0A   DDRD     DDD7   DDD6   DDD5   DDD4   DDD3   DDD2   DDD1   DDD0
    0x0B   PORTD    PORTD7 PORTD6 PORTD5 PORTD4 PORTD3 PORTD2 PORTD1 PORTD0

  Mesures:

      Temps de boucle maxi: 5.25us

  Protocol S88:
  
      RST  ______#_________       ________       ____
      LDIN __###___________  ...  ________  ...  ____
      CLK  ___#____#___#___       _#___#__       _#__
      Data     0    1   2           15  16         31

      Le Load est synchrone pour fonctionner avec les CD4014
*/


/* configuration utilisateur */

// Choisir la configuration (mettre seulement un 1 pour la configuration selectionne)
#define use_15_in 1   // 15 entrees directes  (la broche CLR est utilisee)
#define use_16_in 0   // 16 entrees directes  (la broche CLR n'est pas utilisee)
#define use_48_in 0   // 48 entrees matricees (la broche CLR est utilisee)       PAS ENCORE DISPONIBLE
#define use_64_in 0   // 64 entrees matricees (la broche CLR n'est pas utilisee) PAS ENCORE DISPONIBLE                    

// Choisir si les entrees doivent etre filtrees ou pas
#define use_filter 1

/* fin de la configuration utilisateur */


#if use_15_in == 1
    #define use_clr_pin 1
#endif
#if use_16_in == 1
    #define use_clr_pin 0
#endif
#if use_48_in == 1
    #define use_clr_pin 1
#endif
#if use_64_in == 1
    #define use_clr_pin 0
#endif

    
byte memh = 0;
byte meml = 0;
byte dech = 0;
byte decl = 0;
byte portc;
byte old_portc;
byte dcentrale;
#if use_filter == 1
    byte zestep = 0;
    byte memh1 = 0;
    byte meml1 = 0;
    byte memh2 = 0;
    byte meml2 = 0;
    byte memh3 = 0;
    byte meml3 = 0;
#endif

void setup() 
{
  DDRD  = 0;    // entrees
  //DDRD  = 1;    // UU debug pour mesurer le temps de boucle
  PORTD = 0xff; // pull-ups
  DDRB  = 0;    // entrees
  PORTB = 0x3f; // pull-ups
  DDRC  = 0x10; // seul Dcentrale est en sortie
  PORTC = 0x03; // pull-ups
  noInterrupts();  // pour ne pas etre derange
}

void loop() 
{
    while(1) // plus rapide que de passe dans loop()
    {
        // debug pour mesurer le temps de boucle
        //asm("sbi 11,0\n\t");  // PORTD=11 , bit0 // UU DBG !!
        //asm("cbi 11,0\n\t");  // PORTD=11 , bit0 // UU DBG !!
        
        // lecture des pins et memorisation (il faudra peut etre mettre un filtre pour eviter les glitches)
        old_portc = portc;
        portc = PINC;
        #if use_filter == 0
            meml |= PIND ^ 0xff; 
            memh |= (PINB ^ 0xff) & 0x3f;
            if((portc & 1)==0) memh |= 0x40;
            if((portc & 2)==0) memh |= 0x80;
        #endif
        #if use_filter == 1
            zestep++;
            if((zestep & 2) == 0)
            {
                if((zestep & 1) == 0)  
                {
                    // step 0
                    meml1 = PIND ^ 0xff; 
                    memh1 = (PINB ^ 0xff) & 0x3f;
                    if((portc & 1)==0) memh1 |= 0x40;
                    if((portc & 2)==0) memh1 |= 0x80;
                }
                else
                {
                    // step 1
                    meml2 = PIND ^ 0xff; 
                    memh2 = (PINB ^ 0xff) & 0x3f;
                    if((portc & 1)==0) memh2 |= 0x40;
                    if((portc & 2)==0) memh2 |= 0x80;
                }
            }    
            else
            {
                if((zestep & 1) == 0)  
                {
                    // step 2
                    meml3 = PIND ^ 0xff; 
                    memh3 = (PINB ^ 0xff) & 0x3f;
                    if((portc & 1)==0) memh3 |= 0x40;
                    if((portc & 2)==0) memh3 |= 0x80;
                }
                else
                {
                    // step 3 (pour etre declaree active, l'entree doit etre active 3 fois de suite)
                    meml |= (meml1 & meml2 & meml3);  
                    memh |= (memh1 & memh2 & memh3); 
                }
            }
        #endif

        // decalage
        if((old_portc & 8)==0)
        {
            if(portc & 8)  // front montant: on decale
            {
                dcentrale =  decl & 1;
                decl = decl >> 1;
                if(dech & 1) decl |= 0x80;
                dech = dech >> 1;
                if(PINC & 0x20) dech |= 0x80;
            }
        }
        else
        {
            if((portc & 8)==0)  // front descendant: on met a jour Dcentrale
            {
                if(dcentrale)
                    asm("sbi 8,4\n\t");  // Dcentrale=1 PATTE A4 : PORTC=8 , bit4
                else
                    asm("cbi 8,4\n\t");  // Dcentrale=0 PATTE A4 : PORTC=8 , bit4
            }
        }

        // chargement
        if((old_portc & 4)==0) if(portc & 4) // oblige de mettre un front sinon l'effacement peut se faire plusieurs fois
        {
            dech = memh;
            decl = meml;  
            #if use_clr_pin == 0
                // effacement
                memh = meml = 0;
            #endif
        }

        // effacement
        #if use_clr_pin == 1
            if(portc & 2)
            {
                memh = meml = 0;        
            }
        #endif
    }
}
